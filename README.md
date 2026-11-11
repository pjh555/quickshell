
> [!NOTE]
> This project is under active development.

A desktop shell for [niri](https://github.com/YaLTeR/niri), built with [Quickshell](https://quickshell.org/), QML, Qt 6 and native C++ modules. The Qt/QML modules also build and run on Ubuntu; GNOME sessions currently expose the full-screen Launchpad through a normal toplevel window because Mutter does not implement `wlr-layer-shell`. See [Ubuntu 适配](docs/ubuntu.md). On Ubuntu ARM64, `./install-ubuntu.sh` builds the
missing Ubuntu-only dependencies (libcava and M3Shapes) and installs a launchable shell;
the generic `install.sh` entry point dispatches to it on Debian/Ubuntu.

<table>
  <tr>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-20-21.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-20-21.png" alt="Clavis Shell screenshot 1" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-23-30.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-23-30.png" alt="Clavis Shell screenshot 2" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-32-08.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-32-08.png" alt="Clavis Shell screenshot 3" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-33-40.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-33-40.png" alt="Clavis Shell screenshot 4" width="100%" /></a></td>
  </tr>
  <tr>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-43-18.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-43-18.png" alt="Clavis Shell screenshot 5" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2021-42-49.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2021-42-49.png" alt="Clavis Shell screenshot 6" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_15-36-29_194021.gif"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_15-36-29_194021.gif" alt="Clavis Shell animation 1" width="100%" /></a></td>
    <td width="25%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_22-20-48_544529.gif"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_22-20-48_544529.gif" alt="Clavis Shell animation 2" width="100%" /></a></td>
  </tr>
</table>

## Launchpad

The full-screen application grid lives in `Modules/Launchpad/`. It supports search, multiple pages,
page dots, keyboard navigation, drag reordering across pages, folders, rename, long-press edit mode,
and a persisted layout in `~/.config/clavis/launchpad.json`. Open it with `F4` or
`qs -c clavis ipc call launchpad toggle`. See [Launchpad 设计](docs/launchpad.md) for the
feature matrix and storage format, and [触屏与全屏手势](docs/gestures.md) for edge gestures
and touchscreen behaviour.

## Acknowledgements

Clavis takes inspiration from and integrates ideas or components from projects including:

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- [Zen Browser](https://github.com/zen-browser/desktop) — palette algorithms and editor; see [source and license mapping](licenses/README.md).
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)
- [qml-niri](https://github.com/imiric/qml-niri)
- [Breezy Weather](https://github.com/breezy-weather/breezy-weather)
- [Animated Weather Cards](https://codepen.io/ste-vg/pen/GqaZbo) by Steve Gardner — the current-weather animation at the top of the sidebar weather view is a Qt/QML recreation of this web project. The original is licensed under MIT; see the [full license and copyright notice](licenses/AnimatedWeatherCards-MIT.txt).
- [m3shapes](https://github.com/soramanew/m3shapes)

Third-party license notices are kept in [`licenses/`](licenses/).
# License

See [LICENSE](LICENSE).
