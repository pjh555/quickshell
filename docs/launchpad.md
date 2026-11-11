# Launchpad

Clavis 的 Launchpad 参考 macOS Launchpad（macOS 26 起 Apple 已将其并入 Spotlight
Applications 界面）的经典行为，而不是复制 App Store 或 Screen Time。

## 功能对照

| 能力 | Clavis | 说明 |
| --- | --- | --- |
| 全屏应用网格 | 是 | 模糊/半透明壁纸背景，8×5 自适应网格 |
| 程序坞入口 | 是 | 固定显示在 Dock 最左侧的彩色九宫格图标；单击开关 Launchpad，不可拖动或移除 |
| 打开/关闭 | 是 | `F4`、IPC、Dock 图标、点击空白、Esc、顶部下滑、底部上滑 |
| 键入即搜索 | 是 | 打开即聚焦；结果跨文件夹，按相关度和使用频率排序 |
| 翻页 | 是 | 单指/滚轮/PageUp/PageDown/页码点；1:1 跟随与速度吸附 |
| 页码点 | 是 | 当前页拉长，点击跳转 |
| 键盘导航 | 是 | 方向键、Enter、Esc、Ctrl+左右、PageUp/PageDown |
| 拖动排序 | 是 | 编辑模式下同页拖动 |
| 拖到其他页 | 是 | 拖到左右边缘停留 650 ms 自动翻页 |
| 创建文件夹 | 是 | 应用拖到应用上 |
| 加入文件夹 | 是 | 应用拖到文件夹上 |
| 文件夹内排序 | 是 | 文件夹面板内拖动 |
| 移出文件夹 | 是 | 拖到面板外或右键移除；空文件夹自动折叠 |
| 重命名文件夹 | 是 | 点击文件夹名编辑，Enter/失焦保存 |
| 抖动编辑模式 | 是 | 长按 550 ms、F2、右键菜单 |
| 从 Launchpad 移除 | 是 | 不支持安全卸载的应用映射为隐藏，不删除应用；可恢复隐藏项或重置布局 |
| 删除应用 | 部分支持 | Flatpak 执行真实卸载；用户目录 AppImage 及其桌面文件移入回收站；其他原生包只从 Launchpad 移除 |
| 添加到 Dock | 是 | 应用右键“Add to Dock” |
| 隐藏项恢复 | 是 | 背景菜单“恢复已隐藏的应用”；搜索仍可启动隐藏项 |
| App Store / 游戏文件夹 | 否 | 与 Linux 应用来源无关 |
| 布局持久化 | 是 | `~/.config/clavis/launchpad.json` |

## 布局存储

```json
{
  "schemaVersion": 1,
  "hidden": ["org.example.Hidden"],
  "items": [
    {"type": "app", "id": "org.example.Editor"},
    {
      "type": "folder",
      "id": "folder-...",
      "name": "Media",
      "items": [
        {"type": "app", "id": "org.example.Player"},
        {"type": "app", "id": "org.example.Gallery"}
      ]
    }
  ]
}
```

应用安装/卸载时只做合并：已存在项保持顺序，新应用追加到末尾，消失的应用被移除，
隐藏列表过滤不存在的 ID。布局加载与 `ApplicationService` 的异步应用列表通过
pending 状态解耦，避免启动时用空列表覆盖用户排列。

## 手势与触屏

- 翻页阈值和吸附动画移植自 GNOME Shell `js/ui/swipeTracker.js`：
  取消阈值 0.5 页、速度阈值 0.001 页/ms、吸附时长 100–400 ms。
- 顶部边缘下滑或底部边缘上滑 72 px 关闭，对应 GNOME 触屏 Shell 的边缘优先交互；
  不需要键盘即可退出全屏 Launchpad。
- 图标长按进入编辑模式；拖动中的边缘自动翻页；文件夹网格使用原生 `Flickable`。
- 页码点 40 px、文件夹 Done 44 px、删除按钮 40 px；搜索栏自动聚焦，所有主操作都有
  键盘和触摸两条路径。
- GNOME 不向普通应用暴露全局触摸板手势，因此三/四指系统手势仍由 GNOME Shell 处理；
  Launchpad 只接管自己窗口内的事件。

## 代码结构

| 文件 | 职责 |
| --- | --- |
| `Services/LaunchpadService.qml` | 可见状态、搜索、分页、持久化、布局操作 |
| `Services/ApplicationService.qml` | 应用启动、Flatpak/AppImage 卸载能力探测与执行 |
| `Common/functions/LaunchpadLayout.js` | 纯布局/文件夹/合并逻辑 |
| `Common/functions/SwipeTracker.js` | GNOME 风格手势判定 |
| `Modules/Launchpad/LaunchpadSurface.qml` | 背景、搜索栏、翻页、拖放、菜单 |
| `Modules/Launchpad/LaunchpadTile.qml` | 应用/文件夹图标、抖动、长按、拖动 |
| `Modules/Launchpad/LaunchpadFolderOverlay.qml` | 文件夹面板、重命名与键盘选择 |
| `Modules/Gestures/` | Niri/层壳会话的全屏边缘手势 |
| `Modules/Launchpad/LaunchpadPanelWindow.qml` | 层壳合成器（Niri）窗口 |
| `Modules/Launchpad/LaunchpadFloatingWindow.qml` | GNOME/普通 Wayland 全屏 toplevel |

多显示器下只有当前目标屏幕的 surface 会更新分页和网格容量，避免不同分辨率显示器在
Launchpad 打开时互相覆盖布局参数；窄屏/竖屏会自动提高触摸目标尺寸并减少网格密度。
