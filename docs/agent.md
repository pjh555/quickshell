# Clavis 原生桌面 Agent

这是 Clavis 的原生 Agent 集成，入口在顶栏的 `smart_toy` 图标，配置在
设置 → Agent。它不创建普通应用窗口：聊天面板是 layer-shell 覆盖层，桌宠也运行在
同一层。

## 架构

- `Services/AgentService.qml`：shell 侧状态、聊天、配置和桌宠状态。
- `Modules/Agent/AgentPanel.qml`：顶栏聊天面板。
- `Modules/Agent/AgentPet.qml`：可拖动、点击压扁的桌宠。
- `Modules/ControlCenter/AgentPage.qml`：所有 Agent 配置。
- `Services/AgentService.qml` 通过 `127.0.0.1:8765` 与本地服务通信。
- `scripts/agent/clavis-agentd.py`：持久化配置、会话和供应商调用。
- `packaging/systemd/user/clavis-agent.service`：用户级开机自启动服务。

服务默认支持 OpenAI-compatible Chat Completions 和 Responses 协议，因此可以接
OpenAI、DeepSeek、Ollama、本机网关，或 Codex++ Gateway：

```text
http://127.0.0.1:57321/gw/codex/v1
```

Codex++ Gateway 使用 Responses 协议；把协议开关切到 `Responses`。

## 配置

设置 → Agent 可以配置：

- Agent 名称、启用状态
- OpenAI-compatible Base URL、API 协议、模型、API Key
- 系统提示词
- 桌宠启用、形象、大小、自定义 https 图片、音效
- 语音对话：语音输入、自动朗读、连续对话、朗读语速
- Android / ADB：ADB 权限与序列号

配置写入 `~/.config/clavis/agent.json`，权限为 0600；聊天历史在
`~/.local/state/clavis-agent/sessions/`。

## 附件：图片与文件

聊天面板支持上传图片和文件（回形针按钮多选，或直接拖拽到面板）：

- **图片**（png/jpg/jpeg/webp/gif）→ 以多模态消息发给模型；供应商不支持视觉时
  自动去掉图片重发并注明，消息不会失败
- **文本类文件**（代码、日志、json、md 等 ≤200KB）→ 内容直接内联进本轮消息
- **PDF / Word(.docx) / PPT(.pptx) / Excel(.xlsx)** → 在本机抽取文本后内联：
  PDF 用 pypdf（`~/.local/share/clavis-agent/vendor/pypdf`），Office 系列解析
  OOXML；抽取失败或扫描件（无文本层）会退化为路径引用并明确提示
- **其他二进制** → 以路径标注给模型，可用 `read_attachment` 工具读取内容；
  该工具只允许访问本次会话上传过的文件，且 PDF/Office 文档同样会走本机抽取

限制：单个文件 ≤20MB、总计 ≤40MB、最多 8 个；旧版二进制 `.doc`/`.xls`/`.ppt`
不做文本抽取；扫描版 PDF 无文字层，需要 OCR（暂未内置）。

历史记录只保存附件标记（不内联全文），避免上下文膨胀。

## 语音对话

Agent 支持本地语音聊天：语音识别和语音合成都在本机完成，音频不会上传到任何
服务；只有识别出的文字会进入普通对话流程（因此仍然走已配置的模型供应商）。

- 录音：后端通过 PipeWire（`parecord`）采集默认麦克风，16 kHz 单声道
- 端点检测（VAD）：自适应噪声底 + 静音超时，说完停顿即自动发送
- 识别：vosk `vosk-model-small-cn-0.22`（本地流式识别，边说边出中间结果）
- 合成：espeak-ng（用户级安装于 `~/.local/clavis-voice/espeak-ng`），中文 `zh-cn`
- 播放：QML 侧 `paplay` 播放后端生成的 WAV

入口：

- 聊天面板输入框旁的麦克风按钮：开始/停止聆听，朗读时点击可打断
- IPC：`qs -c clavis ipc call agent voice`

行为：

- 聆听中面板会实时显示中间识别结果；静音后自动把文字发送给 Agent
- “自动朗读回复”开启时，回复完成后自动朗读（自动剔除 Markdown 代码块等）
- “连续对话”开启时，朗读结束后自动回到聆听状态，适合免提交流；
  点击停止按钮可随时退出循环

模型与组件路径（均可通过环境变量覆盖）：

- `~/.local/share/clavis-agent/models/vosk-model-small-cn-0.22`
- `~/.local/share/clavis-agent/vendor/vosk/libvosk.so`（ctypes 直接加载，
  不依赖 vosk Python 包及其第三方依赖）
- `~/.local/clavis-voice/espeak-ng`（apt 包用户级解包，`LD_LIBRARY_PATH` +
  `ESPEAK_DATA_PATH` 由后端注入）

若模型或引擎缺失，`/health` 的 `voice` 字段会显示 `stt`/`tts` 可用性，语音
端点会返回明确错误而不会静默失败。

## Codex++ 来源

