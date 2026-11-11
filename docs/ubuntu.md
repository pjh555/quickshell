# Ubuntu 适配

当前验证环境：

| 项目 | 值 |
| --- | --- |
| 发行版 | Ubuntu 26.04 LTS (resolute), aarch64 |
| 桌面 | GNOME Shell 50.1 / Wayland，另提供 Niri 会话 |
| Qt | 6.10.2 |
| Quickshell | 0.3.2 |
| 构建 | CMake 4.2 + Ninja |

Clavis 原生模块和 QML 外壳在 Ubuntu 上可以完整编译。完整桌面外壳（Bar、Dock、桌面卡片、锁屏、
侧栏）依赖 `wlr-layer-shell`，GNOME/Mutter 不实现该协议；GNOME 会话下只有不依赖层壳的
Launchpad 使用普通全屏窗口显示。需要完整外壳时请登录 Niri 会话。

## 安装依赖

Ubuntu 仓库中的包名与 Arch 不同，以下为可复现的构建依赖：

```bash
sudo apt install \
  build-essential cmake ninja-build pkg-config python3 \
  qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-declarative-dev-tools \
  qt6-wayland-dev qt6-tools-dev qt6-tools-dev-tools qt6-shadertools-dev qt6-svg-dev \
  qtkeychain-qt6-dev libpipewire-0.3-dev libudev-dev libxkbcommon-dev \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-window qml6-module-qtquick-effects \
  qml6-module-qt5compat-graphicaleffects qml6-module-qtlocation \
  qml6-module-qtpositioning
```

`libcava` 需要带 pkg-config 的共享库版本。发行版的 `cava` 命令不提供该接口，可自行构建：

```bash
git clone https://github.com/karlstav/cava
cd cava
./autogen.sh
./configure --prefix=/usr/local
make
sudo make install
sudo ldconfig
```

运行时：

```bash
sudo apt install quickshell niri jq ffmpeg wl-clipboard brightnessctl \
  xdg-utils libnotify-bin gsettings-desktop-schemas \
  fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 \
  fcitx5-frontend-qt5 fcitx5-frontend-qt6 \
  ibus ibus-gtk3 ibus-gtk4 ibus-libpinyin ibus-wayland im-config wtype wf-recorder
```

可选：`flatpak` 用于在 Launchpad 内删除 Flatpak 应用；没有 `flatpak` 时只提供
“从启动台移除”。

可选能力：

- `key-cli` 未安装时，录制、剪贴板历史、系统指标和键盘锁指示不可用；Launchpad、
  应用启动、布局保存不受影响。
- Material Symbols Rounded/Outlined 已随仓库放入 `assets/fonts/material-symbols/`
  （Apache-2.0），由 `FontLoader` 加载，不再依赖发行版字体包。
- GNOME 未设置 Clavis 壁纸时，Launchpad 会读取
  `org.gnome.desktop.background picture-uri` 作为背景，不写入 GSettings。
- Niri 会话默认使用 fcitx5 的 Wayland 输入法处理物理键盘中文；只有缺少 fcitx5 时
  才回退到 IBus Wayland 桥接。顶栏右侧的键盘按钮会打开底部全宽触屏键盘；中文模式
  在键盘顶部显示 libpinyin 候选条，通过 `wtype` 发送 UTF-8 字符。
  安装器会安装 fcitx5/中文插件并执行 `im-config -n fcitx5`。
- 全屏触摸屏可设置 `CLAVIS_TOUCH=1` 强制启用更大的图标间距、触摸目标和边缘退出手势；
  小尺寸/竖屏会自动进入同一布局模式。

## 一键源码安装（ARM64）

仓库根目录的 `install-ubuntu.sh` 按当前机器架构安装，而不是复用 Arch 发布包：

```bash
./install-ubuntu.sh --dry-run          # 先查看将执行的命令
./install-ubuntu.sh                    # 用户目录安装到 ~/.local
./install-ubuntu.sh --system           # 安装到 /usr/local
./install-ubuntu.sh --enable-service   # 写入并启用 systemd 用户服务
```

