#!/usr/bin/env python3
"""Local Clavis desktop-agent service.

The shell is a native QML layer-shell UI. This small service owns the durable
agent configuration, provider calls and conversation history; it deliberately
does not open a window of its own.

It speaks the OpenAI-compatible Chat Completions protocol and the Responses
protocol, so it can use OpenAI, DeepSeek, a local gateway, or a Codex++ gateway.
"""
from __future__ import annotations

import array
import base64
import ctypes
import hashlib
import html
import json
import mimetypes
import zipfile
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from local_agents import available_agents as _local_agents_available
from local_agents import run_local_agent as _run_local_agent
from local_agents import summary as _local_agents_summary

APP = "clavis-agent"
VERSION = "1"
HOST = "127.0.0.1"
PORT = int(os.environ.get("CLAVIS_AGENT_PORT", "8765"))
CONFIG_PATH = Path(os.environ.get("CLAVIS_AGENT_CONFIG", Path.home() / ".config/clavis/agent.json"))
STATE_DIR = Path(os.environ.get("CLAVIS_AGENT_STATE", Path.home() / ".local/state/clavis-agent"))
SESSIONS_DIR = STATE_DIR / "sessions"
MAX_BODY = 64 * 1024 * 1024
MAX_HISTORY = 48
LOCK = threading.RLock()

DEFAULT_CONFIG = {
    "enabled": True,
    "name": "Clavis Agent",
    "provider": "OpenAI",
    "backend": "openai-compatible",
    "base_url": "https://api.openai.com/v1",
    "api_style": "chat",
    "api_key": "",
    "model": "gpt-4o-mini",
    "system_prompt": "你是 Clavis 桌面助手。回答简洁、直接，优先使用中文；需要操作桌面时说明具体步骤。",
    "temperature": 0.3,
    "max_tokens": 2048,
    "timeout": 120,
    "computer_control": {
        "enabled": True,
        "allow_windows": True,
        "allow_launch": True,
        "allow_input": True,
        "allow_clipboard": True,
        "allow_audio": True,
        "allow_android": True,
        "adb_serial": "",
        "allow_shell": False,
        "allow_local_agents": True,
        "allow_documents": True,
        "allow_web": True,
        "allow_config": True,
        "working_dir": str(Path.home()),
        "timeout": 20,
    },
    "mcp": {
        "enabled": True,
        "servers": {},
    },
    "skills": {
        "extra_dirs": [],
        "disabled": [],
    },
    "pet": {
        "enabled": True,
        "image": "whale",
        "custom_url": "",
        "size": 112,
        "sounds": False,
        "volume": 0.7,
    },
    "voice": {
        "enabled": True,
        "auto_speak": True,
        "continuous": False,
        "tts_engine": "auto",
        "tts_voice": "zh-cn",
        "tts_speed": 150,
        "source": "",
        "vad_threshold": 500,
        "vad_silence_ms": 800,
        "max_seconds": 20,
    },
}


