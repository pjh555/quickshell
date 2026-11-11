#!/usr/bin/env python3
"""Run locally installed coding agents for Clavis.

Only configured agent CLIs are executed, as argv arrays (no shell). This is the
data/execution layer behind the `run_local_agent` Agent tool and the
/v1/local-agents HTTP endpoints.
"""
from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CONFIG_PATH = Path(os.environ.get("CLAVIS_LOCAL_AGENTS_CONFIG", HOME / ".config/clavis/local-agents.json"))

EXTRA_PATH = [
    HOME / ".local/bin",
    HOME / ".npm-global/bin",
    HOME / ".opencode/bin",
    HOME / ".bun/bin",
    HOME / ".cargo/bin",
    Path("/usr/local/bin"),
    Path("/usr/bin"),
]

DEFAULT_AGENTS = {
    "codex": {
        "name": "Codex",
        "command": ["codex", "-a", "never", "-s", "workspace-write", "exec",
                    "--skip-git-repo-check", "--color", "never", "{prompt}"],
        "timeout": 900,
    },
    "claude": {
        "name": "Claude Code",
        "command": ["claude", "-p", "{prompt}"],
        "timeout": 900,
    },
    "opencode": {
        "name": "OpenCode",
        "command": ["opencode", "run", "--standalone", "--auto", "{prompt}"],
        "timeout": 900,
    },
}

DISPLAY_ORDER = ["codex", "claude", "opencode", "dsh", "workbuddy", "hermes"]


def _search_path() -> str:
    parts = [str(p) for p in EXTRA_PATH]
    env_path = os.environ.get("PATH", "")
    if env_path:
        parts.append(env_path)
    return os.pathsep.join(parts)


def _load_user_config() -> dict:
    try:
        data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def load_agents() -> dict:
    user = _load_user_config().get("agents")
    agents = {k: dict(v) for k, v in DEFAULT_AGENTS.items()}
    if isinstance(user, dict):
        for key, value in user.items():
            if not isinstance(value, dict):
                continue
            base = dict(agents.get(key, {}))
            base.update(value)
            if isinstance(base.get("command"), str):
                base["command"] = shlex.split(base["command"])
            agents[str(key)] = base
    return agents


def _resolve(command: list[str]) -> str | None:
    if not command:
        return None
    exe = str(command[0])
    if os.path.isabs(exe):
        return exe if os.path.isfile(exe) and os.access(exe, os.X_OK) else None
    return shutil.which(exe, path=_search_path())


def available_agents() -> list[dict]:
    agents = load_agents()
    out = []
    seen = set()
    order = DISPLAY_ORDER + sorted(k for k in agents if k not in DISPLAY_ORDER)
    for key in order:
        if key not in agents or key in seen:
            continue
        seen.add(key)
        spec = agents[key]
        command = spec.get("command") or []
        path = _resolve(command)
        out.append({
            "id": key,
            "name": str(spec.get("name") or key),
            "available": bool(path),
            "path": path or "",
            "timeout": int(spec.get("timeout") or 900),
        })
    return out


def summary() -> str:
    parts = []
    for item in available_agents():
        if item["available"]:
            parts.append(item["id"] + "(" + item["name"] + ", ready)")
        else:
            parts.append(item["id"] + "(" + item["name"] + ", not installed)")
    return ", ".join(parts) if parts else "no local agents configured"


def _command_for(spec: dict, task: str, cwd: str) -> list[str]:
    raw = spec.get("command") or []
    if isinstance(raw, str):
        raw = shlex.split(raw)
    command = []
    replaced = False
    for arg in raw:
        arg = str(arg)
        if "{prompt}" in arg:
            replaced = True
            command.append(arg.replace("{prompt}", task))
        elif "{cwd}" in arg:
            command.append(arg.replace("{cwd}", cwd))
        else:
            command.append(arg)
    if not replaced:
        command.append(task)
    return command


def run_local_agent(agent_id: str, task: str, cwd: str | None = None) -> dict:
    agent_id = str(agent_id or "").strip()
    task = str(task or "").strip()
    if not agent_id:
        return {"ok": False, "error": "缺少 agent id"}
    if not task:
        return {"ok": False, "error": "缺少任务描述"}
    agents = load_agents()
    spec = agents.get(agent_id)
    if not spec:
        return {"ok": False, "error": "没有配置这个本机 Agent：" + agent_id,
                "available": available_agents()}
    workdir = str(cwd or spec.get("cwd") or HOME)
    workdir = os.path.expanduser(workdir)
    if not os.path.isdir(workdir):
        return {"ok": False, "error": "工作目录不存在：" + workdir}
    command = _command_for(spec, task, workdir)
    exe = _resolve(command)
    if not exe:
        return {"ok": False, "error": "本机 Agent CLI 未安装：" + str(command[0] if command else agent_id)}
    command[0] = exe
    timeout = max(10, min(1800, int(spec.get("timeout") or 900)))
    env = os.environ.copy()
    for key, value in (spec.get("env") or {}).items():
        env[str(key)] = str(value)
    started = time.monotonic()
    try:
        proc = subprocess.run(
            command,
            cwd=workdir,
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        duration = round(time.monotonic() - started, 2)
        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        output = (stdout + ("\n" + stderr if stderr else "")).strip()
        truncated = len(output) > 60000
        if truncated:
            output = output[-60000:]
        return {
            "ok": proc.returncode == 0,
            "agent": agent_id,
            "name": str(spec.get("name") or agent_id),
            "cwd": workdir,
            "exitCode": proc.returncode,
            "duration": duration,
            "truncated": truncated,
            "output": output,
        }
    except subprocess.TimeoutExpired as exc:
        duration = round(time.monotonic() - started, 2)
        out = exc.stdout or ""
        if isinstance(out, bytes):
            out = out.decode("utf-8", "replace")
        return {"ok": False, "agent": agent_id, "cwd": workdir, "timeout": True,
                "duration": duration, "error": f"执行超时（{timeout}s）", "output": out[-20000:]}
    except Exception as exc:
        return {"ok": False, "agent": agent_id, "cwd": workdir, "error": str(exc)}


if __name__ == "__main__":
    import sys
    if "--list" in sys.argv:
        print(json.dumps(available_agents(), ensure_ascii=False, indent=2))
    else:
        if len(sys.argv) < 3:
            print("usage: local_agents.py <agent> <task> [cwd] | --list")
            raise SystemExit(2)
        print(json.dumps(run_local_agent(sys.argv[1], sys.argv[2],
                                         sys.argv[3] if len(sys.argv) > 3 else None),
                         ensure_ascii=False, indent=2))
