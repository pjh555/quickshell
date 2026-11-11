# IPC

Shell 生命周期可使用 `key-cli`；新增快捷键直接调用 Quickshell IPC：

```bash
key shell
qs -c clavis ipc show
qs -c clavis ipc call TARGET METHOD [ARGUMENTS...]
```

对应的 Quickshell 调用为：

```text
key shell                 → qs -c clavis -n
key shell --daemon        → qs -c clavis -n -d
key shell --kill          → qs -c clavis kill
key shell --log           → qs -c clavis log
key ipc show              → qs -c clavis ipc show
key ipc call A B ...      → qs -c clavis ipc call A B ...
```

Niri 快捷键和脚本不写裸 `quickshell ipc`，也不写用户源码路径。Shell 内部直接使用
Quickshell API 的地方不需要机械地经过 CLI。

托管快捷键写为独立 argv，不经过 shell 字符串或每次按键的配置 helper：

```kdl
spawn "qs" "-c" "clavis" "ipc" "call" "keystone" "hub"
```

`key ipc call` 的标准既有绑定可以识别为同一 Clavis 动作，但保留原文本。
录屏、录音、剪贴板继续使用各自的 `key` 接口。
动作目录根据实际 IpcHandler 注册维护；需参数的方法保留显式参数模板。
首次在快捷键页面点击“设置”创建缺失的 binds.kdl 时，写入以下默认键位。
全部使用 `spawn "qs" "-c" "clavis" "ipc" "call" ...`，并设置 `repeat=false`。
`Mod` 跟随 Niri 的主修饰键（通常为 Super）。

| 快捷键 | 功能 | IPC target / method / arguments |
| --- | --- | --- |
| Mod+Tab | 台前调度 | stage-manager toggle |
| Mod+Shift+K | 触屏键盘 | touch-keyboard toggle |
| Mod+Space | Spotlight 搜索 | spotlight toggle |
| F4 | Launchpad 应用网格 | launchpad toggle |
| Mod+Slash | 快捷键配置图 | shortcut-map toggle |
| Mod+Shift+Space | 网页搜索 | spotlight web |
| Mod+Alt+V | 剪贴板历史 | spotlight openMode clipboard |
| Mod+Alt+W | 壁纸选择 | spotlight openMode wallpapers |
| Mod+N | 通知与信息侧栏 | sidebar toggle dashboard |
| Mod+A | 快捷设置侧栏 | sidebar toggle quicksettings |
| Mod+Ctrl+Comma | 设置中心 | control-center toggle general |
| Mod+Shift+W | Keystone 主面板 | keystone hub |
| Mod+Shift+T | 工具面板 | keystone tools |
| Alt+Shift+L | 锁屏 | lock open |

这些键避开 Niri 常用窗口、工作区、截图和媒体控制。首次接入前按有效 include 链
检查物理键位占用（含 Mod/Super 别名），发现冲突则拒绝写入并列出键名；用户可释放
这些键，或自行创建自定义 binds.kdl 后接入。任意第三方配置都可能占用默认键，不能
保证对所有配置天然无冲突。已有文件即使为空也不补写，升级不恢复用户删改的绑定。
安装只部署程序；不会自动改写用户 Niri 配置。