def deep_merge(base: dict, patch: dict) -> dict:
    result = dict(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_config() -> dict:
    with LOCK:
        try:
            data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                data = {}
        except (OSError, ValueError):
            data = {}
        merged = deep_merge(DEFAULT_CONFIG, data)
        if not CONFIG_PATH.exists():
            save_config(merged)
        return merged


def save_config(config: dict) -> None:
    with LOCK:
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = CONFIG_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        os.chmod(tmp, 0o600)
        os.replace(tmp, CONFIG_PATH)



APP_CACHE_LOCK = threading.RLock()
APP_CACHE = {"time": 0.0, "apps": []}
APP_CACHE_TTL = 15.0


def _desktop_dirs() -> list[Path]:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    data_dirs = [Path(item) for item in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if item]
    dirs = [data_home / "applications"] + [item / "applications" for item in data_dirs]
    dirs += [
        Path("/var/lib/flatpak/exports/share/applications"),
        Path.home() / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/snapd/desktop/applications"),
    ]
    seen = set()
    result = []
    for directory in dirs:
        key = str(directory)
        if key not in seen:
            seen.add(key)
            result.append(directory)
    return result


def _desktop_value(section: dict, key: str) -> str:
    for candidate in (f"{key}[zh_CN]", f"{key}[zh]", f"{key}[en_US]", key):
        value = section.get(candidate)
        if value:
            return value
    return ""


def _parse_desktop_entry(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    section = {}
    in_desktop = False
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("["):
            in_desktop = line == "[Desktop Entry]"
            continue
        if not in_desktop or not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        section[key.strip()] = value.strip()
    if section.get("Type", "Application") != "Application":
        return None
    if section.get("Hidden", "false").lower() == "true":
        return None
    if section.get("NoDisplay", "false").lower() == "true":
        return None
    name = _desktop_value(section, "Name").strip()
    exec_line = _desktop_value(section, "Exec").strip()
    if not name or not exec_line:
        return None
    # Strip desktop field codes such as %U, %F, %i, %c; keep the command
    # useful for the fallback spawn path.
    command = re.sub(r"%[a-zA-Z]", "", exec_line).replace("%%", "%").strip()
    return {
        "id": path.name,
        "name": name,
        "command": command,
        "icon": _desktop_value(section, "Icon"),
        "terminal": section.get("Terminal", "false").lower() == "true",
        "startup_wm_class": section.get("StartupWMClass", ""),
        "path": str(path),
    }


def installed_apps() -> list[dict]:
    now = time.monotonic()
    with APP_CACHE_LOCK:
        if now - APP_CACHE["time"] < APP_CACHE_TTL and APP_CACHE["apps"]:
            return [dict(item) for item in APP_CACHE["apps"]]
        apps = []
        seen = set()
        for directory in _desktop_dirs():
            if not directory.is_dir():
                continue
            for path in sorted(directory.glob("*.desktop")):
                entry = _parse_desktop_entry(path)
                if not entry:
                    continue
                key = (entry["id"], entry["name"], entry["command"])
                if key in seen:
                    continue
                seen.add(key)
                apps.append(entry)
        apps.sort(key=lambda item: (item["name"].casefold(), item["id"]))
        APP_CACHE["apps"] = apps
        APP_CACHE["time"] = now
        return [dict(item) for item in apps]


def search_installed_apps(query: str = "", limit: int = 60) -> list[dict]:
    needle = str(query or "").strip().casefold()
    apps = installed_apps()
    if needle:
        apps = [app for app in apps if needle in app["name"].casefold() or needle in app["id"].casefold()
                or needle in app["command"].casefold()]
    return apps[:max(1, min(120, int(limit or 60)))]


def find_installed_app(target: str) -> dict | None:
    target = str(target or "").strip()
    if not target:
        return None
    apps = installed_apps()
    for app in apps:
        if app["id"] == target:
            return app
    for app in apps:
        if app["name"] == target:
            return app
    matches = search_installed_apps(target, 1)
    return matches[0] if matches else None


def _audio_devices() -> dict:
    result = _run_command(["pactl", "-f", "json", "list", "sinks"], {})
    sinks = []
    if result.get("ok"):
        raw = result.get("output") or "[]"
        start = raw.find("[")
        end = raw.rfind("]")
        if start >= 0 and end > start:
            raw = raw[start:end + 1]
        try:
            for item in json.loads(raw):
                if not isinstance(item, dict):
                    continue
                volumes = item.get("volume") or {}
                first_volume = next(iter(volumes.values()), {}) if isinstance(volumes, dict) else {}
                sinks.append({
                    "id": item.get("index"),
                    "name": item.get("name", ""),
                    "description": item.get("description", ""),
                    "mute": bool(item.get("mute", False)),
                    "volume": first_volume.get("value_percent", ""),
                })
        except ValueError:
            pass
    default_result = _run_command(["pactl", "get-default-sink"], {})
    return {"sinks": sinks,
            "default": default_result.get("output", "").strip() if default_result.get("ok") else ""}


def environment_context(config: dict) -> str:
    apps = installed_apps()
    lines = ["当前桌面环境：" + (os.environ.get("XDG_CURRENT_DESKTOP") or "unknown")
             + "；会话：" + (os.environ.get("XDG_SESSION_TYPE") or "wayland")]
    if apps:
        app_list = ", ".join(f"{app['name']} [{app['id']}]" for app in apps[:80])
        lines.append("已安装应用（可通过 list_installed_apps 搜索，通过 open_app 启动）：" + app_list)
    windows_result = _niri_json(["windows"], config)
    if windows_result.get("ok"):
        try:
            windows = json.loads(windows_result.get("output") or "[]")
            current = [f"{w.get('id')}:{w.get('title', '')} ({w.get('app_id', '')})"
                       for w in windows if isinstance(w, dict)]
            if current:
                lines.append("当前 Niri 窗口：" + " | ".join(current[:12]))
        except ValueError:
            pass
    audio = _audio_devices()
    if audio["sinks"]:
        lines.append("音频输出设备：" + "; ".join(
            f"{item['description'] or item['name']} [{item['name']}]" for item in audio["sinks"]))
    android = _android_environment(config)
    if android.get("connected"):
        app_text = ", ".join(f"{item['name']} [{item['package']}]" for item in android.get("apps", []))
        lines.append("Android/Droidloom 已连接：" + app_text)
        if android.get("activity"):
            lines.append(android["activity"])
        lines.append("操作 Android 应用内部时先调用 android_ui_dump，使用返回节点的 center 坐标调用 android_tap；"
                     "也可以使用 android_find_and_tap、android_swipe、android_keyevent。")
    lines.append("需要启动已安装应用时，先调用 list_installed_apps 查找，再调用 open_app；不要仅凭窗口列表判断应用是否安装。")
    return "\n".join(lines)



ANDROID_APP_RE = re.compile(r"droidloomctl\s+launch\s+(\S+)(?:\s+--component\s+(\S+))?")
ANDROID_KEYCODES = {
    "home": 3, "back": 4, "call": 5, "endcall": 6, "volumeup": 24, "volumedown": 25,
    "power": 26, "camera": 27, "menu": 82, "notification": 83, "search": 84,
    "enter": 66, "tab": 61, "escape": 111, "delete": 67, "forward_del": 112,
    "move_home": 122, "move_end": 123, "page_up": 92, "page_down": 93,
    "up": 19, "down": 20, "left": 21, "right": 22, "center": 23,
}


def android_apps() -> list[dict]:
    result = []
    for app in installed_apps():
        match = ANDROID_APP_RE.search(app.get("command", ""))
        if not match:
            continue
        package = match.group(1)
        component = match.group(2) or ""
        result.append({
            "name": app["name"],
            "desktop_id": app["id"],
            "package": package,
            "component": component,
            "command": app.get("command", ""),
        })
    return result


def android_serial(config: dict) -> str:
    cc = _computer_config(config)
    configured = str(cc.get("adb_serial") or "").strip()
    if configured:
        return configured
    result = _run_command(["adb", "devices"], config)
    if not result.get("ok"):
        return ""
    for line in (result.get("output") or "").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            return parts[0]
    return ""


def _adb(config: dict, args: list[str]) -> dict:
    serial = android_serial(config)
    if not serial:
        return _tool_error("没有可用的 ADB Android 设备")
    return _run_command(["adb", "-s", serial] + args, config)


def _android_ui_nodes(config: dict) -> tuple[dict | None, dict]:
    serial = android_serial(config)
    if not serial:
        return None, _tool_error("没有可用的 ADB Android 设备")
    # uiautomator can transiently fail while an app animates; the dump command
    # result is not authoritative, the XML cat is.
    _adb(config, ["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    cat = _adb(config, ["shell", "cat", "/sdcard/window_dump.xml"])
    if not cat.get("ok"):
        return None, cat
    raw = cat.get("output") or ""
    start = raw.find("<hierarchy")
    end = raw.rfind("</hierarchy>")
    if start < 0 or end < start:
        return None, _tool_error("uiautomator 没有返回有效 XML")
    xml_text = raw[start:end + len("</hierarchy>")]
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as error:
        return None, _tool_error(f"无法解析 Android UI XML：{error}")
    nodes = []

    def visit(element, depth=0):
        if len(nodes) >= 160:
            return
        attrs = element.attrib
        bounds = attrs.get("bounds", "")
        match = re.match(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", bounds)
        center = None
        if match:
            x1, y1, x2, y2 = map(int, match.groups())
            center = [int((x1 + x2) / 2), int((y1 + y2) / 2)]
        text = attrs.get("text", "")
        desc = attrs.get("content-desc", "")
        resource = attrs.get("resource-id", "")
        clickable = attrs.get("clickable", "false") == "true"
        scrollable = attrs.get("scrollable", "false") == "true"
        if text or desc or clickable or scrollable or (resource and depth <= 8):
            nodes.append({
                "depth": depth,
                "text": text,
                "description": desc,
                "resource_id": resource,
                "class": attrs.get("class", ""),
                "bounds": bounds,
                "center": center,
                "clickable": clickable,
                "scrollable": scrollable,
                "package": attrs.get("package", ""),
            })
        for child in list(element):
            visit(child, depth + 1)

    visit(root)
    package = ""
    if len(root):
        package = root[0].attrib.get("package", "")
    return {"package": package, "rotation": root.attrib.get("rotation", "0"), "nodes": nodes}, {"ok": True}


def _android_tap_node(config: dict, node: dict) -> dict:
    center = node.get("center") if isinstance(node, dict) else None
    if not center or len(center) != 2:
        return _tool_error("该 UI 节点没有可点击坐标")
    return _adb(config, ["shell", "input", "tap", str(int(center[0])), str(int(center[1]))])


def _android_find_node(nodes: list[dict], query: str) -> dict | None:
    needle = str(query or "").strip().casefold()
    if not needle:
        return None
    candidates = [node for node in nodes if node.get("center")]
    for node in candidates:
        if needle == str(node.get("text") or "").casefold() or needle == str(
                node.get("description") or "").casefold():
            return node
    for node in candidates:
        haystack = " ".join(str(node.get(key) or "") for key in ("text", "description", "resource_id"))
        if needle in haystack.casefold():
            return node
    return None


def _android_environment(config: dict) -> dict:
    serial = android_serial(config)
    if not serial:
        return {"connected": False}
    apps = android_apps()
    result = {"connected": True, "serial": serial, "apps": apps[:30]}
    activity = _adb(config, ["shell", "dumpsys", "activity", "activities"])
    if activity.get("ok"):
        for line in (activity.get("output") or "").splitlines():
            if "topResumedActivity" in line or "mResumedActivity" in line:
                result["activity"] = line.strip()
                break
    return result


def _android_screenshot(config: dict) -> dict:
    serial = android_serial(config)
    if not serial:
        return _tool_error("没有可用的 ADB Android 设备")
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = STATE_DIR / f"android-{uuid.uuid4().hex[:12]}.png"
    try:
        completed = subprocess.run(["adb", "-s", serial, "exec-out", "screencap", "-p"],
                                   capture_output=True, timeout=30, env=os.environ.copy())
    except Exception as error:
        return _tool_error(str(error))
    if completed.returncode != 0 or not completed.stdout:
        return _tool_error((completed.stderr or b"Android screenshot failed").decode("utf-8", "replace"))
    path.write_bytes(completed.stdout)
    os.chmod(path, 0o600)
    return {"ok": True, "output": {"path": str(path), "bytes": len(completed.stdout)}}


VOICE_DIR = STATE_DIR / "voice"
VOSK_MODEL_DIR = Path(os.environ.get(
    "CLAVIS_AGENT_VOSK_MODEL",
    str(Path.home() / ".local/share/clavis-agent/models/vosk-model-small-cn-0.22")))
ESPEAK_ROOT = Path(os.environ.get(
    "CLAVIS_AGENT_ESPEAK", str(Path.home() / ".local/clavis-voice/espeak-ng")))

_VOICE_LOCK = threading.Lock()
_VOICE_STATE = {
    "active": False,
    "partial": "",
    "text": "",
    "error": "",
    "started": 0.0,
    "seconds": 0.0,
    "stop": False,
}


def _voice_config(config: dict) -> dict:
    value = config.get("voice")
    return value if isinstance(value, dict) else {}


VOSK_LIB_PATH = Path(os.environ.get(
    "CLAVIS_AGENT_VOSK_LIB", str(Path.home() / ".local/share/clavis-agent/vendor/vosk/libvosk.so")))
_VOSK_LIB = None
_VOSK_MODEL_CACHE = None


def _vosk_lib():
    global _VOSK_LIB
    if _VOSK_LIB is not None:
        return _VOSK_LIB
    if not VOSK_LIB_PATH.exists():
        return None
    try:
        lib = ctypes.CDLL(str(VOSK_LIB_PATH))
    except OSError:
        return None
    lib.vosk_set_log_level.argtypes = [ctypes.c_int]
    lib.vosk_model_new.argtypes = [ctypes.c_char_p]
    lib.vosk_model_new.restype = ctypes.c_void_p
    lib.vosk_model_free.argtypes = [ctypes.c_void_p]
    lib.vosk_recognizer_new.argtypes = [ctypes.c_void_p, ctypes.c_float]
    lib.vosk_recognizer_new.restype = ctypes.c_void_p
    lib.vosk_recognizer_free.argtypes = [ctypes.c_void_p]
    lib.vosk_recognizer_accept_waveform.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    lib.vosk_recognizer_accept_waveform.restype = ctypes.c_int
    lib.vosk_recognizer_result.argtypes = [ctypes.c_void_p]
    lib.vosk_recognizer_result.restype = ctypes.c_char_p
    lib.vosk_recognizer_partial_result.argtypes = [ctypes.c_void_p]
    lib.vosk_recognizer_partial_result.restype = ctypes.c_char_p
    lib.vosk_recognizer_final_result.argtypes = [ctypes.c_void_p]
    lib.vosk_recognizer_final_result.restype = ctypes.c_char_p
    _VOSK_LIB = lib
    return lib


def _vosk_model():
    global _VOSK_MODEL_CACHE
    lib = _vosk_lib()
    if lib is None or not VOSK_MODEL_DIR.exists():
        return None
    if _VOSK_MODEL_CACHE is None:
        try:
            lib.vosk_set_log_level(-1)
            handle = lib.vosk_model_new(str(VOSK_MODEL_DIR).encode("utf-8"))
        except Exception:
            return None
        if not handle:
            return None
        _VOSK_MODEL_CACHE = handle
    return _VOSK_MODEL_CACHE


def _espeak_env() -> dict | None:
    binary = ESPEAK_ROOT / "usr/bin/espeak-ng"
    if not binary.exists():
        return None
    env = os.environ.copy()
    libdir = ESPEAK_ROOT / "usr/lib/aarch64-linux-gnu"
    existing = env.get("LD_LIBRARY_PATH", "")
    env["LD_LIBRARY_PATH"] = str(libdir) + (":" + existing if existing else "")
    env["ESPEAK_DATA_PATH"] = str(libdir)
    return env


def _tts_engine(config: dict) -> str:
    preferred = str(_voice_config(config).get("tts_engine") or "auto")
    if preferred not in ("auto", "espeak"):
        return ""
    if (ESPEAK_ROOT / "usr/bin/espeak-ng").exists():
        return "espeak"
    return ""


def _voice_capabilities() -> dict:
    return {
        "stt": _vosk_model() is not None,
        "tts": _tts_engine(load_config()) != "",
        "model_present": VOSK_MODEL_DIR.exists(),
        "model_dir": str(VOSK_MODEL_DIR),
    }


def _tts_clean(text: str) -> str:
    text = re.sub(r"```.*?```", " 代码省略 ", text or "", flags=re.S)
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\*\*?|__?|#{1,6} ", " ", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:600]


def _tts_speak(config: dict, text: str) -> dict:
    if _voice_config(config).get("enabled") is False:
        return _tool_error("语音功能未启用")
    text = _tts_clean(text)
    if not text:
        return _tool_error("没有可朗读的文本")
    engine = _tts_engine(config)
    if not engine:
        return _tool_error("没有可用的本地语音合成引擎")
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    output = VOICE_DIR / f"tts-{uuid.uuid4().hex[:12]}.wav"
    voice_cfg = _voice_config(config)
    command = [
        str(ESPEAK_ROOT / "usr/bin/espeak-ng"),
        "-v", str(voice_cfg.get("tts_voice") or "zh-cn"),
        "-s", str(int(voice_cfg.get("tts_speed") or 150)),
        "-a", "185", "-g", "4",
        "-w", str(output), "--", text,
    ]
    try:
        proc = subprocess.run(command, capture_output=True, timeout=30, env=_espeak_env())
    except Exception as error:
        return _tool_error(str(error))
    if proc.returncode != 0 or not output.exists() or output.stat().st_size == 0:
        message = proc.stderr.decode("utf-8", "replace").strip()[:200]
        return _tool_error(message or "语音合成失败")
    os.chmod(output, 0o600)
    # keep only the newest few clips
    clips = sorted(VOICE_DIR.glob("tts-*.wav"), key=lambda item: item.stat().st_mtime)
    for stale in clips[:-6]:
        try:
            stale.unlink()
        except OSError:
            pass
    return {"ok": True, "output": {"path": str(output), "engine": engine}}


def _rms(samples: array.array) -> int:
    if not samples:
        return 0
    total = 0
    for value in samples:
        total += value * value
    return int((total / len(samples)) ** 0.5)


def _voice_listen(config: dict) -> dict:
    voice_cfg = _voice_config(config)
    if voice_cfg.get("enabled") is False:
        return _tool_error("语音输入未启用")
    model = _vosk_model()
    if model is None:
        return _tool_error("本地语音识别模型未安装")
    with _VOICE_LOCK:
        if _VOICE_STATE["active"]:
            return _tool_error("语音会话正在进行中")
        _VOICE_STATE.update({
            "active": True, "partial": "", "text": "", "error": "",
            "stop": False, "started": time.time(), "seconds": 0.0,
        })
    try:
        return _voice_capture(config, model, voice_cfg)
    finally:
        _VOICE_STATE["active"] = False
        _VOICE_STATE["stop"] = False


def _voice_capture(config: dict, model, voice_cfg: dict) -> dict:
    lib = _vosk_lib()
    recognizer = lib.vosk_recognizer_new(model, 16000.0)
    if not recognizer:
        return _tool_error("无法创建语音识别器")
    source = str(voice_cfg.get("source") or "")
    command = ["parecord", "--raw", "--format=s16le", "--rate=16000",
               "--channels=1", "--file-format=raw"]
    if source:
        command += ["--device", source]
    try:
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception as error:
        return _tool_error(f"无法打开麦克风：{error}")

    chunk_bytes = 3200  # 100 ms of 16 kHz mono s16le
    threshold = max(150, int(voice_cfg.get("vad_threshold") or 500))
    silence_limit = max(300, int(voice_cfg.get("vad_silence_ms") or 800))
    max_seconds = max(5, int(voice_cfg.get("max_seconds") or 20))
    noise = []
    level = threshold
    speech_started = False
    speech_ms = 0
    silence_ms = 0
    result_text = ""
    started = _VOICE_STATE["started"]
    try:
        while True:
            if _VOICE_STATE["stop"]:
                break
            chunk = proc.stdout.read(chunk_bytes)
            if not chunk:
                break
            samples = array.array("h")
            samples.frombytes(chunk)
            rms = _rms(samples)
            elapsed = time.time() - started
            if not speech_started:
                if len(noise) < 15:
                    noise.append(rms)
                    level = max(threshold, sum(noise) / len(noise) * 3.0 + 120)
                if rms > level:
                    speech_started = True
                elif elapsed > 8.0:
                    _VOICE_STATE["error"] = "没有检测到说话"
                    break
            else:
                speech_ms += 100
                if rms > level * 0.55:
                    silence_ms = 0
                else:
                    silence_ms += 100
                    if silence_ms >= silence_limit and speech_ms >= 400:
                        break
                if elapsed >= max_seconds:
                    break
            if lib.vosk_recognizer_accept_waveform(recognizer, chunk, len(chunk)):
                raw = lib.vosk_recognizer_result(recognizer)
                data = json.loads(raw.decode("utf-8")) if raw else {}
                result_text = (data.get("text") or result_text).strip() or result_text
            else:
                raw = lib.vosk_recognizer_partial_result(recognizer)
                data = json.loads(raw.decode("utf-8")) if raw else {}
                partial = str(data.get("text") or "")
                if partial:
                    _VOICE_STATE["partial"] = partial
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            pass
        raw = lib.vosk_recognizer_final_result(recognizer)
        final = json.loads(raw.decode("utf-8")).get("text", "") if raw else ""
        text = (result_text or str(final)).strip()
        try:
            lib.vosk_recognizer_free(recognizer)
        except Exception:
            pass
        _VOICE_STATE["text"] = text
        _VOICE_STATE["seconds"] = round(time.time() - started, 2)
    return {
        "ok": True,
        "output": {
            "text": _VOICE_STATE["text"],
            "partial": _VOICE_STATE["partial"],
            "seconds": _VOICE_STATE["seconds"],
            "error": _VOICE_STATE["error"],
            "stopped": bool(_VOICE_STATE["stop"]),
        },
    }


def session_path(session_id: str) -> Path:
    safe = re.sub(r"[^a-zA-Z0-9_.-]", "_", session_id or "")
    return SESSIONS_DIR / (safe + ".json")


def load_history(session_id: str) -> list[dict]:
    try:
        data = json.loads(session_path(session_id).read_text(encoding="utf-8"))
        if isinstance(data, list):
            return [m for m in data if isinstance(m, dict) and m.get("role") in ("user", "assistant")]
    except (OSError, ValueError):
        pass
    return []


def save_history(session_id: str, messages: list[dict]) -> None:
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    path = session_path(session_id)
    path.write_text(json.dumps(messages[-MAX_HISTORY:], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


def endpoint(base_url: str, style: str) -> str:
    base = (base_url or "").rstrip("/")
    if not base:
        raise ValueError("请先在设置中填写 Base URL")
    if style == "responses":
        return base if base.endswith("/responses") else base + "/responses"
    return base if base.endswith("/chat/completions") else base + "/chat/completions"


def extract_responses_text(payload: dict) -> str:
    direct = payload.get("output_text")
    if isinstance(direct, str) and direct.strip():
        return direct.strip()
    pieces = []
    for item in payload.get("output", []) or []:
        if not isinstance(item, dict):
            continue
        for content in item.get("content", []) or []:
            if isinstance(content, dict):
                text = content.get("text")
                if isinstance(text, str) and text:
                    pieces.append(text)
    return "".join(pieces).strip()



def _computer_config(config: dict) -> dict:
    value = config.get("computer_control")
    return value if isinstance(value, dict) else {}


def _run_command(command, config: dict, input_text: str | None = None, shell: bool = False) -> dict:
    cc = _computer_config(config)
    timeout = max(3, min(120, int(cc.get("timeout") or 20)))
    cwd = str(cc.get("working_dir") or "").strip() or None
    if cwd:
        cwd = os.path.expanduser(cwd)
    try:
        completed = subprocess.run(command, shell=shell, cwd=cwd, input=input_text,
                                   capture_output=True, text=True, timeout=timeout,
                                   env=os.environ.copy())
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"命令超时（{timeout} 秒）"}
    except FileNotFoundError as error:
        return {"ok": False, "error": f"找不到命令：{error.filename or command}"}
    except Exception as error:
        return {"ok": False, "error": str(error)}
    stdout = (completed.stdout or "").strip()
    stderr = (completed.stderr or "").strip()
    if completed.returncode != 0:
        detail = (stderr or stdout or f"退出码 {completed.returncode}")[:8000]
        return {"ok": False, "error": detail}
    output = stdout
    if stderr:
        output = (output + "\n" + stderr).strip()
    return {"ok": True, "output": output[:12000]}


def _niri_json(command: list[str], config: dict) -> dict:
    return _run_command(["niri", "msg", "-j"] + command, config)


def _niri_action(command: list[str], config: dict) -> dict:
    return _run_command(["niri", "msg", "action"] + command, config)


def _tool_error(message: str) -> dict:
    return {"ok": False, "error": message}


def _tool_specs(config: dict, session_id: str = "") -> list[dict]:
    cc = _computer_config(config)
    if cc.get("enabled") is False:
        return []
    specs = []

    def add(name, description, parameters):
        specs.append({"type": "function", "function": {"name": name, "description": description,
                                                         "parameters": parameters}})

    add("list_installed_apps", "List or search applications installed in the user's desktop environment. "
        "Use this before opening an app when the user mentions an application by name; installed apps may "
        "not have an open window yet.",
        {"type": "object", "properties": {"query": {"type": "string",
                                                    "description": "Optional name/id substring, e.g. QQ音乐"},
                                          "limit": {"type": "integer", "description": "Maximum results"}},
         "additionalProperties": False})

    if cc.get("allow_android", True):
        add("android_list_apps", "List Android/Droidloom applications and their package/component names.",
            {"type": "object", "properties": {"query": {"type": "string",
                                                        "description": "Optional app/package substring"}},
             "additionalProperties": False})
        add("android_current_activity", "Show the current Android foreground activity.",
            {"type": "object", "properties": {}, "additionalProperties": False})
        add("android_ui_dump", "Dump the current Android application UI hierarchy. Use the returned "
            "node text/description/center coordinates to understand and operate inside an app.",
            {"type": "object", "properties": {}, "additionalProperties": False})
        add("android_tap", "Tap an Android screen coordinate. Coordinates are in the Android UI bounds, "
            "not the host window pixels.",
            {"type": "object", "properties": {"x": {"type": "integer"}, "y": {"type": "integer"}},
             "required": ["x", "y"], "additionalProperties": False})
        add("android_find_and_tap", "Find a text/description in the current Android UI and tap its center. "
            "Use this as the primary way to operate an Android app.",
            {"type": "object", "properties": {"query": {"type": "string",
                                                        "description": "Visible text, content description, or resource id"}},
             "required": ["query"], "additionalProperties": False})
        add("android_swipe", "Swipe in the current Android application between two Android coordinates.",
            {"type": "object", "properties": {"x1": {"type": "integer"}, "y1": {"type": "integer"},
                                              "x2": {"type": "integer"}, "y2": {"type": "integer"},
                                              "duration_ms": {"type": "integer"}},
             "required": ["x1", "y1", "x2", "y2"], "additionalProperties": False})
        add("android_keyevent", "Send an Android keyevent by name (home, back, enter, tab, search, "
            "power, volumeup, volumedown, up, down, left, right) or numeric keycode.",
            {"type": "object", "properties": {"key": {"type": "string"}},
             "required": ["key"], "additionalProperties": False})
        add("android_input_text", "Type ASCII text into the focused Android input field. For Chinese "
            "text, use the app's own search UI or clipboard where available.",
            {"type": "object", "properties": {"text": {"type": "string"}},
             "required": ["text"], "additionalProperties": False})
        add("android_screenshot", "Capture a screenshot of the current Android app and return the local "
            "PNG path. The image can be inspected by the user or a vision-capable model.",
            {"type": "object", "properties": {}, "additionalProperties": False})

    if cc.get("allow_windows", True):
        add("list_windows", "List open Niri windows with their id, title, app_id and focused state. "
            "Call this before focusing or closing a window.",
            {"type": "object", "properties": {}, "additionalProperties": False})
        add("focus_window", "Focus an open Niri window by its numeric id.",
            {"type": "object", "properties": {"id": {"type": "integer", "description": "Niri window id"}},
             "required": ["id"], "additionalProperties": False})
        add("close_window", "Close an open Niri window by its numeric id.",
            {"type": "object", "properties": {"id": {"type": "integer", "description": "Niri window id"}},
             "required": ["id"], "additionalProperties": False})
        add("toggle_fullscreen", "Toggle fullscreen for an open Niri window by its numeric id.",
            {"type": "object", "properties": {"id": {"type": "integer", "description": "Niri window id"}},
             "required": ["id"], "additionalProperties": False})

    if cc.get("allow_launch", True):
        add("open_app", "Launch an installed application. Prefer desktop_id (from list_installed_apps) "
            "or name; command is a fallback for an executable. Never assume an app is missing just because "
            "list_windows does not show it.",
            {"type": "object", "properties": {
                "desktop_id": {"type": "string", "description": "Desktop entry id, e.g. org.gnome.Nautilus.desktop"},
                "name": {"type": "string", "description": "Display name, e.g. QQ音乐 or 网易云音乐"},
                "command": {"type": "string", "description": "Fallback executable command"}},
             "additionalProperties": False})
        add("open_url", "Open a URL in the user's default browser.",
            {"type": "object", "properties": {"url": {"type": "string", "description": "http(s) URL"}},
             "required": ["url"], "additionalProperties": False})

    if cc.get("allow_documents", True):
        add("create_document", "Create a Word (.docx), PowerPoint (.pptx), PDF or web page (.html) "
            "document on the user's machine from markdown content. Headings, paragraphs, "
            "bold/italic and lists are supported; for pptx each '# ' heading starts a new slide. "
            "The html format produces a standalone web page that can be previewed in the chat and "
            "opened in a browser. Relative filenames are saved under ~/Documents. Set open=true to "
            "open the file after creating it.",
            {"type": "object", "properties": {
                "format": {"type": "string", "enum": ["docx", "pptx", "pdf", "html"],
                           "description": "Target document format"},
                "filename": {"type": "string",
                             "description": "Output file name, e.g. 周报.docx; default auto name in ~/Documents"},
                "title": {"type": "string", "description": "Document title"},
                "content": {"type": "string", "description": "Document body in markdown"},
                "open": {"type": "boolean", "description": "Open the generated file when done"}},
             "required": ["format", "content"], "additionalProperties": False})

    if cc.get("allow_web", True):
        add("web_search", "Search the public web (Bing, with Baidu fallback) and return titles, "
            "URLs and snippets. Use for current events, news, prices, software versions, weather "
            "and any fact you are unsure about.",
            {"type": "object", "properties": {
                "query": {"type": "string", "description": "Search keywords, Chinese or English"},
                "limit": {"type": "integer", "description": "Maximum results (default 6)"}},
             "required": ["query"], "additionalProperties": False})
        add("read_url", "Fetch a web page and return its text content (HTML converted to plain "
            "text, capped). Use after web_search to read a promising result in detail.",
            {"type": "object", "properties": {
                "url": {"type": "string", "description": "http(s) URL to read"}},
             "required": ["url"], "additionalProperties": False})

    if cc.get("allow_config", True):
        existing_servers = "；".join(
            f"{row['name']}（{'启用' if row['enabled'] else '停用'}"
            f"{'，' + str(row['tool_count']) + ' 个工具' if row['tool_count'] else ''}）"
            for row in _mcp_summary(config)) or "（无）"
        existing_skills = "；".join(
            f"{item['name']}（{'启用' if item['enabled'] else '停用'}）"
            for item in _discover_skills(config)) or "（无）"
        add("manage_mcp", "Manage the user's MCP server settings from the conversation: list, add, "
            "update, remove, enable or disable MCP servers. Use a stdio command (e.g. "
            "'npx -y @modelcontextprotocol/server-memory') or a streamable HTTP url. Changes are "
            "saved to settings and appear in Settings → Agent → MCP servers. Always call this "
            "tool to apply a change (enable/disable/remove/add) instead of only describing it. "
            "Existing servers: " + existing_servers + ".",
            {"type": "object", "properties": {
                "action": {"type": "string",
                           "enum": ["list", "add", "update", "remove", "enable", "disable"]},
                "name": {"type": "string", "description": "Server name (settings key)"},
                "command": {"type": "string", "description": "stdio launch command"},
                "url": {"type": "string", "description": "Streamable HTTP MCP endpoint"},
                "args": {"type": "array", "items": {"type": "string"},
                         "description": "Extra stdio arguments"},
                "env": {"type": "object", "description": "Environment variables for the server"},
                "enabled": {"type": "boolean", "description": "Enable the server"}},
             "required": ["action"], "additionalProperties": False})
        add("manage_skill", "Manage the user's Agent skills (SKILL.md instruction folders) from the "
            "conversation: list, create, update, remove, enable or disable. Skills live in "
            "~/.local/share/clavis-agent/skills and appear in Settings → Agent → Agent skills. "
            "Always call this tool to apply a change (enable/disable/remove/create/update) "
            "instead of only describing it. Call load_skill afterwards to use a new skill's "
            "instructions. Existing skills: " + existing_skills + ".",
            {"type": "object", "properties": {
                "action": {"type": "string",
                           "enum": ["list", "create", "update", "remove", "enable", "disable"]},
                "name": {"type": "string",
                         "description": "Skill name: lowercase letters, digits, - or _"},
                "description": {"type": "string",
                                "description": "Short description shown in the skill index"},
                "content": {"type": "string",
                            "description": "Skill instructions in markdown (SKILL.md body)"},
                "enabled": {"type": "boolean", "description": "Enable the skill"}},
             "required": ["action"], "additionalProperties": False})

    if _mcp_config(config).get("enabled") is not False:
        specs.extend(_mcp_all_tools(config))

    skill_index = _discover_skills(config)
    if skill_index:
        summary = "；".join(f"{item['name']} — {item['description'] or '（无描述）'}"
                            for item in skill_index if item["enabled"])
        add("load_skill", "Load the full instructions of a user-installed skill before doing that "
            "kind of task. Available skills: " + summary[:3000],
            {"type": "object", "properties": {
                "name": {"type": "string", "description": "Skill name"},
                "resource": {"type": "string",
                             "description": "Optional file inside the skill folder to read"}},
             "required": ["name"], "additionalProperties": False})

    if cc.get("allow_input", True):
        add("type_text", "Type text into the currently focused application using the Wayland input method.",
            {"type": "object", "properties": {"text": {"type": "string", "description": "Text to type"}},
             "required": ["text"], "additionalProperties": False})
        add("press_key", "Press one key in the currently focused application. Examples: Return, Escape, "
            "Tab, BackSpace, Left, Right, Up, Down. Use type_text for normal text.",
            {"type": "object", "properties": {"key": {"type": "string", "description": "wtype key name"}},
             "required": ["key"], "additionalProperties": False})

    if cc.get("allow_clipboard", True):
        add("set_clipboard", "Put text on the Wayland clipboard.",
            {"type": "object", "properties": {"text": {"type": "string", "description": "Clipboard text"}},
             "required": ["text"], "additionalProperties": False})
        add("get_clipboard", "Read the current Wayland clipboard as text.",
            {"type": "object", "properties": {}, "additionalProperties": False})

    if cc.get("allow_audio", True):
        add("list_audio_devices", "List the current PipeWire/PulseAudio output devices and the default sink.",
            {"type": "object", "properties": {}, "additionalProperties": False})
        add("set_default_audio_device", "Select the default audio output device by its sink name from "
            "list_audio_devices.",
            {"type": "object", "properties": {"name": {"type": "string",
                                                       "description": "PulseAudio/PipeWire sink name"}},
             "required": ["name"], "additionalProperties": False})
        add("set_audio_volume", "Set the default audio output volume as a percentage (0-150).",
            {"type": "object", "properties": {"percent": {"type": "integer",
                                                          "description": "Volume percentage"}},
             "required": ["percent"], "additionalProperties": False})

    if cc.get("allow_local_agents", True):
        add("list_local_agents", "List the coding Agent CLIs installed on this machine and whether they "
            "are callable. Call this before delegating work if unsure. Available: "
            + _local_agents_summary() + ".",
            {"type": "object", "properties": {}, "additionalProperties": False})
        add("run_local_agent", "Delegate a concrete coding/ops task to another Agent CLI installed on "
            "this machine and return its output. Use this when the user explicitly asks Codex, Claude "
            "Code, OpenCode, DSH, WorkBuddy or another local agent to do the work, or when a second "
            "coding agent is clearly better for the task. Pass a complete, self-contained task and the "
            "project cwd. This runs non-interactively with a timeout. Available: "
            + _local_agents_summary() + ".",
            {"type": "object", "properties": {
                "agent": {"type": "string", "description": "Configured local agent id, e.g. codex/claude/opencode"},
                "task": {"type": "string", "description": "Complete task instructions for that agent"},
                "cwd": {"type": "string", "description": "Project working directory; defaults to the Agent working dir"}},
             "required": ["agent", "task"], "additionalProperties": False})

    if cc.get("allow_shell", False):
        add("run_shell", "Run a shell command on the user's machine. Only available when the user has "
            "explicitly enabled shell access in Agent settings. Prefer the narrow desktop tools first.",
            {"type": "object", "properties": {"command": {"type": "string",
                                                          "description": "Shell command to execute"}},
             "required": ["command"], "additionalProperties": False})
    if _SESSION_ATTACHMENTS.get(str(session_id or "")):
        add("read_attachment", "Read the text content of a file the user attached in this session. "
            "Text files are returned verbatim; PDF and Office documents (docx/pptx/xlsx) are "
            "extracted locally. Only paths registered by the user's attachments are allowed.",
            {"type": "object", "properties": {"path": {"type": "string",
                                                       "description": "Attachment path from the session"}},
             "required": ["path"], "additionalProperties": False})
    return specs


def _document_output_path(raw: str, fmt: str) -> Path:
    name = str(raw or "").strip()
    if not name:
        name = "clavis-" + time.strftime("%Y%m%d-%H%M%S") + "." + fmt
    path = Path(name).expanduser()
    if not path.is_absolute():
        path = Path.home() / "Documents" / path
    if path.suffix.lower() != "." + fmt:
        path = path.with_suffix("." + fmt)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path.resolve()


def _pandoc_document(fmt: str, out_path: Path, title: str, content: str, timeout: int) -> str | None:
    if not PANDOC_BIN.exists():
        return "pandoc 未安装，无法生成 Word/PPT 文档"
    text = content
    if title and not re.match(r"^#\s", text.lstrip()):
        text = f"# {title}\n\n{text}"
    if fmt == "pptx" and not re.search(r"^#\s", text, re.M):
        text = "# 演示文稿\n\n" + text
    handle_fd, md_path = tempfile.mkstemp(suffix=".md", prefix="clavis-doc-")
    try:
        with os.fdopen(handle_fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        env = os.environ.copy()
        extra = os.pathsep.join(PANDOC_LIB_DIRS)
        env["LD_LIBRARY_PATH"] = (extra + os.pathsep + env["LD_LIBRARY_PATH"]
                                  if env.get("LD_LIBRARY_PATH") else extra)
        args = [str(PANDOC_BIN), md_path, "-t", ("html5" if fmt == "html" else fmt)]
        if fmt == "html":
            args.append("--standalone")
            if title:
                args.append("--metadata")
                args.append("title=" + title)
        args.append("-o")
        args.append(str(out_path))
        completed = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout or f"退出码 {completed.returncode}")[:500]
            return f"pandoc 转换失败：{detail}"
    except subprocess.TimeoutExpired:
        return f"pandoc 转换超时（{timeout} 秒）"
    except Exception as error:
        return str(error)
    finally:
        try:
            os.unlink(md_path)
        except OSError:
            pass
    return None


def _render_pdf(out_path: Path, title: str, content: str) -> str | None:
    try:
        if str(REPORTLAB_VENDOR_DIR) not in sys.path:
            sys.path.insert(0, str(REPORTLAB_VENDOR_DIR))
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.units import mm
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer
    except Exception as error:
        return f"PDF 渲染库不可用：{error}"
    font_name = "Helvetica"
    for font_path, name in PDF_FONT_CANDIDATES:
        try:
            if font_path.endswith(".ttc"):
                pdfmetrics.registerFont(TTFont(name, font_path, subfontIndex=0))
            else:
                pdfmetrics.registerFont(TTFont(name, font_path))
            font_name = name
            break
        except Exception:
            continue

    def inline(text: str) -> str:
        text = html.escape(text, quote=False)
        text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
        text = re.sub(r"(?<!\*)\*([^*\s][^*]*)\*(?!\*)", r"<i>\1</i>", text)
        return text

    body = ParagraphStyle("body", fontName=font_name, fontSize=11.5, leading=18, spaceAfter=6)
    headings = [ParagraphStyle(f"h{level}", parent=body, fontSize=size, leading=size + 7,
                               spaceBefore=10, spaceAfter=6)
                for level, size in ((1, 20), (2, 16), (3, 13.5), (4, 12))]
    quote_style = ParagraphStyle("quote", parent=body, leftIndent=14,
                                 textColor=colors.HexColor("#555555"))
    bullet_style = ParagraphStyle("bullet", parent=body, leftIndent=16, bulletIndent=4,
                                  bulletFontName=font_name)

    text = content
    if title and not re.match(r"^#\s", text.lstrip()):
        text = f"# {title}\n\n{text}"
    lines = text.replace("\r\n", "\n").split("\n")
    flowables: list = []
    paragraph: list[str] = []
    number = 0

    def flush():
        nonlocal paragraph, number
        if paragraph:
            flowables.append(Paragraph(inline(" ".join(paragraph)), body))
            paragraph = []
        number = 0

    for line in lines:
        stripped = line.strip()
        if not stripped:
            flush()
            continue
        match = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if match:
            flush()
            flowables.append(Paragraph(inline(match.group(2)), headings[len(match.group(1)) - 1]))
            continue
        if re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", stripped):
            flush()
            flowables.append(Spacer(1, 4))
            flowables.append(HRFlowable(width="100%", thickness=0.7,
                                        color=colors.HexColor("#999999")))
            flowables.append(Spacer(1, 6))
            continue
        match = re.match(r"^[-*+]\s+(.*)$", stripped)
        if match:
            flush()
            flowables.append(Paragraph(inline(match.group(1)), bullet_style, bulletText="•"))
            continue
        match = re.match(r"^(\d+)[.)]\s+(.*)$", stripped)
        if match:
            flush()
            try:
                number = int(match.group(1))
            except ValueError:
                number += 1
            flowables.append(Paragraph(inline(match.group(2)), bullet_style,
                                       bulletText=f"{number}."))
            continue
        match = re.match(r"^>\s?(.*)$", stripped)
        if match:
            flush()
            flowables.append(Paragraph(inline(match.group(1)), quote_style))
            continue
        paragraph.append(stripped)
    flush()

    try:
        document = SimpleDocTemplate(str(out_path), pagesize=A4,
                                     leftMargin=20 * mm, rightMargin=20 * mm,
                                     topMargin=18 * mm, bottomMargin=18 * mm,
                                     title=title or out_path.stem, author="Clavis Agent")
        document.build(flowables)
    except Exception as error:
        return f"PDF 生成失败：{error}"
    return None


def _spawn_open(config: dict, path: str) -> dict:
    result = _niri_action(["spawn", "--", "xdg-open", path], config)
    if result.get("ok"):
        return result
    try:
        subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        return {"ok": True, "output": "opened via xdg-open"}
    except Exception as error:
        return {"ok": False, "error": str(error)}


def _create_document(arguments: dict, config: dict) -> dict:
    fmt = str(arguments.get("format") or "").strip().lower()
    if fmt not in ("docx", "pptx", "pdf", "html"):
        return _tool_error("format 必须是 docx、pptx、pdf 或 html")
    content = str(arguments.get("content") or "").strip()
    if not content:
        return _tool_error("缺少文档内容")
    title = str(arguments.get("title") or "").strip()
    try:
        out_path = _document_output_path(str(arguments.get("filename") or ""), fmt)
    except OSError as error:
        return _tool_error(str(error))
    timeout = max(10, min(120, int(_computer_config(config).get("timeout") or 20)))
    if fmt == "pdf":
        error = _render_pdf(out_path, title, content)
    else:
        error = _pandoc_document(fmt, out_path, title, content, timeout)
    if error:
        return _tool_error(error)
    opened = False
    if arguments.get("open"):
        result = _spawn_open(config, str(out_path))
        opened = bool(result.get("ok"))
    return {"ok": True, "output": {"path": str(out_path), "format": fmt,
                                   "bytes": out_path.stat().st_size, "opened": opened}}


def _artifact_kind(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in IMAGE_SUFFIXES:
        return "image"
    if suffix in (".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"):
        return "video"
    if suffix in (".mp3", ".wav", ".ogg", ".flac", ".m4a", ".opus"):
        return "audio"
    if suffix in (".html", ".htm"):
        return "webpage"
    if suffix in DOCUMENT_SUFFIXES:
        return "document"
    return "file"


def _video_thumbnail(path: Path) -> str | None:
    directory = STATE_DIR / "artifacts"
    directory.mkdir(parents=True, exist_ok=True)
    try:
        digest = hashlib.sha1(f"{path}|{path.stat().st_mtime_ns}".encode()).hexdigest()[:16]
    except OSError:
        return None
    thumb = directory / (digest + ".png")
    if thumb.is_file() and thumb.stat().st_size > 0:
        return str(thumb)
    try:
        subprocess.run(["ffmpeg", "-y", "-ss", "1", "-i", str(path), "-frames:v", "1",
                        "-vf", "scale=480:-2", str(thumb)],
                       capture_output=True, timeout=15)
    except Exception:
        return None
    return str(thumb) if thumb.is_file() and thumb.stat().st_size > 0 else None


def _artifact_entry(path_str: str) -> dict | None:
    raw = str(path_str or "").strip()
    if not raw.startswith("/"):
        return None
    path = Path(raw)
    try:
        if not path.is_file():
            return None
    except OSError:
        return None
    entry = {"name": path.name, "path": str(path), "kind": _artifact_kind(path),
             "bytes": path.stat().st_size}
    if entry["kind"] == "video":
        preview = _video_thumbnail(path)
        if preview:
            entry["preview"] = preview
    elif entry["kind"] == "document":
        excerpt = _extract_document_text(path, 600)
        if excerpt and excerpt.strip():
            entry["excerpt"] = " ".join(excerpt.split())[:600]
    elif entry["kind"] == "webpage":
        entry.update(_webpage_preview(path))
    return entry


def _webpage_preview(path: Path) -> dict:
    try:
        data = path.read_bytes()[:200_000]
    except OSError:
        return {}
    text = data.decode("utf-8", "replace")
    title = ""
    match = re.search(r"<title[^>]*>(.*?)</title>", text, re.S | re.I)
    if match:
        title = " ".join(re.sub(r"<[^>]+>", " ", match.group(1)).split())
    body = text
    body_match = re.search(r"<body[^>]*>(.*)</body>", text, re.S | re.I)
    if body_match:
        body = body_match.group(1)
    body = re.sub(r"(?is)<(script|style|svg)[^>]*>.*?</\1>", " ", body)
    body = re.sub(r"(?is)</?(html|head|body|meta|link|title|!doctype)[^>]*>", " ", body)
    body = re.sub(r'(?is)<h1[^>]*class="title"[^>]*>.*?</h1>', " ", body)
    if not title:
        for tag in ("h1", "h2"):
            match = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", body, re.S | re.I)
            if match:
                title = " ".join(re.sub(r"<[^>]+>", " ", match.group(1)).split())
                break
    return {"title": title or path.stem, "html": body.strip()[:32_000]}


_REPLY_PATH_RE = re.compile(
    r"(?<![\w:/.~])(?:file://)?(?:~/|/(?!/))[^\s\"'<>()\[\]{}`|，。；！？、：”“‘’]+")


def _reply_files(reply: str, artifacts: list[dict]) -> list[dict]:
    """Find existing local files mentioned in the reply text (for click-to-open chips)."""
    seen = {str(item.get("path") or "") for item in artifacts if isinstance(item, dict)}
    files = []
    for match in _REPLY_PATH_RE.finditer(str(reply or "")):
        raw = match.group(0).rstrip(".,;:!?)]}>\"'")
        if raw.startswith("file://"):
            raw = raw[7:]
        if not raw or len(raw) < 4:
            continue
        path = Path(raw).expanduser()
        try:
            if not path.is_file():
                continue
            resolved = str(path.resolve())
            if resolved in seen:
                continue
            seen.add(resolved)
            files.append({"name": path.name, "path": resolved})
        except OSError:
            continue
        if len(files) >= 8:
            break
    return files


def _collect_artifacts(result, seen: set) -> list[dict]:
    if not isinstance(result, dict):
        return []
    output = result.get("output")
    candidates = []
    if isinstance(output, dict) and output.get("path"):
        candidates.append(output["path"])
    elif isinstance(output, list):
        candidates.extend(item.get("path") for item in output
                          if isinstance(item, dict) and item.get("path"))
    entries = []
    for candidate in candidates:
        entry = _artifact_entry(candidate)
        if entry and entry["path"] not in seen:
            seen.add(entry["path"])
            entries.append(entry)
    return entries


WEB_UA = ("Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")


def _html_to_text(data: bytes, limit: int) -> str:
    charset = "utf-8"
    head = data[:4096].lower()
    match = re.search(rb'charset=["\']?([a-z0-9_-]+)', head)
    if match:
        charset = match.group(1).decode("ascii", "replace")
    text = data.decode(charset, "replace")
    text = re.sub(r"(?is)<(script|style|noscript|svg)[^>]*>.*?</\1>", " ", text)
    text = re.sub(r"(?i)<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>", "\n", text)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    text = re.sub(r"[ \t\x0c]+", " ", text)
    text = re.sub(r"\n\s*\n+", "\n", text)
    return text.strip()[:limit]


def _http_get(url: str, timeout: int, max_bytes: int = 2_000_000):
    request = urllib.request.Request(url, headers={
        "User-Agent": WEB_UA,
        "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.7",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    })
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read(max_bytes)


def _web_search(query: str, limit: int) -> list[dict]:
    quoted = urllib.parse.quote(query)
    results = []
    try:
        page = _http_get(f"https://cn.bing.com/search?q={quoted}&count={max(3, limit)}", 12)
        for item in re.findall(r'<li class="b_algo".*?</li>', page.decode("utf-8", "replace"), re.S):
            link = re.search(r'<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', item, re.S)
            if not link:
                continue
            title = html.unescape(re.sub(r"<[^>]+>", "", link.group(2))).strip()
            snippet_match = re.search(r'<p[^>]*>(.*?)</p>', item, re.S)
            snippet = html.unescape(re.sub(r"<[^>]+>", "", snippet_match.group(1))).strip() \
                if snippet_match else ""
            results.append({"title": title, "url": link.group(1), "snippet": snippet[:300]})
            if len(results) >= limit:
                break
    except Exception:
        results = []
    if results:
        return results
    try:
        page = _http_get(f"https://www.baidu.com/s?wd={quoted}&rn={max(3, limit)}", 12)
        page_text = page.decode("utf-8", "replace")
        for container in re.findall(r'<div class="result[^"]*".*?(?=<div class="result|<div id="page")',
                                    page_text, re.S):
            link = re.search(r'<h3[^>]*>.*?<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', container, re.S)
            if not link:
                continue
            title = html.unescape(re.sub(r"<[^>]+>", "", link.group(2))).strip()
            body = html.unescape(re.sub(r"<[^>]+>", " ", container))
            body = re.sub(r"\s+", " ", body).strip()
            snippet = body[len(title):].strip()[:300] if body.startswith(title) else body[:300]
            results.append({"title": title, "url": link.group(1), "snippet": snippet})
            if len(results) >= limit:
                break
    except Exception:
        pass
    return results


def _read_url(url: str) -> tuple[str, str, int]:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise ValueError("只支持 http/https URL")
    data = _http_get(url, 20)
    head = data[:512].lower()
    if b"<html" in head or b"<!doctype" in head or b"<body" in head:
        text = _html_to_text(data, 200_000)
    else:
        text = data.decode("utf-8", "replace")[:200_000]
    return url, text, len(data)


SKILLS_DIR = Path(os.environ.get(
    "CLAVIS_AGENT_SKILLS", str(Path.home() / ".local/share/clavis-agent/skills")))
_MCP_LOCK = threading.RLock()
_MCP_STATE: dict[str, dict] = {}
_MCP_TOOL_MAP: dict[str, tuple[str, str]] = {}
_MCP_TTL = 600.0


def _mcp_config(config: dict) -> dict:
    value = config.get("mcp")
    return value if isinstance(value, dict) else {}


def _mcp_servers_config(config: dict) -> dict:
    value = _mcp_config(config).get("servers")
    return value if isinstance(value, dict) else {}


def _sanitize_mcp_name(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]", "_", name)[:24]


def _mcp_queue_for(state: dict, message: dict) -> None:
    msg_id = message.get("id")
    if msg_id is None:
        return
    state["inbox"].setdefault(msg_id, []).append(message)


def _mcp_reader(state: dict, proc) -> None:
    try:
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if isinstance(message, dict):
                _mcp_queue_for(state, message)
    except Exception:
        pass


def _mcp_spawn(name: str, cfg: dict) -> dict:
    command = str(cfg.get("command") or "").strip()
    if not command:
        raise RuntimeError("缺少启动命令")
    argv = shlex.split(command) + [str(item) for item in (cfg.get("args") or [])]
    env = os.environ.copy()
    local_bin = str(Path.home() / ".local/bin")
    if local_bin not in env.get("PATH", ""):
        env["PATH"] = local_bin + os.pathsep + env.get("PATH", "")
    extra = cfg.get("env")
    if isinstance(extra, dict):
        env.update({str(k): str(v) for k, v in extra.items()})
    log_dir = STATE_DIR / "mcp"
    log_dir.mkdir(parents=True, exist_ok=True)
    stderr_log = open(log_dir / (re.sub(r"[^a-zA-Z0-9_-]", "_", name) + ".stderr.log"), "ab")
    proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=stderr_log, text=True, bufsize=1,
                            cwd=str(Path.home()), env=env, start_new_session=True)
    stderr_log.close()
    state = {"proc": proc, "url": "", "session": None, "next_id": 0,
             "inbox": {}, "lock": threading.Lock()}
    threading.Thread(target=_mcp_reader, args=(state, proc), daemon=True).start()
    return state


def _mcp_http_request(state: dict, method: str, params=None, notify: bool = False,
                      timeout: int = 15):
    message: dict = {"jsonrpc": "2.0", "method": method}
    if notify:
        message_id = None
    else:
        state["next_id"] += 1
        message_id = state["next_id"]
        message["id"] = message_id
    if params is not None:
        message["params"] = params
    headers = {"Content-Type": "application/json",
               "Accept": "application/json, text/event-stream", "User-Agent": WEB_UA}
    if state.get("session"):
        headers["Mcp-Session-Id"] = state["session"]
    request = urllib.request.Request(state["url"], method="POST",
                                     data=json.dumps(message).encode("utf-8"), headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        session = response.headers.get("Mcp-Session-Id")
        if session:
            state["session"] = session
        raw = response.read(4_000_000)
    if notify:
        return None
    candidates = []
    try:
        candidates.append(json.loads(raw.decode("utf-8", "replace")))
    except ValueError:
        for match in re.findall(r"(?m)^data:\s*(.*)$", raw.decode("utf-8", "replace")):
            try:
                candidates.append(json.loads(match))
            except ValueError:
                continue
    for candidate in candidates:
        if isinstance(candidate, dict) and candidate.get("id") == message_id:
            if "error" in candidate:
                raise RuntimeError(str(candidate["error"])[:300])
            return candidate.get("result") or {}
    raise RuntimeError("服务器没有返回有效响应")


def _mcp_request(state: dict, method: str, params=None, timeout: int = 15, notify: bool = False):
    if state.get("url"):
        return _mcp_http_request(state, method, params, notify, timeout)
    message: dict = {"jsonrpc": "2.0", "method": method}
    waiter_key = None
    if not notify:
        state["next_id"] += 1
        waiter_key = state["next_id"]
        message["id"] = waiter_key
    if params is not None:
        message["params"] = params
    with state["lock"]:
        state["proc"].stdin.write(json.dumps(message, ensure_ascii=False) + "\n")
        state["proc"].stdin.flush()
    if notify:
        return None
    deadline = time.time() + timeout
    while True:
        bucket = state["inbox"].get(waiter_key)
        if bucket:
            response = bucket.pop(0)
            if "error" in response:
                raise RuntimeError(str(response["error"])[:300])
            return response.get("result") or {}
        if time.time() >= deadline:
            raise RuntimeError(f"响应超时（{timeout} 秒）")
        time.sleep(0.05)


def _mcp_shutdown(name: str) -> None:
    with _MCP_LOCK:
        state = _MCP_STATE.pop(name, None)
        for full_name in list(_MCP_TOOL_MAP):
            if _MCP_TOOL_MAP[full_name][0] == name:
                del _MCP_TOOL_MAP[full_name]
    if state and state.get("proc"):
        try:
            state["proc"].terminate()
            state["proc"].wait(timeout=3)
        except Exception:
            try:
                state["proc"].kill()
            except Exception:
                pass


def _mcp_initialize(name: str, cfg: dict) -> dict:
    url = str(cfg.get("url") or "").strip()
    if url:
        state = {"proc": None, "url": url, "session": None, "next_id": 0, "inbox": {},
                 "lock": threading.Lock()}
        result = _mcp_request(state, "initialize", {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "clavis-agent", "version": "1"}}, timeout=30)
        _mcp_request(state, "notifications/initialized", notify=True)
    else:
        proc_state = _mcp_spawn(name, cfg)
        state = proc_state
        result = _mcp_request(state, "initialize", {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "clavis-agent", "version": "1"}}, timeout=30)
        _mcp_request(state, "notifications/initialized", notify=True)
    listing = _mcp_request(state, "tools/list", {}, timeout=30)
    tools = []
    for tool in (listing.get("tools") or []):
        if isinstance(tool, dict) and tool.get("name"):
            tools.append({"name": str(tool["name"]),
                          "description": str(tool.get("description") or ""),
                          "inputSchema": tool.get("inputSchema") or {"type": "object"}})
    return {"state": state, "tools": tools}


def _mcp_refresh(name: str, config: dict) -> dict:
    cfg = _mcp_servers_config(config).get(name)
    if not isinstance(cfg, dict) or cfg.get("enabled") is False:
        _mcp_shutdown(name)
        return {"tools": [], "error": ""}
    with _MCP_LOCK:
        previous_proc = (_MCP_STATE.get(name) or {}).get("proc")
    try:
        info = _mcp_initialize(name, cfg)
    except Exception as error:
        print(f"[clavis-agent] mcp {name} refresh failed: {error}", flush=True)
        with _MCP_LOCK:
            previous = _MCP_STATE.get(name) or {}
            _MCP_STATE[name] = {"proc": previous.get("proc"), "url": previous.get("url", ""),
                                "session": previous.get("session"), "next_id": 0,
                                "inbox": previous.get("inbox", {}), "lock": previous.get(
                                    "lock", threading.Lock()),
                                "tools": [], "error": str(error)[:300], "listed": time.time()}
        return _MCP_STATE[name]
    with _MCP_LOCK:
        state = info["state"]
        state.update({"tools": info["tools"], "error": "", "listed": time.time()})
        _MCP_STATE[name] = state
        for full_name in [n for n, v in _MCP_TOOL_MAP.items() if v[0] == name]:
            del _MCP_TOOL_MAP[full_name]
        used = set(_MCP_TOOL_MAP)
        for tool in info["tools"]:
            full = ("mcp__" + _sanitize_mcp_name(name) + "__" + tool["name"])[:64]
            candidate = full
            index = 2
            while candidate in used:
                candidate = (full[:60] + f"_{index}")
                index += 1
            used.add(candidate)
            _MCP_TOOL_MAP[candidate] = (name, tool["name"])
    if previous_proc is not None and previous_proc is not state.get("proc"):
        try:
            previous_proc.terminate()
            previous_proc.wait(timeout=3)
        except Exception:
            try:
                previous_proc.kill()
            except Exception:
                pass
    return state


def _mcp_all_tools(config: dict, wait: float = 6.0) -> list[dict]:
    if _mcp_config(config).get("enabled") is False:
        return []
    names = [name for name, cfg in _mcp_servers_config(config).items()
             if isinstance(cfg, dict) and cfg.get("enabled") is not False]
    todo = []
    with _MCP_LOCK:
        for name in names:
            state = _MCP_STATE.get(name)
            if state is None or time.time() - state.get("listed", 0) > _MCP_TTL \
                    or state.get("error"):
                todo.append(name)
    threads = []
    for name in todo:
        thread = threading.Thread(target=_mcp_refresh, args=(name, config), daemon=True)
        thread.start()
        threads.append(thread)
    deadline = time.time() + wait
    for thread in threads:
        thread.join(max(0.1, deadline - time.time()))
    specs = []
    with _MCP_LOCK:
        for full_name, (server, tool_name) in _MCP_TOOL_MAP.items():
            state = _MCP_STATE.get(server) or {}
            for tool in state.get("tools") or []:
                if tool["name"] == tool_name:
                    specs.append({"type": "function", "function": {
                        "name": full_name,
                        "description": (f"[MCP:{server}] " + tool["description"])[:1200],
                        "parameters": tool.get("inputSchema") or {"type": "object"}}})
                    break
    return specs


def _mcp_call_tool(config: dict, full_name: str, arguments: dict) -> dict:
    with _MCP_LOCK:
        target = _MCP_TOOL_MAP.get(full_name)
    if not target:
        return _tool_error("未知的 MCP 工具，请刷新")
    server, tool_name = target
    state = _MCP_STATE.get(server)
    if state is None or not state.get("tools"):
        state = _mcp_refresh(server, config)
    if not state.get("tools"):
        return _tool_error(f"MCP 服务器 {server} 不可用：{state.get('error') or '未知错误'}")
    try:
        result = _mcp_request(state, "tools/call", {"name": tool_name,
                                                    "arguments": arguments}, timeout=90)
    except Exception as error:
        _mcp_refresh(server, config)
        return _tool_error(f"MCP 调用失败：{error}")
    pieces = []
    for item in (result.get("content") or []):
        if isinstance(item, dict):
            if item.get("type") == "text":
                pieces.append(str(item.get("text") or ""))
            elif item.get("type") == "image":
                pieces.append("[返回了图片内容]")
            else:
                pieces.append("[非文本内容已省略]")
    if result.get("isError"):
        return _tool_error("\n".join(pieces)[:2000] or "MCP 工具执行失败")
    return {"ok": True, "output": "\n".join(pieces)[:100_000] or "(无输出)"}


def _mcp_status(config: dict) -> list[dict]:
    servers = []
    for name, cfg in _mcp_servers_config(config).items():
        if not isinstance(cfg, dict):
            continue
        state = _MCP_STATE.get(name)
        fresh = state is not None and time.time() - state.get("listed", 0) <= _MCP_TTL \
            and not state.get("error")
        if state is None or not fresh:
            state = _mcp_refresh(name, config) or state
        entry = {"name": name, "enabled": cfg.get("enabled") is not False,
                 "command": str(cfg.get("command") or ""),
                 "url": str(cfg.get("url") or "")}
        live = _MCP_STATE.get(name)
        if cfg.get("enabled") is False:
            entry["state"], entry["tools"] = "disabled", []
        else:
            entry["state"] = "ready" if live and not live.get("error") else "error"
            entry["error"] = (live or {}).get("error", "")
            entry["tools"] = [{"name": tool["name"], "description": tool["description"][:120]}
                              for tool in (live or {}).get("tools") or []]
        entry["tool_count"] = len(entry.get("tools") or [])
        servers.append(entry)
    return servers


def _skill_dirs(config: dict) -> list[Path]:
    dirs = [SKILLS_DIR]
    for raw in _skills_config(config).get("extra_dirs") or []:
        path = Path(str(raw)).expanduser()
        if path.is_dir() and path not in dirs:
            dirs.append(path)
    return dirs


def _skills_config(config: dict) -> dict:
    value = config.get("skills")
    return value if isinstance(value, dict) else {}


def _parse_skill_markdown(path: Path) -> tuple[dict, str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return {}, str(error)
    meta = {}
    body = text
    match = re.match(r"\A---\s*\n(.*?)\n---\s*\n?", text, re.S)
    if match:
        for line in match.group(1).splitlines():
            item = line.split(":", 1)
            if len(item) == 2 and item[0].strip() and item[1].strip():
                meta[item[0].strip()] = item[1].strip().strip('"').strip("'")
        body = text[match.end():]
    return meta, body.strip()


def _discover_skills(config: dict) -> list[dict]:
    disabled = set(_skills_config(config).get("disabled") or [])
    skills = []
    seen = set()
    for base in _skill_dirs(config):
        try:
            children = sorted(base.iterdir())
        except OSError:
            continue
        for child in children:
            if not child.is_dir():
                continue
            skill_file = child / "SKILL.md"
            if not skill_file.is_file():
                continue
            meta, _body = _parse_skill_markdown(skill_file)
            name = str(meta.get("name") or child.name)
            if name in seen:
                continue
            seen.add(name)
            skills.append({"name": name, "description": str(meta.get("description") or ""),
                           "dir": str(child), "enabled": name not in disabled,
                           "source": str(base)})
    return skills


def _skill_resources(directory: Path) -> list[str]:
    names = []
    try:
        for path in sorted(directory.rglob("*")):
            if path.is_file() and path.name != "SKILL.md":
                names.append(str(path.relative_to(directory)))
    except OSError:
        pass
    return names[:20]


def _mcp_summary(config: dict) -> list[dict]:
    rows = []
    for name, cfg in _mcp_servers_config(config).items():
        if not isinstance(cfg, dict):
            continue
        state = _MCP_STATE.get(name) or {}
        enabled = cfg.get("enabled") is not False
        if not enabled:
            status = "disabled"
        elif state.get("error"):
            status = "error"
        elif state.get("tools"):
            status = "ready"
        else:
            status = "loading"
        rows.append({"name": name, "enabled": enabled,
                     "command": str(cfg.get("command") or ""),
                     "url": str(cfg.get("url") or ""),
                     "state": status, "tool_count": len(state.get("tools") or [])})
    return rows


def _apply_mcp_set(name: str, cfg) -> tuple[bool, str]:
    """Add, update or remove (cfg=None) an MCP server and persist the config."""
    with LOCK:
        config = load_config()
        servers = _mcp_servers_config(config)
        if cfg is None:
            if name not in servers:
                return False, "没有这个 MCP 服务器：" + name
            servers.pop(name, None)
            config.setdefault("mcp", {})["servers"] = servers
            save_config(config)
            _mcp_shutdown(name)
            return True, ""
        current = servers.get(name) if isinstance(servers.get(name), dict) else {}
        merged = deep_merge(current, cfg if isinstance(cfg, dict) else {})
        merged["enabled"] = merged.get("enabled", True)
        if not str(merged.get("command") or "").strip() \
                and not str(merged.get("url") or "").strip():
            return False, "需要提供 command 或 url"
        servers[name] = merged
        config.setdefault("mcp", {})["servers"] = servers
        save_config(config)
        if merged.get("enabled") is False:
            _mcp_shutdown(name)
        else:
            threading.Thread(target=_mcp_refresh, args=(name, load_config()),
                             daemon=True).start()
    return True, ""


def _skill_create(name: str, description: str, content: str) -> tuple[bool, str]:
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,40}", name):
        return False, "名称只能用小写字母、数字、连字符或下划线（2-41 字符）"
    if not str(content or "").strip():
        return False, "缺少技能内容"
    directory = SKILLS_DIR / name
    if (directory / "SKILL.md").exists():
        return False, "同名技能已存在：" + name
    try:
        directory.mkdir(parents=True, exist_ok=True)
        front = [f"name: {name}"]
        if str(description or "").strip():
            front.append(f"description: {str(description).strip()}")
        (directory / "SKILL.md").write_text(
            "---\n" + "\n".join(front) + "\n---\n\n" + str(content).strip() + "\n",
            encoding="utf-8")
        os.chmod(directory / "SKILL.md", 0o600)
    except OSError as error:
        return False, str(error)
    return True, ""


def _skill_update(name: str, description, content) -> tuple[bool, str]:
    skill_file = SKILLS_DIR / name / "SKILL.md"
    if not skill_file.is_file():
        return False, "默认技能目录里没有这个技能：" + name
    meta, body = _parse_skill_markdown(skill_file)
    new_desc = str(meta.get("description") or "") if description is None else str(description).strip()
    new_body = body if content is None else str(content).strip()
    if not new_body.strip():
        return False, "技能内容不能为空"
    try:
        front = [f"name: {name}"]
        if new_desc:
            front.append(f"description: {new_desc}")
        skill_file.write_text(
            "---\n" + "\n".join(front) + "\n---\n\n" + new_body.strip() + "\n",
            encoding="utf-8")
        os.chmod(skill_file, 0o600)
    except OSError as error:
        return False, str(error)
    return True, ""


def _skill_delete(name: str) -> tuple[bool, str]:
    base = SKILLS_DIR.resolve()
    directory = (SKILLS_DIR / name).resolve()
    if not str(directory).startswith(str(base) + os.sep):
        return False, "只能删除默认技能目录中的技能"
    if not (directory / "SKILL.md").is_file():
        return False, "默认技能目录里没有这个技能：" + name
    try:
        shutil.rmtree(directory)
    except OSError as error:
        return False, str(error)
    with LOCK:
        config = load_config()
        skills_cfg = _skills_config(config)
        skills_cfg["disabled"] = [item for item in (skills_cfg.get("disabled") or [])
                                  if item != name]
        config["skills"] = skills_cfg
        save_config(config)
    return True, ""


def _skill_set_enabled(name: str, enabled: bool) -> tuple[bool, str]:
    if not any(item["name"] == name for item in _discover_skills(load_config())):
        return False, "没有这个技能：" + name
    with LOCK:
        config = load_config()
        skills_cfg = _skills_config(config)
        disabled = [item for item in (skills_cfg.get("disabled") or []) if item != name]
        if not enabled:
            disabled.append(name)
        skills_cfg["disabled"] = disabled
        config["skills"] = skills_cfg
        save_config(config)
    return True, ""


def _manage_mcp(arguments: dict) -> dict:
    action = str(arguments.get("action") or "").strip().lower()
    if action == "list":
        return {"ok": True, "output": {"servers": _mcp_summary(load_config())}}
    if action not in ("add", "update", "remove", "delete", "enable", "disable"):
        return _tool_error("action 必须是 list/add/update/remove/enable/disable")
    name = str(arguments.get("name") or "").strip()
    if not name or len(name) > 64:
        return _tool_error("缺少有效的服务器名称")
    if action in ("remove", "delete"):
        ok, error = _apply_mcp_set(name, None)
    elif action in ("enable", "disable"):
        ok, error = _apply_mcp_set(name, {"enabled": action == "enable"})
    else:
        cfg = {}
        for key in ("command", "url"):
            if key in arguments and str(arguments.get(key) or "").strip():
                cfg[key] = str(arguments.get(key)).strip()
        args = arguments.get("args")
        if isinstance(args, list):
            cfg["args"] = [str(item) for item in args]
        env = arguments.get("env")
        if isinstance(env, dict):
            cfg["env"] = {str(key): str(value) for key, value in env.items()}
        if "enabled" in arguments:
            cfg["enabled"] = bool(arguments.get("enabled"))
        ok, error = _apply_mcp_set(name, cfg)
    if not ok:
        return _tool_error(error)
    return {"ok": True, "output": {"servers": _mcp_summary(load_config())}}


def _manage_skill(arguments: dict) -> dict:
    action = str(arguments.get("action") or "").strip().lower()
    if action == "list":
        return {"ok": True, "output": {"skills": _discover_skills(load_config())}}
    name = str(arguments.get("name") or "").strip()
    if not name:
        return _tool_error("缺少技能名称")
    if action == "create":
        ok, error = _skill_create(name, str(arguments.get("description") or ""),
                                  str(arguments.get("content") or ""))
    elif action == "update":
        ok, error = _skill_update(name, arguments.get("description"),
                                  arguments.get("content"))
    elif action in ("remove", "delete"):
        ok, error = _skill_delete(name)
    elif action in ("enable", "disable"):
        ok, error = _skill_set_enabled(name, action == "enable")
    else:
        return _tool_error("action 必须是 list/create/update/remove/enable/disable")
    if not ok:
        return _tool_error(error)
    return {"ok": True, "output": {"skills": [
        {"name": item["name"], "description": item["description"], "enabled": item["enabled"]}
        for item in _discover_skills(load_config())]}}


def _execute_tool(name: str, arguments: dict, config: dict, session_id: str = "") -> dict:
    name = str(name or "")
    arguments = arguments if isinstance(arguments, dict) else {}

    if name.startswith("mcp__"):
        if _mcp_config(config).get("enabled") is False:
            return _tool_error("MCP 工具未启用")
        return _mcp_call_tool(config, name, _parse_tool_arguments(arguments))

    if name == "load_skill":
        skills = _discover_skills(config)
        wanted = str(arguments.get("name") or "").strip()
        entry = next((item for item in skills if item["name"] == wanted), None)
        if entry is None:
            return _tool_error("没有这个技能：" + wanted)
        if not entry["enabled"]:
            return _tool_error("该技能已被用户停用")
        meta, body = _parse_skill_markdown(Path(entry["dir"]) / "SKILL.md")
        resource = str(arguments.get("resource") or "").strip()
        if resource:
            base = Path(entry["dir"]).resolve()
            target = (base / resource).resolve()
            if not str(target).startswith(str(base) + os.sep):
                return _tool_error("非法的资源路径")
            if not target.is_file():
                return _tool_error("技能目录里没有这个文件：" + resource)
            text = target.read_text(encoding="utf-8", errors="replace")[:200_000]
            return {"ok": True, "output": {"name": wanted, "resource": resource, "text": text}}
        return {"ok": True, "output": {"name": wanted, "dir": entry["dir"],
                                       "resources": _skill_resources(Path(entry["dir"])),
                                       "instructions": body[:50_000]}}

    if name in ("manage_mcp", "manage_skill"):
        if not _computer_config(config).get("allow_config", True):
            return _tool_error("对话修改 MCP/技能配置已在 Agent 设置中关闭")
        return _manage_mcp(arguments) if name == "manage_mcp" else _manage_skill(arguments)

    if name == "read_attachment":
        raw = str(arguments.get("path") or "").strip()
        if not raw:
            return _tool_error("缺少附件路径")
        resolved = str(_attachment_path(raw).resolve())
        allowed = _SESSION_ATTACHMENTS.get(str(session_id or ""), set())
        if resolved not in allowed:
            return _tool_error("该路径不在本次会话的附件列表中")
        try:
            data = Path(resolved).read_bytes()
        except OSError as error:
            return _tool_error(str(error))
        suffix = Path(resolved).suffix.lower()
        if suffix in DOCUMENT_SUFFIXES:
            extracted = _extract_document_text(Path(resolved), 200_000)
            if not extracted or not extracted.strip():
                return _tool_error("该 PDF/Office 文档没有可抽取的文本（可能是扫描件）")
            return {"ok": True, "output": {"path": resolved, "bytes": len(data),
                                           "truncated": len(extracted) >= 200_000,
                                           "text": extracted}}
        truncated = len(data) > 200_000
        if truncated:
            data = data[:200_000]
        if b"\x00" in data[:4096]:
            return _tool_error("该附件是二进制文件，无法作为文本读取")
        return {"ok": True, "output": {"path": resolved, "bytes": len(data),
                                       "truncated": truncated,
                                       "text": data.decode("utf-8", "replace")}}

    cc = _computer_config(config)
    if cc.get("enabled") is False:
        return _tool_error("电脑操作已在 Agent 设置中关闭")

    if name == "list_installed_apps":
        query = str(arguments.get("query") or "").strip()
        try:
            limit = int(arguments.get("limit") or 60)
        except (TypeError, ValueError):
            limit = 60
        apps = search_installed_apps(query, limit)
        return {"ok": True, "output": apps}

    if name == "android_list_apps":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        query = str(arguments.get("query") or "").strip().casefold()
        apps = android_apps()
        if query:
            apps = [app for app in apps if query in app["name"].casefold()
                    or query in app["package"].casefold()]
        return {"ok": True, "output": apps}

    if name == "android_current_activity":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        result = _adb(config, ["shell", "dumpsys", "activity", "activities"])
        if not result.get("ok"):
            return result
        for line in (result.get("output") or "").splitlines():
            if "topResumedActivity" in line or "mResumedActivity" in line:
                return {"ok": True, "output": line.strip()}
        return {"ok": True, "output": "unknown"}

    if name == "android_ui_dump":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        data, result = _android_ui_nodes(config)
        if not data:
            return result
        return {"ok": True, "output": data}

    if name == "android_screenshot":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        return _android_screenshot(config)

    if name == "android_tap":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        try:
            x = int(arguments.get("x"))
            y = int(arguments.get("y"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的 Android 坐标")
        return _adb(config, ["shell", "input", "tap", str(x), str(y)])

    if name == "android_find_and_tap":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        query = str(arguments.get("query") or "").strip()
        if not query:
            return _tool_error("缺少要查找的文本")
        data, result = _android_ui_nodes(config)
        if not data:
            return result
        node = _android_find_node(data.get("nodes", []), query)
        if not node:
            visible = [item.get("text") or item.get("description") for item in data.get("nodes", [])
                       if item.get("text") or item.get("description")]
            return _tool_error("没有找到 Android UI 节点：" + query + "；当前可见文本：" + " | ".join(visible[:20]))
        tap_result = _android_tap_node(config, node)
        tap_result["node"] = node
        return tap_result

    if name == "android_swipe":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        try:
            x1, y1 = int(arguments.get("x1")), int(arguments.get("y1"))
            x2, y2 = int(arguments.get("x2")), int(arguments.get("y2"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的 Android 滑动坐标")
        duration = max(50, min(3000, int(arguments.get("duration_ms") or 300)))
        return _adb(config, ["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])

    if name == "android_keyevent":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        key = str(arguments.get("key") or "").strip().lower().removeprefix("keycode_")
        code = ANDROID_KEYCODES.get(key)
        if code is None:
            if not key.isdigit():
                return _tool_error("未知 Android keyevent：" + key)
            code = int(key)
        return _adb(config, ["shell", "input", "keyevent", str(code)])

    if name == "android_input_text":
        if not cc.get("allow_android", True):
            return _tool_error("Android 操作未启用")
        text = str(arguments.get("text") or "")
        if not text:
            return _tool_error("没有要输入的文本")
        # `input text` is ASCII/keyboard-map based. Keep the encoded form for
        # ADB; non-ASCII is reported clearly instead of silently typing wrong
        # characters.
        if any(ord(char) > 127 for char in text):
            # ADB `input text` is keyboard-map based and drops CJK. If the
            # Droidloom window is focused, try the host Wayland input method
            # as a fallback; otherwise report the limitation explicitly.
            fallback = _run_command(["wtype", "--", text], config)
            if fallback.get("ok"):
                return {"ok": True, "output": "typed through host Wayland input method"}
            return _tool_error("Android input text 仅支持 ASCII；中文请输入到宿主输入法或使用应用内粘贴")
        encoded = text.replace(" ", "%s")
        return _adb(config, ["shell", "input", "text", shlex.quote(encoded)])

    if name == "list_audio_devices":
        if not cc.get("allow_audio", True):
            return _tool_error("音频设备操作未启用")
        return {"ok": True, "output": _audio_devices()}

    if name == "set_default_audio_device":
        if not cc.get("allow_audio", True):
            return _tool_error("音频设备操作未启用")
        sink = str(arguments.get("name") or "").strip()
        available = {item["name"] for item in _audio_devices().get("sinks", [])}
        if sink not in available:
            return _tool_error("未知音频输出设备；请先调用 list_audio_devices")
        return _run_command(["pactl", "set-default-sink", sink], config)

    if name == "set_audio_volume":
        if not cc.get("allow_audio", True):
            return _tool_error("音频设备操作未启用")
        try:
            percent = int(arguments.get("percent"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的音量百分比")
        percent = max(0, min(150, percent))
        return _run_command(["pactl", "set-sink-volume", "@DEFAULT_AUDIO_SINK@", f"{percent}%"], config)

    if name == "list_windows":
        if not cc.get("allow_windows", True):
            return _tool_error("窗口操作未启用")
        result = _niri_json(["windows"], config)
        if not result.get("ok"):
            return result
        try:
            windows = json.loads(result.get("output") or "[]")
            simplified = [{"id": w.get("id"), "title": w.get("title", ""), "app_id": w.get("app_id", ""),
                           "focused": w.get("is_focused", False), "workspace_id": w.get("workspace_id")}
                          for w in windows if isinstance(w, dict)]
            return {"ok": True, "output": simplified}
        except ValueError:
            return {"ok": True, "output": result.get("output", "")}

    if name == "focus_window":
        if not cc.get("allow_windows", True):
            return _tool_error("窗口操作未启用")
        try:
            window_id = int(arguments.get("id"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的窗口 id")
        return _niri_action(["focus-window", "--id", str(window_id)], config)

    if name == "close_window":
        if not cc.get("allow_windows", True):
            return _tool_error("窗口操作未启用")
        try:
            window_id = int(arguments.get("id"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的窗口 id")
        return _niri_action(["close-window", "--id", str(window_id)], config)

    if name == "toggle_fullscreen":
        if not cc.get("allow_windows", True):
            return _tool_error("窗口操作未启用")
        try:
            window_id = int(arguments.get("id"))
        except (TypeError, ValueError):
            return _tool_error("缺少有效的窗口 id")
        return _niri_action(["fullscreen-window", "--id", str(window_id)], config)

    if name == "open_app":
        if not cc.get("allow_launch", True):
            return _tool_error("启动应用未启用")
        target = str(arguments.get("desktop_id") or arguments.get("name") or "").strip()
        if target:
            app = find_installed_app(target)
            if not app:
                suggestions = search_installed_apps(target, 8)
                names = [item["name"] for item in suggestions]
                hint = ("；可能匹配：" + "、".join(names)) if names else ""
                return _tool_error(f"没有找到已安装应用：{target}{hint}")
            return _niri_action(["spawn", "--", "gtk-launch", app["id"]], config)
        command = str(arguments.get("command") or "").strip()
        if not command:
            return _tool_error("请提供 name、desktop_id 或 command")
        if command.endswith(".desktop") or command.startswith("org."):
            argv = ["gtk-launch", command]
        else:
            try:
                argv = shlex.split(command)
            except ValueError as error:
                return _tool_error(str(error))
        if not argv:
            return _tool_error("应用命令为空")
        return _niri_action(["spawn", "--"] + argv, config)

    if name == "open_url":
        if not cc.get("allow_launch", True):
            return _tool_error("启动应用未启用")
        url = str(arguments.get("url") or "").strip()
        if not url.startswith(("http://", "https://")):
            return _tool_error("只允许打开 http(s) URL")
        return _niri_action(["spawn", "--", "xdg-open", url], config)

    if name == "type_text":
        if not cc.get("allow_input", True):
            return _tool_error("键盘输入未启用")
        text = str(arguments.get("text") or "")
        if not text:
            return _tool_error("没有要输入的文本")
        return _run_command(["wtype", "--", text], config)

    if name == "press_key":
        if not cc.get("allow_input", True):
            return _tool_error("键盘输入未启用")
        key = str(arguments.get("key") or "").strip()
        if not re.match(r"^[A-Za-z0-9_+\-]+$", key):
            return _tool_error("无效的按键名称")
        return _run_command(["wtype", "-k", key], config)

    if name == "set_clipboard":
        if not cc.get("allow_clipboard", True):
            return _tool_error("剪贴板操作未启用")
        return _run_command(["wl-copy"], config, input_text=str(arguments.get("text") or ""))

    if name == "get_clipboard":
        if not cc.get("allow_clipboard", True):
            return _tool_error("剪贴板操作未启用")
        return _run_command(["wl-paste", "--no-newline"], config)

    if name == "web_search":
        if not cc.get("allow_web", True):
            return _tool_error("联网搜索未启用")
        query = str(arguments.get("query") or "").strip()
        if not query:
            return _tool_error("缺少搜索关键词")
        try:
            limit = max(1, min(10, int(arguments.get("limit") or 6)))
        except (TypeError, ValueError):
            limit = 6
        results = _web_search(query, limit)
        if not results:
            return _tool_error("搜索没有返回结果（网络可能受限）")
        return {"ok": True, "output": results}

    if name == "read_url":
        if not cc.get("allow_web", True):
            return _tool_error("联网搜索未启用")
        url = str(arguments.get("url") or "").strip()
        if not url.startswith(("http://", "https://")):
            return _tool_error("只允许读取 http(s) URL")
        try:
            final_url, text, size = _read_url(url)
        except Exception as error:
            return _tool_error(f"读取网页失败：{error}")
        if not text.strip():
            return _tool_error("该页面没有可提取的文本")
        return {"ok": True, "output": {"url": final_url, "bytes": size,
                                       "truncated": size > 200_000, "text": text}}

    if name == "create_document":
        if not cc.get("allow_documents", True):
            return _tool_error("文档生成未启用")
        return _create_document(arguments, config)

    if name == "list_local_agents":
        if not cc.get("allow_local_agents", True):
            return _tool_error("本机 Agent 调用已在 Agent 设置中关闭")
        return {"ok": True, "output": {"agents": _local_agents_available()}}

    if name == "run_local_agent":
        if not cc.get("allow_local_agents", True):
            return _tool_error("本机 Agent 调用已在 Agent 设置中关闭")
        agent_id = str(arguments.get("agent") or "").strip()
        task = str(arguments.get("task") or "").strip()
        cwd = str(arguments.get("cwd") or "").strip() or None
        result = _run_local_agent(agent_id, task, cwd)
        if not result.get("ok"):
            return {"ok": False, "error": result.get("error") or "本机 Agent 执行失败",
                    "output": result}
        return {"ok": True, "output": result}

    if name == "run_shell":
        if not cc.get("allow_shell", False):
            return _tool_error("Shell 操作未启用；请在 Agent 设置中明确开启")
        command = str(arguments.get("command") or "").strip()
        if not command:
            return _tool_error("缺少 shell 命令")
        return _run_command(command, config, shell=True)

    return _tool_error(f"未知工具：{name}")


def _parse_tool_arguments(value) -> dict:
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value.strip():
        try:
            parsed = json.loads(value)
            return parsed if isinstance(parsed, dict) else {}
        except ValueError:
            return {}
    return {}


def _provider_request(config: dict, body: dict) -> dict:
    base_url = str(config.get("base_url") or "").strip()
    style = str(config.get("api_style") or "chat").strip().lower()
    api_key = str(config.get("api_key") or "").strip()
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if api_key:
        headers["Authorization"] = "Bearer " + api_key
    req = urllib.request.Request(endpoint(base_url, style), data=json.dumps(body).encode("utf-8"),
                                 headers=headers, method="POST")
    timeout = max(10, min(600, int(config.get("timeout") or 120)))
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read(MAX_BODY * 8)
    except urllib.error.HTTPError as error:
        detail = error.read(4096).decode("utf-8", "replace")
        raise RuntimeError(f"上游 HTTP {error.code}: {detail[:800]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"无法连接上游：{error.reason}") from error
    try:
        return json.loads(raw.decode("utf-8", "replace"))
    except ValueError as error:
        raise RuntimeError("上游返回的不是 JSON") from error


def _response_tool_calls(payload: dict) -> list[dict]:
    calls = []
    for item in payload.get("output", []) or []:
        if isinstance(item, dict) and item.get("type") == "function_call":
            calls.append({"name": item.get("name", ""), "arguments": _parse_tool_arguments(item.get("arguments")),
                          "call_id": item.get("call_id", item.get("id", ""))})
    return calls


def _tool_summary(trace: list[dict]) -> list[dict]:
    return [{"name": item.get("name", ""), "ok": bool(item.get("result", {}).get("ok")),
             "arguments": item.get("arguments", {})} for item in trace]


MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024
MAX_TOTAL_ATTACHMENT_BYTES = 40 * 1024 * 1024
INLINE_TEXT_LIMIT = 200 * 1024
MAX_ATTACHMENTS = 8
IMAGE_SUFFIXES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                  ".webp": "image/webp", ".gif": "image/gif"}
TEXT_SUFFIXES = {".txt", ".md", ".markdown", ".json", ".jsonl", ".yaml", ".yml", ".toml",
                 ".ini", ".cfg", ".conf", ".csv", ".tsv", ".log", ".xml", ".html", ".htm",
                 ".css", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".py", ".pyi", ".sh",
                 ".bash", ".zsh", ".fish", ".c", ".h", ".cc", ".cpp", ".hpp", ".cxx", ".java",
                 ".kt", ".kts", ".swift", ".rs", ".go", ".rb", ".php", ".pl", ".lua", ".sql",
                 ".r", ".dart", ".vue", ".svelte", ".qml", ".cmake", ".gradle", ".qrc", ".ui",
                 ".diff", ".patch", ".properties", ".service", ".desktop", ".gitignore"}
TEXT_MIMES = {"application/json", "application/xml", "application/javascript",
              "application/x-yaml", "application/toml", "application/x-sh", "application/sql"}
_SESSION_ATTACHMENTS: dict[str, set] = {}


PYPDF_VENDOR_DIR = Path(os.environ.get(
    "CLAVIS_AGENT_PYPDF", str(Path.home() / ".local/share/clavis-agent/vendor/pypdf")))
REPORTLAB_VENDOR_DIR = Path(os.environ.get(
    "CLAVIS_AGENT_REPORTLAB", str(Path.home() / ".local/share/clavis-agent/vendor/reportlab")))
DOCUMENT_SUFFIXES = {".pdf", ".docx", ".pptx", ".xlsx"}
PANDOC_BIN = Path.home() / ".local/clavis-voice/pandoc/usr/bin/pandoc"
PANDOC_LIB_DIRS = ["/home/xiaomi/.local/clavis-voice/pandoc/usr/lib/aarch64-linux-gnu",
                   "/home/xiaomi/.local/clavis-voice/pandoc/lib/aarch64-linux-gnu"]
PDF_FONT_CANDIDATES = [
    ("/usr/share/fonts/truetype/winfonts/NotoSansSC-VF.ttf", "NotoSC"),
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", "NotoCJK"),
]


def _xml_text_nodes(data: bytes, limit: int) -> str:
    text = data.decode("utf-8", "replace")
    chunks = re.split(r"</w:p>|</a:p>|<w:br[^>]*/>", text)
    lines = []
    total = 0
    for chunk in chunks:
        pieces = re.findall(r"<(?:w:t|a:t)[^>]*>([^<]*)</(?:w:t|a:t)>", chunk)
        if not pieces:
            continue
        line = html.unescape("".join(pieces)).strip()
        if line:
            lines.append(line)
            total += len(line)
            if total >= limit:
                break
    if lines:
        return "\n".join(lines)[:limit]
    stripped = html.unescape(re.sub(r"<[^>]+>", " ", text))
    return re.sub(r"[ \t\x0c]+", " ", stripped)[:limit]


def _extract_pdf(path: Path, limit: int) -> str | None:
    if str(PYPDF_VENDOR_DIR) not in sys.path:
        sys.path.insert(0, str(PYPDF_VENDOR_DIR))
    try:
        import pypdf
        reader = pypdf.PdfReader(str(path))
        pages = []
        for index, page in enumerate(reader.pages):
            text = (page.extract_text() or "").strip()
            if text:
                pages.append(text)
            if sum(len(item) for item in pages) >= limit:
                break
        return "\n\n".join(pages)[:limit] if pages else None
    except Exception:
        return None


def _extract_document_text(path: Path, limit: int) -> str | None:
    suffix = path.suffix.lower()
    try:
        if suffix == ".pdf":
            return _extract_pdf(path, limit)
        with zipfile.ZipFile(path) as archive:
            if suffix == ".docx":
                return _xml_text_nodes(archive.read("word/document.xml"), limit) or None
            if suffix == ".pptx":
                slides = sorted(name for name in archive.namelist()
                                if re.fullmatch(r"ppt/slides/slide\d+\.xml", name))
                parts = []
                for index, slide in enumerate(slides, 1):
                    text = _xml_text_nodes(archive.read(slide), limit // max(1, len(slides)))
                    if text.strip():
                        parts.append(f"[Slide {index}] {text.strip()}")
                return "\n".join(parts)[:limit] if parts else None
            if suffix == ".xlsx":
                return _xml_text_nodes(archive.read("xl/sharedStrings.xml"), limit) or None
    except Exception:
        return None
    return None


def _attachment_path(raw: str) -> Path:
    value = str(raw or "").strip()
    if value.startswith("file://"):
        value = urllib.parse.unquote(value[len("file://"):])
    return Path(value).expanduser()


def _prepare_attachments(raw_attachments) -> list[dict]:
    if not raw_attachments:
        return []
    if not isinstance(raw_attachments, list):
        raise ValueError("附件格式无效")
    prepared = []
    total = 0
    seen = set()
    for item in raw_attachments[:MAX_ATTACHMENTS]:
        if not isinstance(item, dict):
            continue
        path = _attachment_path(item.get("path") or item.get("url") or "")
        if not str(path):
            continue
        if not path.is_file():
            raise ValueError(f"附件不存在：{path.name}")
        size = path.stat().st_size
        if size > MAX_ATTACHMENT_BYTES:
            raise ValueError(f"附件过大（上限 20MB）：{path.name}")
        total += size
        if total > MAX_TOTAL_ATTACHMENT_BYTES:
            raise ValueError("附件总大小超过 40MB")
        resolved = str(path.resolve())
        if resolved in seen:
            continue
        seen.add(resolved)
        suffix = path.suffix.lower()
        mime = mimetypes.guess_type(path.name)[0] or ""
        entry = {"path": resolved, "name": str(item.get("name") or path.name),
                 "size": size, "mime": mime}
        if suffix in IMAGE_SUFFIXES:
            entry["kind"] = "image"
            entry["mime"] = IMAGE_SUFFIXES[suffix]
            entry["data_uri"] = ("data:" + IMAGE_SUFFIXES[suffix] + ";base64,"
                                 + base64.b64encode(path.read_bytes()).decode("ascii"))
        elif suffix in DOCUMENT_SUFFIXES:
            extracted = _extract_document_text(path, INLINE_TEXT_LIMIT)
            if extracted and extracted.strip():
                entry["kind"] = "document"
                entry["text"] = extracted
            else:
                entry["kind"] = "file"
        elif (suffix in TEXT_SUFFIXES or mime.startswith("text/") or mime in TEXT_MIMES) \
                and size <= INLINE_TEXT_LIMIT:
            raw = path.read_bytes()
            text = ""
            if b"\x00" not in raw[:8192]:
                try:
                    text = raw.decode("utf-8")
                except UnicodeDecodeError:
                    try:
                        text = raw.decode("gb18030")
                    except UnicodeDecodeError:
                        text = ""
            if text:
                entry["kind"] = "text"
                entry["text"] = text
            else:
                entry["kind"] = "file"
        else:
            entry["kind"] = "file"
        prepared.append(entry)
    return prepared


def _register_attachments(session_id: str, prepared: list[dict]) -> None:
    if not session_id or not prepared:
        return
    paths = _SESSION_ATTACHMENTS.setdefault(str(session_id), set())
    for item in prepared:
        paths.add(item["path"])
    if len(paths) > 64:
        _SESSION_ATTACHMENTS[str(session_id)] = set(sorted(paths)[-64:])


def _attachment_history_text(message: str, prepared: list[dict]) -> str:
    parts = [message]
    for item in prepared:
        if item["kind"] == "image":
            parts.append(f"[图片附件：{item['name']}]")
        elif item["kind"] == "text":
            parts.append(f"[文件附件：{item['name']}]")
        else:
            parts.append(f"[文件附件：{item['name']} → {item['path']}]")
    return "\n".join(parts)


def _user_content(message: str, prepared: list[dict], style: str):
    text = message
    for item in prepared:
        if item["kind"] == "text":
            text += f"\n\n[附件文件：{item['name']}]\n```\n{item['text']}\n```"
        elif item["kind"] == "document":
            text += f"\n\n[附件文档：{item['name']}（已在本机抽取文本）]\n```\n{item['text']}\n```"
    for item in prepared:
        if item["kind"] == "file":
            text += (f"\n\n[附件文件：{item['name']}（{item['mime'] or 'binary'}，"
                     f"{item['size']} 字节）位于 {item['path']}；可用 read_attachment 工具读取内容]")
    images = [item for item in prepared if item["kind"] == "image"]
    if not images:
        return text
    if style == "responses":
        content = [{"type": "input_text", "text": text}]
        for item in images:
            content.append({"type": "input_image", "image_url": item["data_uri"]})
        return content
    content = [{"type": "text", "text": text}]
    for item in images:
        content.append({"type": "image_url", "image_url": {"url": item["data_uri"]}})
    return content


def _content_has_images(content) -> bool:
    if not isinstance(content, list):
        return False
    return any(isinstance(part, dict) and part.get("type") in ("image_url", "input_image")
               for part in content)


def _strip_images(messages: list[dict], note: str) -> list[dict]:
    result = []
    for message in messages:
        content = message.get("content")
        if not _content_has_images(content):
            result.append(message)
            continue
        text = " ".join(str(part.get("text") or "") for part in content
                        if isinstance(part, dict) and part.get("type") in ("text", "input_text"))
        if message.get("role") == "user":
            text = (text + "\n\n" + note).strip()
        rebuilt = dict(message)
        rebuilt["content"] = text
        result.append(rebuilt)
    return result


def request_chat(config: dict, message: str, session_id: str,
                 attachments=None) -> tuple[str, str, dict, list[dict]]:
    base_url = str(config.get("base_url") or "").strip()
    style = str(config.get("api_style") or "chat").strip().lower()
    model = str(config.get("model") or "").strip()
    if not model:
        raise ValueError("请先在设置中填写模型名称")
    api_key = str(config.get("api_key") or "").strip()
    local_upstream = any(token in base_url for token in ("127.0.0.1", "localhost", "[::1]"))
    if not api_key and not local_upstream:
        raise ValueError("请先在设置中填写 API Key")
    prepared = _prepare_attachments(attachments)
    _register_attachments(session_id, prepared)
    history = load_history(session_id)
    messages = []
    system_prompt = str(config.get("system_prompt") or "").strip()
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.extend(history)
    messages.append({"role": "user", "content": _user_content(message, prepared, style)})

    tools = _tool_specs(config, session_id)
    cc = _computer_config(config)
    if tools:
        tool_notice = ("你可以使用提供的工具直接操作电脑。需要窗口信息时先调用 list_windows；"
                       "用户提到某个应用时先调用 list_installed_apps，不要因为窗口列表里没有就断言应用未安装。"
                       "不要声称已经执行未执行的操作。执行有副作用的操作前，确认目标窗口或应用。")
        if messages and messages[0].get("role") == "system":
            messages[0]["content"] = str(messages[0].get("content") or "") + "\n\n" + tool_notice
        else:
            messages.insert(0, {"role": "system", "content": tool_notice})

    environment = environment_context(config)
    if environment:
        if messages and messages[0].get("role") == "system":
            messages[0]["content"] = str(messages[0].get("content") or "") + "\n\n" + environment
        else:
            messages.insert(0, {"role": "system", "content": environment})

    trace: list[dict] = []
    artifacts: list[dict] = []
    seen_artifacts: set = set()
    reply = ""
    usage = {}
    payload: dict = {}
    recent_calls: list[str] = []

    def _note_tool_call(call_name: str, call_arguments) -> None:
        """Abort only when the same tool+args repeat consecutively (stuck loop)."""
        try:
            signature = call_name + "|" + json.dumps(call_arguments, ensure_ascii=False,
                                                     sort_keys=True)
        except (TypeError, ValueError):
            signature = call_name + "|?"
        recent_calls.append(signature)
        if len(recent_calls) > 6:
            del recent_calls[:-6]
        if len(recent_calls) == 6 and len(set(recent_calls)) == 1:
            raise RuntimeError("检测到工具调用陷入重复循环，已中止本轮")

    if style == "responses":
        response_tools = []
        for tool in tools:
            response_tools.append({"type": "function", "name": tool["function"]["name"],
                                   "description": tool["function"]["description"],
                                   "parameters": tool["function"]["parameters"]})
        previous_id = ""
        pending_input = None
        while True:
            body = {
                "model": model,
                "max_output_tokens": int(config.get("max_tokens") or 2048),
                "temperature": float(config.get("temperature") or 0.3),
                "store": False,
            }
            if previous_id:
                body["previous_response_id"] = previous_id
                body["input"] = pending_input or []
            else:
                body["input"] = messages
            if response_tools:
                body["tools"] = response_tools
            try:
                payload = _provider_request(config, body)
            except urllib.error.HTTPError as error:
                if _content_has_images(body.get("input")) and 400 <= error.code < 500 \
                        and error.code not in (401, 403, 429):
                    messages = _strip_images(messages, "(图片附件已忽略：当前模型不支持图片输入)")
                    body["input"] = messages
                    payload = _provider_request(config, body)
                else:
                    raise
            usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else usage
            calls = _response_tool_calls(payload)
            if not calls:
                reply = extract_responses_text(payload)
                break
            response_id = str(payload.get("id") or "")
            if not response_id:
                raise RuntimeError("上游没有返回 response id，无法继续工具调用")
            outputs = []
            for call in calls:
                _note_tool_call(call.get("name", ""), call.get("arguments", {}))
                result = _execute_tool(call.get("name", ""), call.get("arguments", {}),
                                       config, session_id)
                trace.append({"name": call.get("name", ""), "arguments": call.get("arguments", {}),
                              "result": result})
                artifacts.extend(_collect_artifacts(result, seen_artifacts))
                outputs.append({"type": "function_call_output", "call_id": call.get("call_id", ""),
                                "output": json.dumps(result, ensure_ascii=False)})
            previous_id = response_id
            pending_input = outputs
    else:
        while True:
            body = {
                "model": model,
                "messages": messages,
                "temperature": float(config.get("temperature") or 0.3),
                "max_tokens": int(config.get("max_tokens") or 2048),
            }
            if tools:
                body["tools"] = tools
            try:
                payload = _provider_request(config, body)
            except urllib.error.HTTPError as error:
                if _content_has_images(messages) and 400 <= error.code < 500 \
                        and error.code not in (401, 403, 429):
                    messages = _strip_images(messages, "(图片附件已忽略：当前模型不支持图片输入)")
                    continue
                raise
            usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else usage
            choices = payload.get("choices") or []
            if not choices or not isinstance(choices[0], dict):
                raise RuntimeError("上游没有返回对话内容")
            choice_message = choices[0].get("message") or {}
            calls = choice_message.get("tool_calls") or []
            if not calls:
                content = choice_message.get("content", "")
                if isinstance(content, list):
                    reply = "".join(part.get("text", "") for part in content if isinstance(part, dict))
                else:
                    reply = str(content or "")
                break
            messages.append({
                "role": "assistant",
                "content": choice_message.get("content"),
                "tool_calls": calls,
            })
            for call in calls:
                function = call.get("function") or {}
                arguments = _parse_tool_arguments(function.get("arguments"))
                _note_tool_call(function.get("name", ""), arguments)
                result = _execute_tool(function.get("name", ""), arguments, config, session_id)
                trace.append({"name": function.get("name", ""), "arguments": arguments, "result": result})
                artifacts.extend(_collect_artifacts(result, seen_artifacts))
                messages.append({
                    "role": "tool",
                    "tool_call_id": call.get("id", ""),
                    "content": json.dumps(result, ensure_ascii=False),
                })

    if not str(reply or "").strip():
        raise RuntimeError("上游没有返回最终文本")
    history.extend([{"role": "user", "content": _attachment_history_text(message, prepared)},
                    {"role": "assistant", "content": reply}])
    save_history(session_id, history)
    return (reply.strip(), session_id, usage, _tool_summary(trace), artifacts,
            _reply_files(reply, artifacts))

class Handler(BaseHTTPRequestHandler):
    server_version = "ClavisAgent/1"

    def log_message(self, fmt, *args):
        sys.stderr.write("[clavis-agent] " + (fmt % args) + "\n")

    def _headers(self, status=200, content_type="application/json; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def _json(self, status, value):
        self._headers(status)
        self.wfile.write(json.dumps(value, ensure_ascii=False).encode("utf-8"))

    def _body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY:
            return {}
        try:
            value = json.loads(self.rfile.read(length).decode("utf-8"))
            return value if isinstance(value, dict) else {}
        except (ValueError, UnicodeDecodeError):
            return {}

    def do_OPTIONS(self):
        self._headers(204)
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            config = load_config()
            computer = _computer_config(config)
            self._json(200, {"ok": True, "app": APP, "version": VERSION,
                             "configured": bool(str(config.get("api_key") or "").strip()
                                                or str(config.get("base_url") or "").startswith("http://127.")),
                             "model": config.get("model", ""), "provider": config.get("provider", ""),
                             "computer_control": computer.get("enabled") is not False,
                             "voice": _voice_capabilities()})
            return
        if self.path == "/v1/config":
            self._json(200, load_config())
            return
        if self.path == "/v1/mcp":
            self._json(200, {"ok": True, "servers": _mcp_status(load_config())})
            return
        if self.path == "/v1/skills":
            config = load_config()
            self._json(200, {"ok": True, "dir": str(SKILLS_DIR),
                             "skills": _discover_skills(config)})
            return
        if self.path == "/v1/voice/state":
            self._json(200, {"ok": True, "state": dict(_VOICE_STATE),
                             "capabilities": _voice_capabilities()})
            return
        if self.path == "/v1/local-agents":
            self._json(200, {"ok": True, "agents": _local_agents_available()})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/v1/config":
            patch = self._body()
            with LOCK:
                config = deep_merge(load_config(), patch)
                save_config(config)
            self._json(200, config)
            return
        if self.path == "/v1/voice/listen":
            self._json(200, _voice_listen(load_config()))
            return
        if self.path == "/v1/voice/stop":
            _VOICE_STATE["stop"] = True
            self._json(200, {"ok": True})
            return
        if self.path == "/v1/voice/tts":
            body = self._body()
            self._json(200, _tts_speak(load_config(), str(body.get("text") or "")))
            return
        if self.path == "/v1/mcp/set":
            body = self._body()
            name = str(body.get("name") or "").strip()
            if not name or len(name) > 64:
                self._json(400, {"error": "无效的名称"})
                return
            ok, error = _apply_mcp_set(name, body.get("cfg"))
            if not ok:
                self._json(400, {"error": error})
                return
            self._json(200, {"ok": True, "servers": _mcp_status(load_config())})
            return
        if self.path == "/v1/skills/create":
            body = self._body()
            ok, error = _skill_create(str(body.get("name") or "").strip(),
                                      str(body.get("description") or ""),
                                      str(body.get("content") or ""))
            if not ok:
                self._json(400, {"error": error})
                return
            self._json(200, {"ok": True, "skills": _discover_skills(load_config())})
            return
        if self.path == "/v1/skills/set":
            body = self._body()
            ok, error = _skill_set_enabled(str(body.get("name") or "").strip(),
                                           bool(body.get("enabled")))
            if not ok:
                self._json(400, {"error": error})
                return
            self._json(200, {"ok": True, "skills": _discover_skills(load_config())})
            return
        if self.path == "/v1/open":
            body = self._body()
            raw = str(body.get("path") or "").strip()
            path = Path(raw).expanduser() if raw else None
            try:
                exists = bool(path) and path.is_file()
            except OSError:
                exists = False
            if not exists:
                self._json(400, {"error": "文件不存在"})
                return
            resolved = str(path.resolve())
            self._json(200, _spawn_open(load_config(), resolved))
            return
        if self.path == "/v1/local-agents/run":
            if not _computer_config(load_config()).get("allow_local_agents", True):
                self._json(403, {"ok": False, "error": "本机 Agent 调用已在 Agent 设置中关闭"})
                return
            body = self._body()
            result = _run_local_agent(str(body.get("agent") or "").strip(),
                                       str(body.get("task") or "").strip(),
                                       str(body.get("cwd") or "").strip() or None)
            self._json(200 if result.get("ok") else 400, result)
            return
        if self.path == "/v1/chat":
            body = self._body()
            message = str(body.get("message") or "").strip()
            if not message:
                self._json(400, {"error": "消息不能为空"})
                return
            session_id = str(body.get("session_id") or "").strip() or uuid.uuid4().hex
            try:
                reply, session_id, usage, trace, artifacts, files = request_chat(
                    load_config(), message, session_id, body.get("attachments"))
                self._json(200, {"reply": reply, "session_id": session_id, "usage": usage,
                                 "trace": trace, "artifacts": artifacts, "files": files})
            except Exception as error:
                self._json(502, {"error": str(error), "session_id": session_id})
            return
        self._json(404, {"error": "not found"})


def main():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    config = load_config()
    if not CONFIG_PATH.exists():
        save_config(config)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[clavis-agent] listening on http://{HOST}:{PORT}; config={CONFIG_PATH}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
