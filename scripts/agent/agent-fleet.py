#!/usr/bin/env python3
"""Local agent fleet discovery for Clavis.

Reads only local process/session metadata and prints a normalized JSON snapshot.
It never uploads anything. New agents can be added with
~/.config/clavis/agent-fleet.json (patterns/paths) or a small adapter below.

Usage:
    agent-fleet.py [--pretty] [--mock]
"""
from __future__ import annotations

import glob
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
NOW = time.time()

CODEX_HOME = Path(os.environ.get("CODEX_HOME", HOME / ".codex"))
CLAUDE_HOME = Path(os.environ.get("CLAUDE_CONFIG_DIR", HOME / ".claude"))
OPENCODE_DB = Path(os.environ.get("OPENCODE_DB", HOME / ".local/share/opencode/opencode.db"))
CLAVIS_HEALTH = os.environ.get("CLAVIS_AGENT_HEALTH", "http://127.0.0.1:8765/health")

RECENT_SESSION_WINDOW = 30 * 86400  # show recent sessions, but mark old ones idle
ACTIVE_WINDOW = 120                 # seconds since last session update
MAX_AGENTS = 10

STATUS_LABEL = {
    "thinking": "思考中",
    "working": "工作中",
    "result": "有进展",
    "waiting": "等待确认",
    "success": "已完成",
    "error": "出错",
    "running": "运行中",
    "idle": "空闲",
    "offline": "离线",
}

DEFAULT_PATTERNS = {
    "codex": ["codex"],
    "claude": ["claude"],
    "opencode": ["opencode"],
    "dsh": ["dsh", "deepseek-harness", "deepseek_harness"],
    "workbuddy": ["workbuddy", "work-buddy"],
    "hermes": ["hermes"],
    "gemini": ["gemini-cli", "gemini"],
    "qwen": ["qwen"],
    "aider": ["aider"],
    "goose": ["goose"],
    "clavis": ["clavis-agentd", "clavis-agent"],
}

DISPLAY_NAME = {
    "codex": "Codex",
    "claude": "Claude Code",
    "opencode": "OpenCode",
    "dsh": "DeepSeek Harness",
    "workbuddy": "WorkBuddy",
    "hermes": "Hermes",
    "gemini": "Gemini CLI",
    "qwen": "Qwen Code",
    "aider": "Aider",
    "goose": "Goose",
    "clavis": "Clavis Agent",
}

KIND_COLOR = {
    "clavis": "primary",
    "codex": "success",
    "claude": "tertiary",
    "opencode": "primary",
    "dsh": "secondary",
    "workbuddy": "secondary",
}


def short(text, limit=90):
    text = re.sub(r"\s+", " ", str(text or "")).strip()
    if len(text) > limit:
        text = text[:limit - 1] + "…"
    return text


def shape_row(kind, **kwargs):
    row = {
        "id": kwargs.get("id") or kind,
        "kind": kind,
        "name": kwargs.get("name") or DISPLAY_NAME.get(kind, kind.title()),
        "status": kwargs.get("status") or "idle",
        "statusLabel": STATUS_LABEL.get(kwargs.get("status") or "idle", "空闲"),
        "title": short(kwargs.get("title") or "", 90),
        "task": short(kwargs.get("task") or "", 120),
        "cwd": kwargs.get("cwd") or "",
        "pid": kwargs.get("pid") or 0,
        "pids": kwargs.get("pids") or [],
        "model": kwargs.get("model") or "",
        "tokens": kwargs.get("tokens") or 0,
        "cost": round(float(kwargs.get("cost") or 0), 4),
        "sessionId": kwargs.get("sessionId") or "",
        "sessionPath": kwargs.get("sessionPath") or "",
        "updatedAt": float(kwargs.get("updatedAt") or 0),
        "active": bool(kwargs.get("active")),
        "source": kwargs.get("source") or "session",
        "canChat": bool(kwargs.get("canChat")),
        "color": kwargs.get("color") or KIND_COLOR.get(kind, "secondary"),
    }
    if not row["active"] and row["status"] in ("working", "thinking", "waiting", "result"):
        row["status"] = "idle"
        row["statusLabel"] = STATUS_LABEL["idle"]
    return row


# ---------------------------------------------------------------------------
# processes
# ---------------------------------------------------------------------------
def read_text(path, limit=0):
    try:
        with open(path, "rb") as f:
            data = f.read(limit if limit > 0 else -1)
        return data.decode("utf-8", "replace")
    except Exception:
        return ""