本项目参考并安装了 BigPizzaV3/CodexPlusPlus 的 Agent 桌宠行为与设置模型：

- 仓库：https://github.com/BigPizzaV3/CodexPlusPlus
- AGPL-3.0-only
- 桌宠图库来自 Microsoft Fluent Emoji 3D（MIT），运行时从 jsDelivr 获取
- 桌宠音效来自上游 `assets/inject/agent-pet/sounds`，按上游原始素材声明使用；
  文件随 Clavis 一起分发，详见 `assets/agent/sounds/README.md`

上游代码位于当前用户的 `~/CodexPlusPlus`，未修改；Clavis 不把整个 Tauri 管理器
嵌入桌面，而是提供原生 shell 的 Agent 入口。

## 联网搜索

Agent 支持联网获取公开信息（受“联网搜索”权限控制，默认开启）：

- `web_search`：用 Bing（cn.bing.com）搜索，失败时自动回退百度，返回标题、
  链接与摘要；适合新闻、价格、软件版本、天气等时效性问题
- `read_url`：抓取网页并转为纯文本返回（上限 200KB），用于细读搜索结果；
  部分站点（如知乎）有反爬限制会返回 403，模型会改读其他结果

## 文档生成

Agent 可以在用户机器上生成 Word、PPT 和 PDF 文档（`create_document` 工具，
受“文档生成”权限控制，默认开启）：

- **docx / pptx**：由本机 pandoc（`~/.local/clavis-voice/pandoc`）把 markdown
  转换为目标格式；pptx 中每个 `# ` 一级标题开始一张新幻灯片
- **html**：pandoc 生成 standalone HTML5 网页；聊天里会以卡片内嵌渲染网页
  预览（无脚本、无远程资源），点击卡片用浏览器打开完整页面
- **pdf**：由 reportlab（`~/.local/share/clavis-agent/vendor/reportlab`）直接排版，
  内嵌 Noto Sans SC 字体，支持标题、段落、有序/无序列表、引用、分隔线与
  `**加粗**`/`*斜体*`
- 相对文件名默认保存到 `~/Documents`；`open=true` 时生成后用系统默认应用打开

## MCP 与技能（Skills）

### MCP 服务器

设置 → Agent → “MCP 服务器” 可查看、添加、启停和移除 MCP 服务器：

- **本地 stdio 服务器**：填写启动命令（如 `npx -y @modelcontextprotocol/server-filesystem /tmp`）
- **远程服务器**：填写 URL（streamable HTTP），设置后优先于命令
- **快捷添加**：预设 chips 一键填充表单——`time` / `memory` /
  `sequential-thinking` / `context7` / `fetch`（与上游 CodexPlusPlus
  `mcp-presets.ts` 同源，源自 cc-switch），以及免本地运行时的远程商用服务
  `context7 (HTTP)` 与 `deepwiki (HTTP)`；`fetch` 需要本机安装 uvx
- **对话配置**：直接对 Agent 说“添加一个 MCP 服务器 …（给出命令或 URL）”、
  “停用/删除 …”即可，模型通过 `manage_mcp` 工具写入配置，改动即时显示在本页；
  该能力可在“对话修改 MCP 与技能”开关中关闭
- 连接后其工具自动出现在模型可用工具列表（命名 `mcp__服务器__工具`），
  对话中即可直接调用；配置保存在 `~/.config/clavis/agent.json` 的 `mcp.servers`

### 技能

技能是带 `SKILL.md` 的文件夹（frontmatter 含 `name` / `description`，正文是
markdown 指令），存放于 `~/.local/share/clavis-agent/skills/`：

- 模型看到技能索引（名称+描述），用 `load_skill` 工具加载完整指令后再执行任务
- `load_skill` 也可读取技能目录内的资源文件
- 添加方式：设置页直接“创建技能”，或把文件夹放入技能目录（设置页可一键打开）
- **对话配置**：说“创建一个技能 …（给出名称/描述/内容）”，或让 Agent 修改、
  停用、删除技能，模型通过 `manage_skill` 工具写入 `SKILL.md`；该能力同样受
  “对话修改 MCP 与技能”开关控制
- 每个技能可单独停用；停用列表保存在配置 `skills.disabled`

## 电脑操作

设置 → Agent → “允许 Agent 操作电脑” 可以逐项打开桌面工具权限：

- 窗口：列出、聚焦、关闭窗口，切换全屏
- 启动应用 / 打开链接
- 键盘输入：向当前焦点应用输入文字或按键
- 剪贴板读写
- 联网搜索：搜索公开网页并读取页面内容，默认开启
- 文档生成：创建 Word/PPT/PDF 文件，默认开启
- Shell：高风险，默认关闭，需要单独开启

这些工具在本地后端执行，使用 Niri CLI 和 Wayland 输入工具；模型通过
OpenAI-compatible function calling 调用它们。关闭“允许 Agent 操作电脑”后，
模型不会再收到任何桌面工具定义。
