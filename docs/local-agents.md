# 本机 Agent 调度

Clavis 不只是监控本机 Agent，它还可以把具体任务交给本机已安装的 Agent CLI 执行。实现分两层：

1. **Agent tool**：Clavis 模型可调用 `list_local_agents` / `run_local_agent`
2. **HTTP API**：桌面 UI 或脚本可直接调用 `/v1/local-agents`、`/v1/local-agents/run`

监控中心卡片上的「派活」会把任务交给 Clavis，由 Clavis 选择本地 Agent 并调用工具；聊天里也可以直接说：

> 用 OpenCode 在当前目录修一下这个测试失败，改完告诉我。

## 默认支持的 Agent

| id | CLI | 默认命令 |
| --- | --- | --- |
| `codex` | Codex CLI | `codex -a never -s workspace-write exec --skip-git-repo-check --color never {prompt}` |
| `claude` | Claude Code | `claude -p {prompt}` |
| `opencode` | OpenCode | `opencode run --auto {prompt}` |

DSH / WorkBuddy / Hermes 等没有写死命令，放一个配置文件即可接入。

## 配置

`~/.config/clavis/local-agents.json`：

```json
{
  "agents": {
    "codex": {
      "name": "Codex",
      "command": ["codex", "-a", "never", "-s", "workspace-write",
                  "exec", "--skip-git-repo-check", "--color", "never", "{prompt}"],
      "timeout": 900
    },
    "opencode": {
      "name": "OpenCode",
      "command": ["opencode", "run", "--standalone", "--auto", "{prompt}"],
      "timeout": 900
    },
    "my-agent": {
      "name": "My Agent",
      "command": ["/path/to/my-agent", "run", "{prompt}"],
      "cwd": "/home/xiaomi/project",
      "timeout": 300
    }
  }
}
```

- `command` 必须是 argv 数组；不会经过 shell。
- `{prompt}` 会替换成任务文本；没有占位符时任务会追加到末尾。
- `{cwd}` 也可用；实际 `cwd` 由调用方传入或配置 `cwd`。
- 只允许配置里的 Agent id；没有任意 shell 入口。
- 超时时间默认 900 秒，最大 1800 秒。

## 工具

- `list_local_agents`：返回 id/name/available/path
- `run_local_agent`：参数 `agent`、`task`、`cwd`（可选）

Clavis 的电脑控制设置里可以关闭「允许 Clavis 调度本机 Agent」。

## HTTP

```bash
curl http://127.0.0.1:8765/v1/local-agents

curl -X POST http://127.0.0.1:8765/v1/local-agents/run \
  -H 'Content-Type: application/json' \
  -d '{"agent":"opencode","task":"修复测试","cwd":"/home/xiaomi/project"}'
```

返回 `ok`、`exitCode`、`duration`、`output`（末尾截断到 60k 字符）。

## 注意

- 这是让**受信任的本机 CLI**干活，CLI 自身的权限/审批策略仍然生效。Codex 的网络/登录失败、Claude 未安装等都会原样返回错误。
- 监控中心看到的是新产生的 Codex/Claude/OpenCode 会话；任务完成后会自动反映到 Agent 列表。
- 不要把 `local-agents.json` 配成任意 `sh -c`，这会绕过 argv 的安全边界。