def process_list():
    try:
        out = subprocess.run(["ps", "-eo", "pid=,etimes=,comm=,args="],
                             capture_output=True, text=True, timeout=4).stdout
    except Exception:
        return []
    rows = []
    for line in out.splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) < 3:
            continue
        try:
            pid, etimes = int(parts[0]), int(parts[1])
        except ValueError:
            continue
        comm, args = parts[2], (parts[3] if len(parts) > 3 else "")
        if pid == os.getpid():
            continue
        rows.append({"pid": pid, "etimes": etimes, "comm": comm, "args": args})
    return rows


def classify_processes(procs, extra_patterns=None):
    patterns = {k: list(v) for k, v in DEFAULT_PATTERNS.items()}
    if extra_patterns:
        for k, v in extra_patterns.items():
            patterns.setdefault(k, [])
            patterns[k].extend([str(x) for x in v])
    found = {}
    for p in procs:
        hay = (p["comm"] + " " + p["args"]).lower()
        if "agent-fleet.py" in p["args"]:
            continue
        for kind, names in patterns.items():
            if any(str(name).lower() in hay for name in names):
                # avoid matching "codex" inside an unrelated shell command string
                token = (p["comm"] + " " + " ".join(p["args"].split()[:3])).lower()
                if not any(str(name).lower() in token for name in names):
                    continue
                found.setdefault(kind, []).append(p)
                break
    return found


def process_cwd(pid):
    try:
        return os.readlink(f"/proc/{pid}/cwd")
    except Exception:
        return ""


def process_row(kind, procs):
    if not procs:
        return None
    p = procs[0]
    cwd = process_cwd(p["pid"])
    return shape_row(kind, id=f"{kind}:process", status="running", active=True,
                     title=short(cwd or p["args"], 80) or DISPLAY_NAME.get(kind, kind),
                     task="进程运行中", cwd=cwd, pid=p["pid"],
                     pids=[x["pid"] for x in procs], source="process",
                     updatedAt=NOW, canChat=(kind == "clavis"))


# ---------------------------------------------------------------------------
# Codex
# ---------------------------------------------------------------------------
def tail_lines(path, max_bytes=180_000):
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - max_bytes))
            data = f.read()
        return data.decode("utf-8", "replace").splitlines()
    except Exception:
        return []


