# 桌宠角色包（Pet Packs）

Agent 桌宠不再把角色写死在 `AgentPet.qml` 里。角色由**角色包**描述，
`AgentPet` 只负责选择渲染器；新增角色只需要新增数据目录，不需要改 QML。

## 目录

```text
<shell>/assets/agent/pets/<id>/pet.json     # 内置角色包
~/.config/clavis/pets/<id>/pet.json         # 用户角色包（同名 id 覆盖内置）
```

`PetPackService` 启动时扫描这两个目录。用户目录后扫描，因此可以覆盖内置角色。
设置页「桌宠形象」会自动出现所有包；`AgentService.pet.image` 保存的是包 id。

## 最小示例

```json
{
  "schemaVersion": 1,
  "id": "my-pet",
  "name": "我的桌宠",
  "renderer": "frames",
  "preview": "preview.png",
  "behavior": {
    "wander": true,
    "speed": 26,
    "facing": "right"
  },
  "animations": {
    "idle": {
      "frames": ["frames/idle_0.png", "frames/idle_1.png"],
      "fps": 2,
      "loop": true
    },
    "walk": {
      "frames": ["frames/walk_0.png", "frames/walk_1.png", "frames/walk_2.png"],
      "fps": 6,
      "loop": true
    },
    "click": {
      "frames": ["frames/click_0.png", "frames/click_1.png"],
      "fps": 5,
      "loop": false
    },
    "drag": {
      "frames": ["frames/drag_0.png"],
      "fps": 1,
      "loop": true
    }
  }
}
```

## 字段

| 字段 | 说明 |
| --- | --- |
| `id` | 必填，唯一 id；保存到 `pet.image` |
| `name` | 设置页显示名 |
| `renderer` | `frames`（动画帧）或 `image`（单张静态图） |
| `preview` | 列表/回退预览图，相对包目录 |
| `image` | `renderer: "image"` 时必填 |
| `animations` | `renderer: "frames"` 时至少要有 `idle` |
| `behavior.wander` | 是否在桌面上自动散步；也可以写 `{ enabled, speed, animation, say }` |
| `behavior.speed` | 散步速度（逻辑像素/秒，默认 26） |
| `behavior.facing` | `right`（默认）或 `left`：walk 动画原始朝向 |
| `behavior.sleep` | 睡眠动画、`say` 和 `wakeSay` 台词；台词由角色包提供 |
| `language` / `locale` | 该角色自己的默认语言/地区 |
| `locales` / `i18n` | 可选的多语言覆盖；按语言选择角色自己的文案 |
| `ui` | 动作菜单标题和 Agent/设置入口的本地化标签 |

每个动画支持 `frames`（相对路径数组）、`fps`、`loop`、`pingpong`（来回播放，适合走路循环）。

## 动作、交互、菜单和 Agent 状态

角色包还可以声明（全部可选，**由角色包自己提供，框架不生成共用动作/台词**）：

```json
{
  "language": "zh-CN",
  "ui": {
    "menuTitle": "我的角色",
    "agentPanel": "Agent",
    "petSettings": "设置"
  },
  "actions": {
    "pet": { "animation": "waving", "duration": 1.6, "say": ["这个角色自己的台词"] },
    "read": { "animation": "review", "duration": 3.5, "loop": true },
    "ask": { "agent": "prompt", "prompt": "总结当前工作", "say": ["让我看看…"] }
  },
  "interactions": {
    "singleClick": "pet",
    "doubleClick": "read",
    "rightClick": "menu",
    "dragStart": { "animation": "jumping", "duration": 60, "loop": true },
    "dragEnd": "idle"
  },
  "menu": [
    { "id": "pet", "label": "摸摸", "icon": "favorite", "action": "pet" },
    { "separator": true },
    { "id": "agent", "label": "打开 Agent", "icon": "chat", "action": "agentPanel" }
  ],
  "agentStates": {
    "thinking": "review",
    "working": "running",
    "waiting": "waiting",
    "success": "jumping",
    "error": "failed"
  },
  "workStatusTexts": [
    ["思考中"], ["干活中"], ["有进展"], ["等你确认"], ["完成"], ["出错"]
  ],
  "sleep": {
    "after": 180,
    "animation": "sleep",
    "wakeAnimation": "wake",
    "say": ["Zzz…"],
    "wakeSay": ["醒了"]
  },
  "aliases": ["main"],
  "dsh": { "schema": "dsh-pet", "workStatusOrder": ["thinking", "working", "result", "waiting", "success", "error"] }
}
```