脚本会：

- 检查 Ubuntu/Debian 与 `aarch64`（也接受 `x86_64`）。
- 通过 apt 安装 Qt 6、Quickshell、Niri 和构建依赖。
- 若系统没有 `libcava`，从 Cava 1.0.0 源码构建经过 SHA-256 校验的共享库。
- 若系统没有 `M3Shapes`，从固定提交的源码构建 QML 模块。
- 使用 Qt 的多架构 QML 路径（`lib/aarch64-linux-gnu/qt6/qml`）。
- 安装 `clavis-shell` wrapper、Launchpad desktop entry、可选 systemd 用户服务。
- 创建 `~/.config/quickshell/clavis` 符号链接。

从 `curl .../install.sh | bash` 入口在 Ubuntu 上也会转到这个安装器；Arch 才走原有的 Arch release 流程。

## 构建与启动

```bash
git clone https://github.com/StatIndet/quickshell.git
cd quickshell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build

mkdir -p ~/.config/quickshell
ln -sfn "$PWD" ~/.config/quickshell/clavis

QML_IMPORT_PATH="$PWD/build/qml" qs -c clavis
```

QML 修改会热重载；修改 `core/` 或 CMake 后重新执行 `cmake --build build` 并重启 Shell。

## GNOME 会话

GNOME 下启动同一个 Shell 即可使用 Launchpad：

```bash
QML_IMPORT_PATH="$PWD/build/qml" qs -c clavis -n
```

打开和关闭：

```bash
qs -c clavis ipc call launchpad toggle
qs -c clavis ipc call launchpad open
qs -c clavis ipc call launchpad close
```

在“设置 → 键盘 → 自定义快捷键”中把 `F4` 或 `Super+A` 绑定到
`qs -c clavis ipc call launchpad toggle` 即可获得类似 macOS 的启动器入口。

Niri 会话中默认绑定为 `F4`（首次生成 `binds.kdl` 时写入，已有配置不会被覆盖），
完整外壳、锁屏、Dock 和侧栏同时可用。

## 已知差异

- GNOME 不支持层壳，Bar/Dock/锁屏等窗口不会显示；这是合成器能力限制，不是构建失败。
- GNOME 下没有全局手势注入接口。三指/四指系统手势仍由 GNOME Shell 处理；
  Launchpad 内部的翻页、长按编辑、边缘下滑关闭等手势由 QML 自己处理。Niri 会话可用
  `Modules/Gestures/` 的左右/底/顶边缘手势层。
- `key-cli` 的 Arch 授权包不适用于 Ubuntu；需要相应功能时使用其独立安装工具。

## Launchpad 触屏手势

检测到触摸屏（udev `ID_INPUT_TOUCHSCREEN=1`）后，Launchpad 自动切换更大触控布局；
Niri/层壳会话还会加载全屏边缘手势层，详见 [触屏与全屏手势](gestures.md)。

Launchpad 不再依赖 hover 才能操作，触屏和鼠标共用同一套指针处理：

- 单指左右拖动翻页，内容 1:1 跟随手指；松手后按 GNOME Shell `swipeTracker.js`
  的 0.5 页距离 / 0.001 页每毫秒速度阈值吸附，动画时长限制在 100–400 ms。
- 从屏幕顶部边缘向下拖动超过 72 px 关闭 Launchpad。
- 长按图标约 550 ms 进入抖动编辑模式；编辑模式下拖动图标可排序，拖到另一页边缘停留
  650 ms 自动翻页，拖到另一个应用上创建文件夹，拖到文件夹上加入文件夹。
- 文件夹内拖到面板外移出文件夹；拖空文件夹后文件夹自动折叠。
- 触控目标不小于 40 px（页码点、删除按钮、Done），搜索框始终自动获得焦点，
  点击空白处等同 Esc 的上一级返回。
- 搜索、翻页、文件夹网格都使用 `Flickable`/`GridView` 原生触摸滚动，不劫持系统手势。