def first_json_line(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for _ in range(3):
                line = f.readline()
                if not line:
                    break
                try:
                    return json.loads(line)
                except Exception:
                    continue
    except Exception:
        pass
    return {}


def codex_adapters(procs):
    rows = []
    files = glob.glob(str(CODEX_HOME / "sessions" / "*" / "*" / "*" / "rollout-*.jsonl"))
    files = sorted(files, key=lambda p: os.path.getmtime(p), reverse=True)
    seen_sessions = set()
    for path in files[:10]:
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        if NOW - mtime > RECENT_SESSION_WINDOW:
            continue
        meta = first_json_line(path)
        payload = meta.get("payload") or {}
        session_id = str(payload.get("session_id") or payload.get("id") or Path(path).stem)
        if session_id in seen_sessions:
            continue
        seen_sessions.add(session_id)
        cwd = payload.get("cwd") or ""
        last_user, last_event, last_tool, model = "", "", "", ""
        turn = ""
        tokens = 0
        waiting = False
        for line in tail_lines(path):
            try:
                obj = json.loads(line)
            except Exception:
                continue
            typ = str(obj.get("type") or "")
            p = obj.get("payload") or {}
            if typ == "turn_context":
                cwd = p.get("cwd") or cwd
                model = p.get("model") or model
            elif typ == "event_msg":
                et = str(p.get("type") or "")
                if et == "user_message":
                    msg = str(p.get("message") or "").strip()
                    if msg and "environment_context" not in msg:
                        last_user = msg
                    last_event = "user"
                elif et == "task_started":
                    last_event, turn = "task_started", "thinking"
                elif et == "task_complete":
                    last_event, turn = "task_complete", "success"
                elif et in ("turn_aborted", "error"):
                    last_event, turn = et, "error"
                elif et in ("exec_approval_request", "apply_patch_approval_request",
                            "request_user_input", "approval_request"):
                    wait = True
                    waiting = True
                    last_event = et
                elif et == "agent_message":
                    last_event = "assistant"
                elif et == "token_count":
                    info = p.get("info") or {}
                    usage = info.get("total_token_usage") or info.get("last_token_usage") or {}
                    tokens = int(usage.get("total_tokens") or usage.get("input_tokens") or 0) or tokens
            elif typ == "response_item":
                rt = str(p.get("type") or "")
                if rt == "message":
                    role = str(p.get("role") or "")
                    text = ""
                    for c in p.get("content") or []:
                        if isinstance(c, dict):
                            text += str(c.get("text") or "")
                    if role == "user" and text and "environment_context" not in text:
                        last_user = text
                        last_event = "user"
                    elif role == "assistant":
                        last_event = "assistant"
                elif rt == "function_call":
                    last_tool = str(p.get("name") or "")
                    last_event = "tool"
                elif rt == "function_call_output":
                    last_event = "tool_result"
        recent = NOW - mtime < ACTIVE_WINDOW
        proc_active = bool(procs)
        if waiting:
            status = "waiting"
        elif turn == "error" and recent:
            status = "error"
        elif proc_active and recent:
            status = "working" if last_event not in ("task_started", "") else "thinking"
        elif turn == "success" and recent:
            status = "success"
        elif proc_active:
            status = "idle"
        elif recent:
            status = "idle"
        else:
            status = "idle"
        rows.append(shape_row(
            "codex", id=f"codex:{session_id}", status=status, active=proc_active and recent,
            title=last_user or f"Codex 会话 {session_id[:8]}",
            task=last_tool or last_user, cwd=cwd, model=model, tokens=tokens,
            sessionId=session_id, sessionPath=path, updatedAt=mtime,
            pid=procs[0]["pid"] if procs else 0,
            pids=[x["pid"] for x in procs], source="session",
        ))
        if len(rows) >= 3:
            break
    if not rows and procs:
        rows.append(process_row("codex", procs))
    return [r for r in rows if r]


# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
def claude_adapters(procs):
    rows = []
    files = glob.glob(str(CLAUDE_HOME / "transcripts" / "*.jsonl"))
    files += glob.glob(str(CLAUDE_HOME / "projects" / "**" / "*.jsonl"), recursive=True)
    files = sorted(set(files), key=lambda p: os.path.getmtime(p), reverse=True)
    for path in files[:8]:
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        if NOW - mtime > RECENT_SESSION_WINDOW:
            continue
        last_user, last_event, last_tool, cwd, model = "", "", "", "", ""
        error = False
        waiting = False
        tokens = 0
        for line in tail_lines(path):
            try:
                obj = json.loads(line)
            except Exception:
                continue
            typ = str(obj.get("type") or "")
            if obj.get("cwd"):
                cwd = str(obj.get("cwd"))
            if typ == "user":
                content = obj.get("content")
                text = content if isinstance(content, str) else ""
                if not text and isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get("type") == "text":
                            text += str(c.get("text") or "")
                text = text.strip()
                if text and not text.startswith("<"):
                    last_user = text
                last_event = "user"
            elif typ == "tool_use":
                last_tool = str(obj.get("tool_name") or "")
                last_event = "tool"
            elif typ == "tool_result":
                last_event = "tool_result"
            elif typ == "assistant":
                msg = obj.get("message") or {}
                model = str(msg.get("model") or model)
                usage = msg.get("usage") or {}
                tokens = int(usage.get("input_tokens") or 0) + int(usage.get("output_tokens") or 0) or tokens
                last_event = "assistant"
                stop = str(msg.get("stop_reason") or "")
                if stop in ("end_turn", "stop"):
                    last_event = "done"
            elif typ == "system":
                subtype = str(obj.get("subtype") or "")
                if "permission" in subtype or "approval" in subtype:
                    waiting = True
                if "error" in subtype:
                    error = True
                last_event = "system"
            elif typ in ("error", "failed"):
                error = True
                last_event = "error"
            elif typ == "result":
                if str(obj.get("subtype") or "") == "error":
                    error = True
                last_event = "done"
        recent = NOW - mtime < ACTIVE_WINDOW
        proc_active = bool(procs)
        if error and recent:
            status = "error"
        elif waiting and recent:
            status = "waiting"
        elif proc_active and recent:
            status = "working" if last_event in ("tool", "tool_result", "user") else "thinking"
        elif last_event == "done" and recent:
            status = "success"
        else:
            status = "idle"
        session_id = Path(path).stem
        rows.append(shape_row(
            "claude", id=f"claude:{session_id}", status=status, active=proc_active and recent,
            title=last_user or f"Claude 会话 {session_id[:14]}",
            task=last_tool or last_user, cwd=cwd, model=model, tokens=tokens,
            sessionId=session_id, sessionPath=path, updatedAt=mtime,
            pid=procs[0]["pid"] if procs else 0,
            pids=[x["pid"] for x in procs], source="session",
        ))
        if len(rows) >= 3:
            break
    if not rows and procs:
        rows.append(process_row("claude", procs))
    return [r for r in rows if r]


# ---------------------------------------------------------------------------
# OpenCode
# ---------------------------------------------------------------------------
def opencode_adapters(procs):
    rows = []
    if not OPENCODE_DB.is_file():
        return [process_row("opencode", procs)] if procs else []
    try:
        con = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True, timeout=2)
        con.row_factory = sqlite3.Row
        sessions = con.execute(
            "select id,title,directory,tokens_input,tokens_output,cost,time_created,time_updated,model,agent "
            "from session order by time_updated desc limit 8"
        ).fetchall()
        for s in sessions:
            updated = float(s["time_updated"] or 0) / 1000.0
            if NOW - updated > RECENT_SESSION_WINDOW:
                continue
            last_msg = con.execute(
                "select data from message where session_id=? order by time_created desc limit 1",
                (s["id"],),
            ).fetchone()
            parts = con.execute(
                "select data from part where session_id=? order by time_created desc limit 6",
                (s["id"],),
            ).fetchall()
            role, finish, last_part_type, last_tool, task = "", "", "", "", ""
            active_part = False
            error = False
            if last_msg:
                try:
                    md = json.loads(last_msg["data"])
                    role = str(md.get("role") or "")
                    finish = str(md.get("finish") or "")
                except Exception:
                    pass
            for p in parts:
                try:
                    pd = json.loads(p["data"])
                except Exception:
                    continue
                pt = str(pd.get("type") or "")
                last_part_type = pt
                if pt == "tool":
                    last_tool = str(pd.get("tool") or "")
                    state = pd.get("state") or {}
                    st = str(state.get("status") or "")
                    if st in ("running", "pending"):
                        active_part = True
                    if st == "error":
                        error = True
                    inp = state.get("input") or {}
                    if isinstance(inp, dict):
                        task = str(inp.get("command") or inp.get("description") or inp.get("filePath") or "")
                elif pt == "text":
                    if not task:
                        task = str(pd.get("text") or "")
                elif pt in ("step-start", "step-finish", "reasoning"):
                    pass
            recent = NOW - updated < ACTIVE_WINDOW
            proc_active = bool(procs)
            if error and recent:
                status = "error"
            elif proc_active and recent and (active_part or role in ("user", "assistant") and finish == "tool-calls"):
                status = "working"
            elif proc_active and recent and last_part_type in ("step-start", "reasoning"):
                status = "thinking"
            elif recent and finish == "stop":
                status = "success"
            elif proc_active:
                status = "idle"
            else:
                status = "idle"
            model = ""
            try:
                m = json.loads(s["model"] or "{}")
                model = str(m.get("id") or m.get("modelID") or "")
            except Exception:
                pass
            rows.append(shape_row(
                "opencode", id=f"opencode:{s['id']}", status=status, active=proc_active and recent,
                title=s["title"] or f"OpenCode 会话 {s['id'][:12]}",
                task=task or s["title"], cwd=s["directory"] or "",
                model=model, tokens=int(s["tokens_input"] or 0) + int(s["tokens_output"] or 0),
                cost=float(s["cost"] or 0), sessionId=s["id"], sessionPath=str(OPENCODE_DB),
                updatedAt=updated, pid=procs[0]["pid"] if procs else 0,
                pids=[x["pid"] for x in procs], source="session",
            ))
            if len(rows) >= 3:
                break
        con.close()
    except Exception as exc:
        print(f"opencode adapter: {exc}", file=sys.stderr)
    if not rows and procs:
        rows.append(process_row("opencode", procs))
    return [r for r in rows if r]


