pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Local Agent Mission Control. The Python scanner discovers processes and
// session files; this singleton normalizes the result for the pet HUD and the
// fleet panel. Clavis itself is always one of the agents.
Singleton {
    id: root

    property var rawAgents: []
    property bool loaded: false
    property bool scanning: false
    property string error: ""
    property bool panelOpen: false
    property string debugState: ""

    readonly property var agents: {
        const list = (root.rawAgents || []).slice();
        let index = -1;
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].kind) === "clavis") {
                index = i;
                break;
            }
        }
        const existing = index >= 0 ? list[index] : null;
        const selfStatus = AgentService.busy ? "working" : (AgentService.online ? "idle" : "offline");
        const usage = AgentService.lastUsage || {};
        const selfRow = {
            "id": "clavis:self",
            "kind": "clavis",
            "name": "Clavis Agent",
            "status": selfStatus,
            "statusLabel": selfStatus === "working" ? "工作中" : (selfStatus === "offline" ? "离线" : "空闲"),
            "title": AgentService.config && AgentService.config.name ? AgentService.config.name : "Clavis Agent",
            "task": AgentService.busy ? "正在处理对话" : (AgentService.online ? "在线，可接收任务" : "后端离线"),
            "cwd": existing && existing.cwd ? existing.cwd : "",
            "pid": existing && existing.pid ? existing.pid : 0,
            "pids": existing && existing.pids ? existing.pids : [],
            "model": AgentService.config && AgentService.config.model ? AgentService.config.model : "",
            "tokens": Number(usage.total_tokens || usage.totalTokens || 0),
            "cost": 0,
            "sessionId": AgentService.sessionId || "",
            "sessionPath": "",
            "updatedAt": Date.now() / 1000,
            "active": true,
            "source": "self",
            "canChat": true,
            "color": "primary"
        };
        if (index >= 0)
            list[index] = selfRow;
        else
            list.unshift(selfRow);
        return list;
    }

    readonly property var summary: {
        const out = { "total": 0, "active": 0, "working": 0, "waiting": 0, "result": 0,
                      "error": 0, "success": 0, "idle": 0, "running": 0 };
        const list = root.agents || [];
        for (let i = 0; i < list.length; i++) {
            const a = list[i];
            out.total++;
            if (a.active)
                out.active++;
            const s = String(a.status || "idle");
            if (s === "working" || s === "thinking")
                out.working++;
            else if (s === "result")
                out.result++;
            else if (out[s] !== undefined)
                out[s]++;
            else
                out.idle++;
        }
        return out;
    }

    readonly property int activeCount: root.summary.active
    readonly property int waitingCount: root.summary.waiting
    readonly property int errorCount: root.summary.error
    readonly property int workingCount: root.summary.working + root.summary.result

    readonly property string summaryText: {
        const s = root.summary;
        if (s.total <= 1)
            return qsTr("Agent 空闲");
        return qsTr("%1 个 Agent · %2 工作中 · %3 等待").arg(s.total).arg(root.workingCount).arg(s.waiting);
    }

    // The pet HUD follows the most urgent active agent, not the most recent
    // random one. `running` (a server with no active session) is deliberately
    // treated as idle so a background OpenCode daemon doesn't animate forever.
    readonly property var petAgent: {
        const list = root.agents || [];
        let best = null;
        let bestRank = -1;
        for (let i = 0; i < list.length; i++) {
            const a = list[i];
            if (!a.active)
                continue;
            const s = String(a.status || "idle");
            let rank = 0;
            if (s === "waiting") rank = 6;
            else if (s === "error") rank = 5;
            else if (s === "working") rank = 4;
            else if (s === "thinking") rank = 3;
            else if (s === "result") rank = 2;
            else if (s === "success") rank = 1;
            if (rank > bestRank) {
                bestRank = rank;
                best = a;
            }
        }
        return best;
    }

    readonly property string petState: {
        if (root.debugState !== "")
            return root.debugState;
        const a = root.petAgent;
        if (!a)
            return "idle";
        const s = String(a.status || "idle");
        return (s === "running" || s === "offline") ? "idle" : s;
    }

    readonly property string petTask: {
        const a = root.petAgent;
        if (!a)
            return "";
        return a.task || a.title || a.statusLabel || "";
    }

    readonly property string petName: {
        const a = root.petAgent;
        return a ? String(a.name || "") : "";
    }

    function statusLabel(status) {
        const map = {
            "thinking": "思考中", "working": "工作中", "result": "有进展",
            "waiting": "等待确认", "success": "已完成", "error": "出错",
            "running": "运行中", "idle": "空闲", "offline": "离线"
        };
        return map[String(status || "idle")] || String(status || "空闲");
    }

    function statusColor(status) {
        switch (String(status || "idle")) {
        case "waiting": return Appearance.colors.colTertiary;
        case "error": return Appearance.colors.colError;
        case "working":
        case "thinking":
        case "result": return Appearance.colors.colPrimary;
        case "success": return Appearance.colors.colSecondary;
        default: return Appearance.colors.colOnSurfaceVariant;
        }
    }

    function statusIcon(kind) {
        switch (String(kind || "")) {
        case "clavis": return "smart_toy";
        case "codex": return "terminal";
        case "claude": return "menu_book";
        case "opencode": return "code";
        case "dsh": return "hub";
        case "workbuddy": return "work";
        default: return "smart_toy";
        }
    }

    function ago(ts) {
        const value = Number(ts || 0);
        if (value <= 0)
            return "";
        const diff = Math.max(0, Date.now() / 1000 - value);
        if (diff < 60)
            return qsTr("刚刚");
        if (diff < 3600)
            return qsTr("%1 分钟前").arg(Math.floor(diff / 60));
        if (diff < 86400)
            return qsTr("%1 小时前").arg(Math.floor(diff / 3600));
        return qsTr("%1 天前").arg(Math.floor(diff / 86400));
    }

    function tokenText(value) {
        const n = Number(value || 0);
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B";
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "k";
        return String(n);
    }

    function refresh() {
        if (scan.running)
            return;
        root.scanning = true;
        scan.running = true;
    }

    function openPanel() {
        root.refresh();
        root.panelOpen = true;
        AgentService.openPanel();
    }

    function closePanel() {
        root.panelOpen = false;
    }

    function togglePanel() {
        if (root.panelOpen)
            root.closePanel();
        else
            root.openPanel();
    }

    function contextLine(agent) {
        return "- " + (agent.name || agent.kind) + " [" + (agent.kind || "") + "]"
                + " 状态=" + (agent.statusLabel || statusLabel(agent.status))
                + " 任务=" + (agent.task || "无")
                + " 目录=" + (agent.cwd || "未知")
                + " 会话=" + (agent.sessionPath || "无");
    }

    function askAbout(agent) {
        if (!agent)
            return;
        const prompt = "请关注本机 " + (agent.name || agent.kind) + " 的会话。\n"
                + contextLine(agent) + "\n"
                + "请先读取/理解可用信息，然后用中文总结：它正在做什么、有没有卡住或风险、下一步建议。不要编造不存在的会话。";
        AgentService.openPanel();
        AgentService.send(prompt);
        root.closePanel();
    }

    function delegateTo(agent) {
        if (!agent)
            return;
        const name = String(agent.name || agent.kind || "本机 Agent");
        const kind = String(agent.kind || "");
        const cwd = String(agent.cwd || "");
        const context = String(agent.task || agent.title || "检查并继续推进这个会话");
        const prompt = "请直接调用本机 " + name + "（" + kind + "）执行任务。\n"
                + "工作目录：" + (cwd || "由你选择合适目录") + "\n"
                + "当前上下文：" + context + "\n"
                + "请使用 run_local_agent 工具，把完整、可执行的任务交给它；执行完用中文总结它的输出、改动和下一步。";
        AgentService.openPanel();
        AgentService.send(prompt);
        root.closePanel();
    }

    function sendSummary() {
        const list = root.agents || [];
        let lines = [];
        for (let i = 0; i < list.length; i++)
            lines.push(contextLine(list[i]));
        const prompt = "你是本机的 Agent 监控中心。下面是本机当前发现的 Agent 状态快照：\n\n"
                + lines.join("\n") + "\n\n"
                + "请用中文给出简洁的 Mission Control 汇总：哪些在运行、哪些在等待我、哪些出错、最值得我马上处理的一件事。不要编造不存在的信息。";
        AgentService.openPanel();
        AgentService.send(prompt);
        root.closePanel();
    }

    function openAgent(agent) {
        if (!agent)
            return;
        if (String(agent.kind) === "clavis") {
            AgentService.openPanel();
            return;
        }
        const path = agent.cwd || (agent.sessionPath ? String(agent.sessionPath).replace(/\/[^/]+$/, "") : "");
        if (path)
            Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        id: scan

        command: ["/usr/bin/python3", Paths.scriptPath("agent", "agent-fleet.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(String(this.text || "{}"));
                    root.rawAgents = data && Array.isArray(data.agents) ? data.agents : [];
                    root.error = data && data.ok === false ? String(data.error || "扫描失败") : "";
                } catch (e) {
                    root.rawAgents = [];
                    root.error = String(e);
                    console.warn("AgentFleetService: invalid snapshot:", e);
                }
                root.loaded = true;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = String(this.text || "").trim();
                if (text !== "")
                    console.warn("AgentFleetService:", text);
            }
        }

        onExited: exitCode => {
            root.scanning = false;
            if (!root.loaded)
                root.loaded = true;
            if (exitCode !== 0 && root.error === "")
                root.error = "扫描进程退出码 " + exitCode;
        }
    }

    Timer {
        interval: 3500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
