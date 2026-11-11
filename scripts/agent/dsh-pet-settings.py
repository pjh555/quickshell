#!/usr/bin/env python3
"""Import DSH/dsh-pet pet settings without importing its code.

Reads the user's dsh-pet JSONC config and emits a normalized settings map for
Clavis' PetSettingsService. This is a schema adapter: size, display, position,
work-status reactions and animation slots are translated; unknown fields are
preserved under `dsh` for future extension.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

HOME = Path.home()
DSH_PET = Path(os.environ.get("DSH_PET_HOME", HOME / ".dsh/dsh-pet"))

STATES = ["thinking", "working", "result", "waiting", "success", "error"]


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments while preserving strings."""
    out = []
    i = 0
    in_string = False
    escaped = False
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and nxt == "/":
            i += 2
            while i < len(text) and text[i] not in "\r\n":
                i += 1
            continue
        if ch == "/" and nxt == "*":
            i += 2
            while i + 1 < len(text) and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def load_jsonc(path: Path):
    try:
        return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    except Exception as exc:  # noqa: BLE001
        print(f"skip {path}: {exc}", file=sys.stderr)
        return None


def canonical_anim(name: str) -> str:
    value = str(name or "")
    if value in STATES:
        return value
    if "思考" in value:
        return "thinking"
    if "清点" in value or "归档" in value:
        return "result"
    if "踱步" in value or "张望" in value:
        return "waiting"
    if "庆祝" in value or "雀跃" in value:
        return "success"
    if "垂头" in value or "叹气" in value or "冒汗" in value:
        return "error"
    if "忙碌" in value or "工作" in value:
        return "working"
    return value


def first_slot(slot):
    if isinstance(slot, str):
        return slot
    if isinstance(slot, list):
        for item in slot:
            if isinstance(item, str) and item:
                return item
    return ""


def pet_settings(pet: dict, global_cfg: dict, prefix: str = "") -> dict | None:
    if not isinstance(pet, dict):
        return None
    pid = str(pet.get("id") or prefix or pet.get("name") or "").strip()
    if not pid:
        return None
    dsh_size = pet.get("size")
    try:
        dsh_size = float(dsh_size)
    except (TypeError, ValueError):
        dsh_size = 462.0
    our_size = int(round(dsh_size if 64 <= dsh_size <= 240 else dsh_size * 112.0 / 462.0))
    our_size = max(64, min(240, our_size))

    display_raw = str(pet.get("display") or "desktop")
    display = "desktop" if display_raw in ("desktop", "both") else "none"

    pos = pet.get("position") if isinstance(pet.get("position"), dict) else {}
    position = {
        "corner": str(pos.get("corner") or "bottom-right"),
        "marginX": max(0, min(400, int(pos.get("marginX") or 36))),
        "marginY": max(0, min(400, int(pos.get("marginY") or 92))),
    }

    animations = pet.get("animations") if isinstance(pet.get("animations"), dict) else {}
    if not animations and isinstance(global_cfg.get("animations"), dict):
        animations = global_cfg.get("animations")
    events = animations.get("events") if isinstance(animations.get("events"), dict) else {}
    slots = events.get("workStatus") if isinstance(events.get("workStatus"), list) else []
    agent_states = {}
    for i, state in enumerate(STATES):
        if i < len(slots):
            name = first_slot(slots[i])
            if name:
                agent_states[state] = canonical_anim(name)

    texts = pet.get("workStatusTexts")
    if not isinstance(texts, list):
        texts = global_cfg.get("workStatusTexts")
    if not isinstance(texts, list):
        texts = None

    settings = {
        "name": str(pet.get("name") or pid),
        "size": our_size,
        "display": display,
        "position": position,
        "fixed": (pet.get("fixedEnabled") if "fixedEnabled" in pet else global_cfg.get("fixedEnabled")) is True,
        "workStatusEnabled": (pet.get("workStatusEnabled") if "workStatusEnabled" in pet else global_cfg.get("workStatusEnabled")) is not False,
        "sounds": global_cfg.get("clickSoundEnabled") is True,
        "dsh": {
            "id": pid,
            "size": dsh_size,
            "display": display_raw,
            "position": pos,
            "fixedEnabled": pet.get("fixedEnabled"),
            "workStatusEnabled": pet.get("workStatusEnabled"),
            "balanceEnabled": pet.get("balanceEnabled"),
            "whisperEnabled": pet.get("whisperEnabled"),
            "animations": animations,
            "animationWeights": pet.get("animationWeights") or global_cfg.get("animationWeights"),
            "workStatusSlots": slots,
            "physics": pet.get("physics") or global_cfg.get("physics"),
            "font": pet.get("font") or global_cfg.get("font"),
        },
    }
    if agent_states:
        settings["agentStates"] = agent_states
    if texts:
        settings["workStatusTexts"] = texts
    return settings


def main() -> int:
    arg_file = None
    if "--file" in sys.argv:
        idx = sys.argv.index("--file")
        if idx + 1 < len(sys.argv):
            arg_file = Path(sys.argv[idx + 1]).expanduser()

    files = []
    if arg_file:
        files = [arg_file]
    else:
        for name in ("main-config.jsonc", "main-config.json"):
            p = DSH_PET / name
            if p.is_file():
                files.append(p)
        files += sorted((DSH_PET / "pet").glob("*-config.jsonc"))
        files += sorted((DSH_PET / "pet").glob("*-config.json"))
        # A few tolerant fallbacks for older/alternate DSH homes.
        for root in (HOME / ".dsh", HOME / ".config/dsh", HOME / ".config/deepseek-harness"):
            if root != DSH_PET:
                for p in root.glob("**/dsh-pet/main-config.jsonc"):
                    files.append(p)
                for p in root.glob("**/dsh-pet/pet/*-config.jsonc"):
                    files.append(p)

    if not files:
        print(json.dumps({"ok": False, "pets": {}, "error": "未找到 ~/.dsh/dsh-pet 配置"}, ensure_ascii=False))
        return 0

    merged = {}
    sources = []
    for path in files:
        data = load_jsonc(path)
        if not isinstance(data, dict):
            continue
        sources.append(str(path))
        prefix = ""
        if path.parent.name == "pet" and path.name.endswith(("-config.json", "-config.jsonc")):
            prefix = path.name.split("-config.")[0]
        pets = data.get("pets")
        if isinstance(pets, list):
            for pet in pets:
                settings = pet_settings(pet, data, prefix)
                if settings:
                    pid = str(pet.get("id") or prefix or settings["name"])
                    merged[pid] = settings
        elif isinstance(pets, dict):
            for pid, pet in pets.items():
                if isinstance(pet, dict):
                    copy = dict(pet)
                    copy.setdefault("id", pid)
                    settings = pet_settings(copy, data, prefix)
                    if settings:
                        merged[str(pid)] = settings
        elif prefix:
            settings = pet_settings(data, data, prefix)
            if settings:
                merged[prefix] = settings

    print(json.dumps({
        "ok": True,
        "source": ", ".join(sources),
        "count": len(merged),
        "pets": merged,
    }, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(json.dumps({"ok": False, "pets": {}, "error": str(exc)}, ensure_ascii=False))
        raise SystemExit(1)