# ---------------------------------------------------------------------------
# Generic process/session adapters (DSH, WorkBuddy, third-party)
# ---------------------------------------------------------------------------
def generic_session_rows(kind, procs, roots, max_rows=2):
    rows = []
    patterns = []
    for root in roots:
        root = Path(os.path.expanduser(str(root)))
        if not root.is_dir():
            continue
        patterns += glob.glob(str(root / "**" / "*.jsonl"), recursive=True)
        patterns += glob.glob(str(root / "**" / "*.json"), recursive=True)
    files = sorted(set(patterns), key=lambda p: os.path.getmtime(p), reverse=True)
    for path in files[:max_rows * 3]:
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        if NOW - mtime > RECENT_SESSION_WINDOW:
            continue
        recent = NOW - mtime < ACTIVE_WINDOW
        status = ("working" if recent and procs else ("success" if recent else "idle"))
        rows.append(shape_row(
            kind, id=f"{kind}:{path}", status=status,
            active=bool(procs) and recent, title=Path(path).stem,
            task="会话文件更新" if recent else "", cwd=str(Path(path).parent),
            sessionPath=path, updatedAt=mtime, pid=procs[0]["pid"] if procs else 0,
            pids=[x["pid"] for x in procs], source="session",
        ))
        if len(rows) >= max_rows:
            break
    if not rows and procs:
        rows.append(process_row(kind, procs))
    return rows


