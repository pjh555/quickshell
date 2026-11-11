# Clavis 桌宠系统

这是一套完整的桌宠运行时：角色包、动画/动作、交互、Agent 状态反应、按角色设置、DSH 设置导入，以及聊天面板里的 Agent 监控中心。桌宠本体和监控中心是分开的：

- **桌宠**：透明置顶的角色，负责走动、动作、气泡和 Agent 状态动画。
- **监控中心**：聊天面板顶部的雷达按钮，展示本机所有 Agent 的会话/状态；不再单独占一个桌面窗口。

## 分层

```text
AgentService / AgentFleetService / PetSettingsService
                │
        PetProfile.js  ← 角色包数据 → 动作、菜单、交互、Agent 状态映射
                │
        AgentPet.qml   ← 行为控制器（idle / wander / ambient / action / drag / sleep）
                │
   PetFrames.qml / Image  ← 渲染器（帧动画 / 静态图）
```

- **角色包**：`assets/agent/pets/<id>/pet.json`（内置）或 `~/.config/clavis/pets/<id>/pet.json`（用户）。`PetPackService` 扫描、校验、解析相对路径。
- **PetProfile**：把角色包规范化为 `actions`、`agentStates`、`interactions`、`menu`、`ambient`、`wander`、`sleep`、`appearance`、`ui`。所有宠物共用同一套**控制器**，但动作、台词、菜单和语言全部来自各自角色包，不存在全角色共用的“摸摸/喂食/玩耍”默认台词。
- **AgentPet**：只消费 profile 和设置，不引用具体角色/动作 id。
- **PetSettings**：按角色持久化大小、显示、位置、是否散步、是否响应 Agent、音效等。
- **AgentFleet**：本机 Agent 发现与监控，视图嵌入聊天面板。

## 语言和动作属于角色包

框架不替宠物发明性格，也不把同一套动作强加给所有角色：

- 每个角色包自己声明 `actions`、每个动作的 `say` 台词、`menu` 标签和 `interactions`。
- 没有 `say` 就是静默动作；没有 `menu` 就只显示框架的 Agent/设置入口；没有 `workStatusTexts` 就不说通用状态台词（只显示真实任务文本）。
- `ui.menuTitle` / `ui.agentPanel` / `ui.petSettings` 让菜单标题和框架入口也能按角色本地化。
- `language` 是角色默认语言；`locales` / `i18n` 可以为一个角色提供多语言覆盖。覆盖字段可以是 `actions`（按动作合并）、`menu`、`ui`、`workStatusTexts`、`behavior.wander.say`、`sleep.say/wakeSay` 等；没有匹配的语言就使用基础角色包。
- 框架自身的 Agent/设置/菜单标题兜底走 `qsTr`，字符台词不经过框架翻译。
- 设置页「角色语言」会列出角色默认语言和 `locales`；也可以用 IPC：

```bash
qs -c clavis ipc call agent setPetLanguage zh-CN
# 清空覆盖，回到角色包默认语言
qs -c clavis ipc call agent setPetLanguage ""
```

- `behavior.sleep.say` / `wakeSay` 和 `behavior.wander.say` 分别控制睡觉、醒来、散步时该角色自己的话；没有就保持安静。
- 当前四个角色包就是四种不同配置：大肥鱼是中文摸鱼口吻，dsh-pet 是 DSH 工具口吻，ChatGPT 默认英文分析口吻（带 `zh-CN` locale），Claude 是中文书卷口吻。

框架只保留中性的行为机制（idle、走动、拖拽、Agent 状态动画）和 Agent/设置入口；不会自动生成角色动作。

迁移旧角色包时，如果它以前依赖框架的通用 `pet/feed/play` 动作，请在该角色的 `actions`/`menu`/`interactions` 中补上自己的定义；或用导入器加 `--profile`。这是有意的变化：动作和语言属于角色，而不是框架。

## 角色包能力

一个角色包可以声明：