目录维护依据：[niri 键绑定](https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html)、
[默认配置](https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl)、
[可绑定动作定义](https://github.com/niri-wm/niri/blob/main/niri-config/src/binds.rs) 与
[Quickshell IpcHandler](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/)。
托管片段按 [niri include 顺序](https://niri-wm.github.io/niri/Configuration:-Include.html)
处理覆盖。目录随程序部署，运行时只在本机验证动作支持，不联网下载。

快捷键配置图独立于设置中心加载，使用 `qs -c clavis ipc call shortcut-map toggle`
打开或关闭；也提供无参数的 `open` 和 `close`。账户页按钮与 IPC 共用同一个弹层。

侧栏 IPC 的参数按内容区分：`dashboard` 表示信息、抽屉和天气侧栏，`quicksettings`
表示快捷设置侧栏。通用设置 → 侧边栏中可独立选择各自的屏幕位置，默认仍为信息侧栏在左、快捷设置在右。
不同侧可同时打开；同侧时，点击另一组按钮会自动收起当前侧栏，待其退出后展开新的侧栏，
无需手动关闭。连续切换以最后一次请求为准，再次点击待展开侧栏可取消展开，Esc 可关闭全部。
将已打开的两组调整到同侧时，保留最近打开的一组。
`open`、`close`、`toggle` 均接受上述参数，返回 `DASHBOARD_OPEN/CLOSED` 或
`QUICKSETTINGS_OPEN/CLOSED`。旧参数 `left`、`right` 继续分别指向信息和快捷设置内容，
返回值保持 `LEFT_OPEN/CLOSED`、`RIGHT_OPEN/CLOSED`；它们不随实际位置重新解释。
已有用户绑定无需改写，快捷键页面会将旧参数识别为对应的内容动作。

灵动岛歌词界面通过 `qs -c clavis ipc call keystone lyrics` 切换展开与收起，返回
`LYRICS_OPENED` / `LYRICS_CLOSED`。两种样式均作用于当前输出（无匹配时使用首个屏幕），
展开时收起其他灵动岛面板。快捷键设置提供歌词动作占位，不绑定默认快捷键。


## 控制中心快捷操作

控制中心底部提供截屏、录屏和台前调度按钮。截屏在 Niri 打开原生截图界面；录屏使用
`wf-recorder` 配合 Clavis 区域选择，文件保存到 `~/Videos/Clavis-*.mp4`。底部的重启、
锁屏、关机使用三个圆形按钮，锁屏走 Clavis 安全锁屏流程。

## 触屏键盘

顶栏 Agent 图标旁的键盘按钮常驻，可直接打开或收起底部悬浮触屏键盘；控制中心面板
不再提供键盘入口，IPC 入口保持不变。

`qs -c clavis ipc call touch-keyboard toggle` 打开或关闭底部悬浮触屏键盘；`open`、
`close` 也可用。键盘沿用 Clavis 原有的 macOS 玻璃面板、键帽材质与强调色，采用 Gboard
风格的独立实现：10 列 QWERTY、字母键上滑输入数字或半角符号，长按弹出变音符号与标点
选项，Shift 双击锁定大写，退格长按连续删除。中文 26 键的候选栏首项带 `EN` 标记，可
直接上屏当前输入的原始英文字符串；`中/EN` 键切换纯英文输入模式。26 键主键盘带
`Home ← ↑ ↓ → End PgUp PgDn Del` 导航行。
支持 QWERTY、中文九键、`?123` 符号页、数字页、表情页和 Fn 桌面功能页。符号页采用
中文全角常用符号布局，`#+=` 打开全量符号面板（14 个分类 + 最近使用，含独立英文符号页）；数字页
采用三列结构：左侧运算符与返回、中间数字、右侧退格/空格/表情/回车。Fn 页提供
Esc、Tab、Ctrl/Alt/Super 粘滞修饰键、F1-F12、方向键、Home/End、PgUp/PgDn、Delete 等
常用键。中文九键的候选词显示在左侧候选栏，QWERTY 候选词条显示在顶部工具栏。英文/符号
通过 `wtype` 的虚拟键盘协议发送；中文 QWERTY 与九键都使用内置 libpinyin 候选，选择候选
后再用 `wtype` 发送 UTF-8 字符，因此不依赖终端的 IBus 客户端。`Mod+Shift+K` 为默认
键盘快捷键。

Niri 默认使用 **fcitx5** 的 Wayland 输入法（`zwp_input_method_v2`）处理物理键盘中文；
输入法面板和 Alacritty 等 text-input 客户端由 Clavis 启动。触屏键盘仍使用自带
libpinyin 候选条，不依赖 fcitx5/IBus。只有系统没有 fcitx5 时才回退到
`ibus-daemon` + `ibus-wayland`。Ubuntu 安装器会安装 fcitx5 相关包并设置
`im-config -n fcitx5`。

## 截图

`qs -c clavis ipc call screenshot capture` 在 Niri 下打开原生截图界面；Sway 下使用
`slurp` + `grim` 选择区域并保存到 `~/Pictures/Screenshots`。

## 顶栏控制中心

`qs -c clavis ipc call status-menu toggle` 打开或关闭顶栏右侧的控制中心下拉菜单；
`close` 关闭。下拉菜单使用固定两列布局承载网络、蓝牙、主题、夜间模式、免打扰、麦克风、
亮度/音量/麦克风滑块和设备状态，不再把全部状态项堆在顶栏。

## Launchpad

`qs -c clavis ipc call launchpad toggle` 打开或关闭全屏应用网格。`open`、`close` 语义与
Spotlight 相同；`openOn SCREEN` / `toggleOn SCREEN` 可指定输出名。重复调用 `open` 会回到
第一页并清空搜索，不改变已保存的布局。

- `page N`：打开并跳到第 N 页（从 0 开始）。
- `next` / `previous`：翻页，Shell 未打开时会先打开。
- `edit`：打开并进入长按/抖动编辑模式。
- `search TEXT`：打开并填入搜索文本，用于脚本或辅助工具。
- `folder ID`：打开指定文件夹；ID 来自 `~/.config/clavis/launchpad.json`。
- `reset`：恢复默认布局（按应用名排序、清空文件夹和隐藏项）。
- `restoreHidden`：把所有隐藏项恢复到布局末尾，不清除排列。

布局保存在 `~/.config/clavis/launchpad.json`，只包含应用 ID、文件夹和隐藏项；应用安装或
卸载后自动合并，不会覆盖用户排列。GNOME 下 Launchpad 使用普通全屏 toplevel，其他窗口
仍要求支持 `wlr-layer-shell` 的合成器（例如 Niri）。

### 全屏手势

触摸屏 + `wlr-layer-shell` 会话会加载 `Modules/Gestures/` 的边缘手势层；屏幕中部保持
点击穿透。动作名称与键位无关：

```bash
qs -c clavis ipc call gesture actions
qs -c clavis ipc call gesture trigger home
qs -c clavis ipc call gesture triggerOn quick-settings DP-1
```

`home` 打开 Launchpad，`overview` 在 Niri 和 Sway 下都打开 Clavis 窗口布局（
Niri 使用 WindowPreview 实时缩略图），`quick-settings` / `notifications` 打开对应侧栏，
`app-previous` / `app-next` 切换 Niri 列，`workspace-previous` / `workspace-next` 切换工作区，
`stage-manager` 打开或关闭台前调度侧栏。`trigger` 使用当前输出，`triggerOn` 指定输出。

### 台前调度（Niri）

`qs -c clavis ipc call stage-manager toggle` 打开或关闭左侧台前调度栏。侧栏按应用
分组列出当前未聚焦的窗口，使用 WindowPreview 提供实时缩略图；缩略图采用 macOS
Stage Manager 风格的左侧透视斜排、悬浮阴影和悬停标题，不再使用大面板和标题栏。
点击应用缩略图会聚焦并恢复该应用最近的窗口；右上角数字表示该应用还有多少个窗口。
`open`、`close` 和 `focus ID` 也可用，窗口 ID 来自 Niri 的 `windows` 列表。台前调度
只管理窗口切换，不改变 Niri 的平铺布局；`Mod+Tab` 为默认键盘入口。

### 窗口布局（Niri / Sway）

底部边缘长滑或 `Mod+O` 会打开窗口布局视图。Sway 使用窗口树和 `grim` 缩略图，
Niri 使用 `WindowPreviewService` 的实时窗口缩略图。两种后端都支持点击聚焦、
拖动卡片到顶部全屏；Sway 还支持拖到另一张卡片交换位置。

```bash
qs -c clavis ipc call windows toggle
qs -c clavis ipc call windows open
qs -c clavis ipc call windows close
qs -c clavis ipc call windows swap SOURCE_ID TARGET_ID
qs -c clavis ipc call windows fullscreen WINDOW_ID
```

在 Sway 布局中拖动窗口卡片到另一张卡片上会交换两个容器的位置；Niri 目前以
拖动到顶部全屏为主。拖到顶部高亮区域会切换该窗口的全屏状态。点击卡片聚焦并退出
布局，卡片左上角的红/黄/绿按钮分别关闭、最小化、最大化，右上角按钮或双击卡片可
直接切换全屏。`windows fullscreen` 是切换语义，重复调用会恢复原来的平铺布局。Sway
的窗口 ID 可通过 `swaymsg -t get_tree` 获取。可在 Sway 配置中绑定
`bindsym Mod4+Tab exec qs -c clavis ipc call windows toggle` 作为键盘入口。
在 Niri 中 `Mod+O` 打开 Clavis 窗口布局，`Mod+Shift+O` 保留 Niri 自带 Overview。
窗口布局卡片左上角提供关闭、最小化、最大化按钮，右上角按钮和双击可直接切换全屏。

### Spotlight Files

`qs -c clavis ipc call spotlight openMode files` and
`qs -c clavis ipc call spotlight files` open Files and focus its input. Repeated
calls keep it open. Existing Apps/Wallpapers/Clipboard and web methods remain.

Ctrl+1/2/3/4 selects Apps/Wallpapers/Clipboard/Files. Tab expands the four-mode rail; subsequent Tab/Shift+Tab cycle it, and Enter selects a mode. In Files, Enter opens the selected file or enters
the folder; Ctrl+Enter requests selection in a file manager. Holding Ctrl immediately shows
the selected result's containing path; the right-click menu also exposes Open
and Show in file manager. Clipboard retains Shift+Enter.

Search uses the public `key file` capability through `${CLAVIS_KEY:-key}`. Install
fd plus key-cli supporting `file.status`/`file.search`; there is no invented
minimum release version. HOME is the default root, with fd's normal ignore/hidden
rules and no directory-symlink traversal. Queries are literal and case-insensitive;
slash-containing queries match paths. A 180 ms debounce feeds at most 50 results
from 400 candidates with a 3-second search budget. Limited searches are identified
in the UI. Empty input does not enumerate HOME.

Open uses the system default association and blocks launching executable content.
Reveal first requests FileManager1 selection, then falls back to opening the
parent directory without promising selection. Failures keep Spotlight open.

Settings → keyboard shortcuts includes **Spotlight: Find files** as an unbound
action. Bind/save it using the existing editor if desired; no default global
shortcut is added and existing user bindings are preserved.

### Spotlight Search (default)

`spotlight open`, the opening branch of `spotlight toggle`, `spotlight search`,
and `spotlight openMode search` enter Search. `open` and `search` are idempotent:
when Search is visible they focus it. A new session starts with an empty input
and no results panel. To open the application Grid/List directly, use
`qs -c clavis ipc call spotlight openMode apps`.

Ctrl+0 or the search icon returns to Search and preserves ordinary search text. Tool parameters and command drafts are cleared.
Ctrl+1/2/3/4 still opens Apps/Wallpapers/Clipboard/Files; Tab expands and cycles
the same four satellite buttons. Ctrl+K enters Web, and Esc from Web restores the previous
mode, including Search. The existing modal/rail/clear-input/close Esc priority and
IME composition handling remain. No new global key is installed.

Nonempty input searches the already loaded Apps directory, static Settings and
Actions catalogs, and `WallpaperService.wallpapers`, in that order. Groups display
with one responsive row of app icons/names and wallpaper thumbnails/names, and
up to two Settings/Actions entries each, with no category expansion. Up/Down moves between rows; Left/Right moves within
a tile row. There is no separate input/result navigation state; Esc follows the
shared modal/rail/clear-input/close behavior.
The last two rows
are explicit **Search files for…** and **Search the web for…** actions. Files is
queried only after entering its dedicated mode; Web opens only after activation.
Clipboard content, live web results and file results are not aggregated.

Search does not refresh or scan wallpaper folders. Files added externally become
visible after the existing startup, directory-change or dedicated wallpaper-page
refresh. There is no file index service or “enable indexing” setting.

Settings results release Spotlight before opening/focusing the existing Settings
window. Stable page/subpage IDs and section anchors support scroll and brief
highlight after loading and layout. Later requests replace earlier ones; leaving
the page or closing the window cancels pending navigation. A missing or hidden
section reports that it is unavailable.

Actions reuse fixed Clavis shortcuts and business functions. Power opens the
existing confirmation menu. Parameter templates, raw compositor commands,
queries, duplicate navigation aliases and the reserved no-op `cancelRecord` are
not exposed as executable Search results. No shell expression is evaluated.
See [search catalog maintenance](architecture/spotlight-search.md).

### Spotlight commands and temporary tools

`spotlight commands` and `spotlight openMode commands` are idempotent public
entries. Explicit IPC mode navigation clears temporary tools/overrides through
the same session controller as local navigation; it does not change user keys.

All 16 command-palette actions are also callable as
`qs -c clavis ipc call spotlight command NAME`, using the slash name without `/`
(e.g. `calc`, `fx`, `time`, `light`, `dark`, `find-settings`, `actions`, `map`).
This returns `OK` or `INVALID_COMMAND`; scoped layout/order overrides are rejected.
Tools open a fresh session; theme, Settings and map actions also work while
Spotlight is closed. Existing dedicated IPC entry points remain compatible.
Every palette action has a permanent row in Settings → Shortcuts, reusing existing
rows where available. The new rows start unassigned and add no default bindings.

Type `>` to enter the command palette immediately (`>calc` filters Calculator).
Slash drafts stay in their base mode. Enter executes an exact command; slash input has no suggestion list. Unknown commands
never fall through to content activation. `\/etc` and `\>hello` are literal
searches. Tool parameters are not reparsed as top-level commands.

| Command | Behavior |
| --- | --- |
| `/default`, `/apps`, `/wallpaper` (`/wallpapers`), `/clipboard`, `/files`, `/commands` | Base mode navigation |
| `/search` (`/web`) | Web tool, not default Search |
| `/calc`, `/fx` (`/currency`), `/time` (`/tz`) | Calculator, currency, time zone |
| `/find-settings`, `/actions` | Settings-only / IPC action-only search |
| `/light`, `/dark`, `/settings`, `/map` | Apply theme, open Settings, open standalone location map |
| `/list`, `/grid`, `/smart`, `/most-used`, `/recent` (`/recently-used`), `/name` | Apps-only temporary presentation |
| `/compact`, `/detail` (`/details`) | Clipboard-only temporary presentation |

Tool commands accept trailing input, e.g. `/calc (120 + 80) * 0.85` or
`/fx 100 USD to CNY`. The first Enter only enters the tool. A later Enter copies
its valid result (Web submits); it does not close calculation tools.

Empty-input Backspace removes the current tool, then the most recent presentation
override. It requires a fresh press in the search input, no selection/preedit or
modal dialog. Holding Backspace cannot unwind the stack. Theme changes
and other completed actions are never undone. Closing clears temporary state.

Tab and Shift+Tab always navigate the mode rail; they never complete input.
Ctrl editing shortcuts and Files Ctrl+Enter retain their previous behavior.

Currency opens with four independent slots: amount, currency, amount, currency,
separated by ≈. Left/Right select adjacent slots without wrapping. Clicking a
slot activates it; typing replaces the selected value. The last edited amount
is the driver; currency changes preserve that side. `/fx 100 USD to CNY` seeds
the slots, while `/fx` defaults to 1 USD → EUR.

Only active currency slots show locally filtered candidates. Up/Down select and
Enter confirms without copying. Tab/Shift+Tab retain mode-rail navigation.
Ctrl+C copies the current slot (an explicit text selection takes priority).
Ctrl+A highlights the whole four-slot expression; Ctrl+C then copies that expression.
With candidates closed, Enter copies the derived amount without its currency.
A fresh Backspace in an empty amount slot leaves Currency.

Only the confirmed pair requests `key tool currency --expression="1 USD to EUR"`.
Amount edits and direction changes reuse that rate locally, using decimal-string
arithmetic. Reverse conversion rounds half-even to 24 decimal places. Pending or
invalid dependent amounts cannot be copied. Existing generation checks reject
old pair results, and current driver state determines which amount is derived.

Time opens a searchable list of templates from local time to every available
time zone. “Change source” chooses a different source zone. Select a template
with Enter, then type a time (`0930`, `9`, `09:30`, or a date and time). Clearing
the input and pressing Backspace again returns to template selection. Another
fresh Backspace on the empty selector leaves the tool. DST ambiguity and invalid
times still use the existing explicit result/error flow.

### Sidebar weather and drawer

`qs -c clavis ipc call sidebar open weather` and `sidebar open drawer` select the
respective dashboard tab and open its sidebar, following the configured edge.
Open/close remain explicit IPC operations. Spotlight Actions and permanent
unassigned shortcut rows instead use `sidebar toggle weather` / `sidebar toggle drawer`.
Toggling the already open target tab closes it; a closed sidebar or a different
active tab opens the requested tab. No default key is installed.