# ---------------------------------------------------------------------------
# Clavis itself
# ---------------------------------------------------------------------------
def clavis_adapter(procs):
    import urllib.request
    status, cwd = "offline", process_cwd(procs[0]["pid"]) if procs else ""
    try:
        with urllib.request.urlopen(CLAVIS_HEALTH, timeout=0.8) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
        if data.get("ok") is True:
            status = "idle"
    except Exception:
        status = "running" if procs else "offline"
    return shape_row(
        "clavis", id="clavis:self", status=status, active=True,
        title="Clavis Agent · 本机 Agent", task="在线，可接收任务" if status != "offline" else "后端离线",
        cwd=cwd, pid=procs[0]["pid"] if procs else 0,
        pids=[x["pid"] for x in procs], source="self", canChat=True,
        updatedAt=NOW,
    )


# ---------------------------------------------------------------------------
def load_extra_config():
    path = Path(os.environ.get("CLAVIS_FLEET_CONFIG", HOME / ".config/clavis/agent-fleet.json"))
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def mock_snapshot():
    t = NOW
    return {
        "ok": True,
        "generatedAt": t,
        "mock": True,
        "agents": [
            shape_row("clavis", id="clavis:self", status="working", active=True,
                      title="Clavis Agent · 本机 Agent", task="正在整理多 Agent 汇总",
                      updatedAt=t, canChat=True, source="self"),
            shape_row("codex", id="codex:mock", status="waiting", active=True,
                      title="修复登录流程的 token 刷新", task="等待批准：npm test",
                      cwd=str(HOME), updatedAt=t - 8, sessionPath="/tmp/mock-codex.jsonl"),
            shape_row("opencode", id="opencode:mock", status="success", active=True,
                      title="迁移设置页面", task="构建通过，准备提交",
                      cwd=str(HOME), updatedAt=t - 30, tokens=182400, cost=0.42),
            shape_row("claude", id="claude:mock", status="idle", active=False,
                      title="审查 AOSP 构建日志", task="上次活动 12 分钟前",
                      cwd=str(HOME), updatedAt=t - 720),
        ],
    }


def main():
    if "--mock" in sys.argv:
        snap = mock_snapshot()
    else:
        extra = load_extra_config()
        procs = classify_processes(process_list(), extra.get("patterns") or {})
        agents = [clavis_adapter(procs.get("clavis", []))]
        agents += codex_adapters(procs.get("codex", []))
        agents += claude_adapters(procs.get("claude", []))
        agents += opencode_adapters(procs.get("opencode", []))
        agents += generic_session_rows("dsh", procs.get("dsh", []), [
            HOME / ".dsh", HOME / ".config/dsh", HOME / ".local/share/dsh",
            HOME / ".deepseek-harness", HOME / ".config/deepseek-harness",
            HOME / ".local/share/deepseek-harness",
        ])
        agents += generic_session_rows("workbuddy", procs.get("workbuddy", []), [
            HOME / ".workbuddy", HOME / ".config/workbuddy", HOME / ".local/share/workbuddy",
            HOME / ".config/WorkBuddy", HOME / "WorkBuddy",
        ])
        for kind in ("hermes", "gemini", "qwen", "aider", "goose"):
            agents += generic_session_rows(kind, procs.get(kind, []), [
                HOME / f".{kind}", HOME / ".config" / kind, HOME / ".local/share" / kind,
            ], max_rows=1)
        seen = set()
        deduped = []
        for a in agents:
            if not a or a["id"] in seen:
                continue
            seen.add(a["id"])
            deduped.append(a)
        # Active rows first, then most recently updated.
        deduped.sort(key=lambda a: (not a["active"], -a["updatedAt"]))
        agents = deduped[:MAX_AGENTS]
        summary = {"total": len(agents), "active": 0, "working": 0, "waiting": 0,
                   "error": 0, "success": 0, "idle": 0, "running": 0}
        for a in agents:
            if a["active"]:
                summary["active"] += 1
            s = a["status"]
            if s in ("working", "thinking", "result"):
                summary["working"] += 1
            elif s in summary:
                summary[s] += 1
            else:
                summary["idle"] += 1
        snap = {"ok": True, "generatedAt": NOW, "agents": agents, "summary": summary}
    print(json.dumps(snap, ensure_ascii=False, indent=2 if "--pretty" in sys.argv else None,
                     separators=None if "--pretty" in sys.argv else (",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc), "agents": []}, ensure_ascii=False))
        raise SystemExit(1)