| 能力 | 字段 |
| --- | --- |
| 形象/动画 | `renderer: frames/image`、`animations` |
| 待机/散步 | `behavior.wander`、`speed`、`facing`、`say` |
| 自定义动作 | `actions`（动画、时长、台词、打开 Agent、发 prompt） |
| 点击/双击/拖拽/右键 | `interactions` |
| 右键动作菜单 | `menu`（标签由角色包提供） |
| 环境自播 | `behavior.ambient`（加权动作） |
| 睡眠 | `behavior.sleep`（`say` / `wakeSay`） |
| Agent 状态反应 | `agentStates` + `workStatusTexts` |
| 语言/菜单文案 | `language`、`locales`/`i18n`、`ui` |
| 外观 | `appearance`（阴影、名字、默认大小） |
| DSH 兼容 | `aliases`、`dsh` 元数据 |

详见 `docs/pet-packs.md`。

## 按角色设置

设置页 → Agent → 桌面 Agent 桌宠：

- 桌宠形象（自动列出所有角色包）
- 角色语言（角色默认语言 + `locales`，按角色记忆）
- 重新扫描角色包
- 在聊天面板打开监控中心
- 当前角色大小
- 桌宠音效 / 音量
- 在桌面显示（关闭 = 只保留聊天）
- 允许桌宠散步
- 响应本机 Agent 状态
- 重置当前角色设置
- 导入 DSH 桌宠设置

持久化在 `~/.config/clavis/pet-settings.json`：

```json
{
  "version": 1,
  "pets": {
    "dsh-pet": {
      "size": 112,
      "display": "desktop",
      "fixed": false,
      "workStatusEnabled": true,
      "sounds": true,
      "x": 1180,
      "y": 700,
      "agentStates": {
        "working": "working",
        "waiting": "waiting"
      },
      "workStatusTexts": [["思考中"], ["干活中"], ["有进展"], ["等你"], ["完成"], ["出错"]]
    }
  }
}
```

`x`/`y` 由拖动自动保存；`position` 也可以使用 DSH 风格的 `corner/marginX/marginY`。

## DSH / dsh-pet 兼容

Clavis **不复制 dsh-pet 的代码**，只兼容它的设置数据：

- 读取 `~/.dsh/dsh-pet/main-config.jsonc`（以及旧 `.json`）
- 读取 `~/.dsh/dsh-pet/pet/<prefix>-config.json(c)` 文件宠物
- 自动去掉 JSONC 注释
- 映射到 Clavis 设置：
  - `size`：DSH 462 基准 → Clavis 112 基准，clamp 64–240
  - `display`、`position.corner/marginX/marginY`
  - `fixedEnabled` → `fixed`
  - `workStatusEnabled`
  - `clickSoundEnabled` → `sounds`
  - `animations.events.workStatus` → `agentStates`（按 DSH 档位 0..5）
  - `workStatusTexts`
  - `animations/animationWeights/physics/font` 原样保留在 `dsh` 字段，供后续扩展
- 角色包通过 `aliases` 接收导入设置，例如 `dsh-pet` 声明 `aliases: ["main"]`，DSH 的 `main` 设置会应用到它。
- 导入入口：设置页「导入 DSH 桌宠设置」，或 `scripts/agent/dsh-pet-settings.py --file <config>` 查看规范化结果。

这是**设置层兼容**；DSH 的 webm 素材可先转成帧/图集，再作为普通角色包使用（内置的 `dsh-pet` 包就是这样生成的）。

## Agent 监控中心

- 打开聊天面板（顶栏 Agent 图标），点击标题栏的 `radar` 按钮。
- 监控视图是聊天面板的**同一块玻璃面板**：共用标题栏、关闭/返回按钮、14px 内容边距、字体、圆角和输入框样式；不再有独立的覆盖层风格，也不在桌面单独开窗。
- `AgentFleetService` 每 3.5 秒运行 `scripts/agent/agent-fleet.py`，只读本机：
  - Clavis 自身（健康检查）
  - Codex（`~/.codex/sessions/**/rollout-*.jsonl`）
  - Claude Code（`~/.claude/transcripts/*.jsonl`、`projects/**`）
  - OpenCode（`~/.local/share/opencode/opencode.db`，只读 SQLite）
  - DSH / WorkBuddy / Hermes / Gemini / Qwen / Aider / Goose（进程 + 常见会话目录）
  - 未知 Agent：在 `~/.config/clavis/agent-fleet.json` 增加 `patterns` 即可
