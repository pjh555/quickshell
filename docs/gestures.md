# 触屏与全屏手势

## 触摸设备检测

`PlatformService` 启动时运行一次 `udevadm info --export-db`，查找
`ID_INPUT_TOUCHSCREEN=1`。检测到触摸屏后：

- Launchpad 自动使用更大的触控布局（更大图标、页码点和行距）。
- 在支持 `wlr-layer-shell` 的会话中启用全屏边缘手势层。

可用环境变量覆盖：

```bash
CLAVIS_TOUCH=1              # 强制启用触控布局/手势
CLAVIS_TOUCH_GESTURES=0     # 禁用全屏边缘手势
```

## 全屏边缘手势

实现位于 `Modules/Gestures/`。每个输出创建一个全屏透明 `PanelWindow`，只有四条屏幕边缘
属于输入区域（`mask: Region`），屏幕中部对下层应用完全透明且可点击。手势处理器只接受
`PointerDevice.TouchScreen`，不会影响鼠标。

| 手势 | 短距离 | 长距离/快速滑动 |
| --- | --- | --- |
| 左边缘向右滑 | 上一个应用（Niri 左列） | 上一个工作区 |
| 右边缘向左滑 | 下一个应用（Niri 右列） | 下一个工作区 |
| 底边向上滑 | 打开 Launchpad（Home） | Sway：打开可拖动窗口布局；Niri：打开 Niri Overview（Recents） |
| 顶边向下滑 | 快捷设置 | 通知侧栏 |

拖动过程中会在对应边缘显示 Material 图标和动作提示；提示不参与触控命中。

动作通过 `TouchGestureService` 发送给 `AppShell`，不经过自我 IPC：

```bash
qs -c clavis ipc call gesture actions
qs -c clavis ipc call gesture trigger home
qs -c clavis ipc call gesture triggerOn quick-settings DP-1
```

`gesture actions` 返回可用的稳定动作名。`trigger` 使用当前输出，`triggerOn` 指定输出。
`touch-keyboard` 可绑定为边缘手势动作，用于打开底部触屏键盘。

## Launchpad 内手势

- 单指左右拖动翻页，1:1 跟手；使用 GNOME Shell `swipeTracker.js` 的距离/速度阈值吸附。
- 顶部边缘向下拖 72 px 关闭。
- 长按 550 ms 进入编辑；编辑模式下拖到屏幕左右边缘 650 ms 自动翻页。
- 文件夹、搜索结果使用原生触摸滚动；触控目标最小 40 px。
- 文件夹面板获得键盘焦点后，方向键选择、Enter 打开、Delete 移出文件夹、Esc 关闭。

## 稳定性

- 手势动作通过 `Qt.callLater()` 延迟到当前触摸事件结束后执行。这样在触摸释放期间不会
  立即映射新窗口或隐藏手势层，避免 Qt 指针处理器持有失效的触摸点。
- Launchpad 的层壳窗口在输出生命周期内保持映射；关闭时只清空输入区域并隐藏内容。
  这规避了部分 ARM64 Qt 6.10/Wayland 环境在反复 map/unmap 全屏层壳时的 Qt GUI 崩溃。
- Launchpad 打开时手势层仍留在下方并禁用边缘手势，Overlay 层上的 Launchpad 优先接收
  输入；关闭后边缘手势立即恢复。

## 限制

GNOME/Mutter 不支持 `wlr-layer-shell`，普通 Wayland 应用无法创建覆盖全屏且只拦截边缘的
输入层。GNOME 会话下只能使用 Launchpad 内部手势；三/四指系统手势仍由 GNOME Shell 处理。
需要完整全屏手势时使用 Niri 会话。