- 没有 `actions` / `say` / `menu` 时，不会自动补“摸摸、喂食、玩耍”等通用动作；框架只会补 Agent/设置入口。
- `actions` 的 key、标签、台词、显示顺序由角色包决定；不同角色可以有完全不同的动作集合和语言。
- `ui`、`language`、`locale` 是角色自己的界面语言/菜单文案，不会把别的角色语言强加过来。
- 可选 `locales` / `i18n` 为同一个角色提供多语言内容。运行时按角色默认语言或设置页「角色语言」选择；没有匹配就使用基础包。`actions` 按动作合并，`menu` 整体替换，`ui` 合并，`workStatusTexts` / `sleep` / `behavior.wander.say` 可覆盖：

```json
{
  "language": "en",
  "locales": {
    "zh-CN": {
      "actions": {
        "pat": { "label": "摸摸", "say": ["我在。"] }
      },
      "menu": [
        { "id": "pat", "label": "摸摸", "action": "pat" },
        { "separator": true },
        { "id": "agent", "label": "Agent", "action": "agentPanel" }
      ],
      "ui": { "menuTitle": "动作" },
      "workStatusTexts": [["思考中"], ["干活中"], ["有进展"], ["等你确认"], ["完成"], ["出错"]]
    }
  }
}
```

```bash
qs -c clavis ipc call agent setPetLanguage zh-CN
qs -c clavis ipc call agent setPetLanguage ""   # 回到角色默认语言
```

- `agent` 支持 `panel`、`toggle`、`prompt`、`settings`、`sleep`、`wake`。
- `menu` 中的 `fleet`/`fleetSummary` 不会显示在桌宠上：监控中心固定在聊天面板。
- `aliases` 让 DSH 设置（例如 `main`）可以应用到该角色包。
- 按角色设置和 DSH 导入见 [`pet-system.md`](./pet-system.md)。
帧图建议使用
**同一画布尺寸**的透明 PNG，并保持角色脚底/锚点一致；这样切换动作不会跳动。
所有帧会在启动后一次性加载，播放时只切换可见帧，避免闪烁。

## 接入方式

1. 把角色包目录放到 `~/.config/clavis/pets/<id>/`（或内置到
   `<shell>/assets/agent/pets/<id>/`）。
2. 设置 → Agent → 桌宠 → 重新扫描角色包。
3. 在「桌宠形象」里选择它。

已有 Codex/OpenPet 图集、旧静态图片或 Clavis 角色包可以用统一导入器：

```bash
# 只导入中性机制，不编造台词/动作
python3 scripts/agent/import-pet-pack.py /path/to/pet --id my-pet

# 带上这个角色自己的 actions/say/menu/ui/language
python3 scripts/agent/import-pet-pack.py /path/to/pet --id my-pet \
  --profile my-pet-profile.json

qs -c clavis ipc call agent reloadPets
```

`--profile` 是**单角色**资料文件，不是全局模板；可参考 `docs/examples/pet-profile.json`。不加 profile 时，导入器只生成动画/行走/拖拽等中性机制和框架 Agent/设置入口，不会自动写“摸摸/看看书”这类共用语言。

详细说明见 [`pet-system.md`](./pet-system.md#导入已有--新生成的宠物)。

`AgentPet.qml` 只判断 `renderer`：

- `image`：使用 `AgentService.petImageUrl`
- `frames`：实例化通用 `PetFrames`，读取 `animations`
- 点击播放 `click`，拖拽播放 `drag`，散步播放 `walk`，其余时间 `idle`
- 没有对应动画时自动回退到 `idle`

## 大肥鱼

`assets/agent/pets/dafeiyu/` 是内置示例：MIT 素材来自
`fatfish-pet-smart-companion` / `whale-girl`，角色设计 credit：ZipZipPipe。
角色包内的 `LICENSE` 与 `THIRD_PARTY_NOTICES.md` 保留了原始许可信息。


## 回滚

本次改动的原始 QML 备份在 `<repo>/.dafeiyu-backup/`。需要回滚时，把备份覆盖回
`AppShell.qml`、`Services/AgentService.qml`、`Modules/Agent/AgentPet.qml`、
`Modules/ControlCenter/AgentPage.qml`，删除 `Services/PetPackService.qml`、
`Modules/Agent/PetFrames.qml`、`assets/agent/pets/dafeiyu/` 和
`scripts/agent/list-pet-packs.py`，然后重启 `clavis-shell-ubuntu`。