- 每个 Agent 卡片支持：
  - `让 Clavis 看`：把会话路径/任务交给 Clavis Agent 读取并总结
  - `派活`：让 Clavis 通过 `run_local_agent` 调用该本机 Agent 执行任务
  - `打开对话` / `目录`
- 底部可以直接给 Clavis 一个任务，或让它汇总全部 Agent。
- 桌宠只根据最高优先级 Agent 状态播放动画/气泡：`waiting > error > working > thinking > result > success`；监控细节在聊天面板。

## 扩展点

### 新增角色

把 `pet.json` + 帧图/预览图放进 `~/.config/clavis/pets/<id>/`，点击「重新扫描角色包」，在设置里选择。不需要改 QML。

### 新增 Agent 适配器

在 `scripts/agent/agent-fleet.py` 中增加一个 `scan_<agent>`，或在 `~/.config/clavis/agent-fleet.json` 增加：

```json
{
  "patterns": {
    "myagent": ["myagent-cli"]
  }
}
```

### 导入已有 / 新生成的宠物

```bash
# Codex / OpenPet 图集（1536x1872 或 1536x2288）
python3 scripts/agent/import-pet-pack.py /path/to/codex-pet --id my-pet

# 带角色自己的动作/台词/菜单配置导入
python3 scripts/agent/import-pet-pack.py /path/to/codex-pet --id my-pet \
  --profile my-pet-profile.json

# 旧桌宠：单张透明 PNG/WebP
python3 scripts/agent/import-pet-pack.py /path/to/old-pet.png --name "旧桌宠" \
  --profile old-pet-profile.json

# 已有 Clavis 角色包
python3 scripts/agent/import-pet-pack.py /path/to/existing-pack --id my-pack

# 导入后重新扫描
qs -c clavis ipc call agent reloadPets
```

导入器会把 Codex/OpenPet 9 行图集切成 `idle/running/waiting/failed/review/waving/jumping` 等帧，但**不会给所有宠物写同一套“摸摸/看看书/一起工作”的台词或动作**。没有提供 profile 时，只生成中性机制：动画、行走、拖拽、右键菜单和框架的 Agent/设置入口；该角色的 `actions`、`say`、`menu`、`workStatusTexts`、`ui`、`language`、`locales` 由源 `pet.json` 或 `--profile` 提供。示例见 `docs/examples/pet-profile.json`。单张图片生成 `image` 渲染器角色包，默认同样不编造角色动作。

### 新增渲染器

在 `PetProfile`/`AgentPet` 中增加一个新 `renderer` 分支；当前支持 `frames` 和 `image`。角色包格式不绑定某个角色。

### 新增动作

在角色包 `actions` 中增加带 `animation`/`duration`/`say`/`agent`/`prompt` 的动作，再在 `menu` 或 `interactions` 引用即可。

## 让 Clavis 调用本机 Agent

监控中心卡片上的「派活」会把任务交给 Clavis；Clavis 通过 `run_local_agent` 工具调用 Codex / Claude Code / OpenCode / DSH / WorkBuddy 等本机 CLI。配置、工具参数、HTTP API 和安全边界见 [`local-agents.md`](./local-agents.md)。电脑控制设置里可以关闭「允许 Clavis 调度本机 Agent」。

## 独立版

独立 GTK4 大肥鱼程序仍在 `~/.local/share/dafeiyu-pet/`，但自启动已禁用，避免和 Agent 桌宠重复。需要时运行 `~/.local/bin/dafeiyu-pet`。
