pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string desktop: String(Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
    readonly property string sessionDesktop: String(Quickshell.env("XDG_SESSION_DESKTOP") || "").toLowerCase()
    readonly property string sessionType: String(Quickshell.env("XDG_SESSION_TYPE") || "").toLowerCase()
    readonly property bool hasNiriSocket: String(Quickshell.env("NIRI_SOCKET") || "") !== ""
    readonly property bool isNiri: root.hasNiriSocket || root.desktop.split(":").indexOf("niri") >= 0 || root.sessionDesktop
                                   === "niri"
    readonly property bool isSway: String(Quickshell.env("SWAYSOCK") || "") !== "" || root.desktop.split(":").indexOf(
                                       "sway") >= 0 || root.sessionDesktop === "sway"
    readonly property bool isGnome: root.desktop.split(":").indexOf("gnome") >= 0 || root.sessionDesktop
                                    === "gnome"
    readonly property bool isKde: root.desktop.indexOf("kde") >= 0 || root.desktop.indexOf("plasma") >= 0
    readonly property bool isWayland: root.sessionType === "wayland"
    readonly property bool softwareRendering: String(Quickshell.env("QT_QUICK_BACKEND") || "").toLowerCase()
                                              === "software" || String(Quickshell.env("QSG_RHI_BACKEND")
                                                                       || "").toLowerCase() === "software"
    readonly property bool isLayerShellCompositor: {
        const tokens = (root.desktop + ":" + root.sessionDesktop).split(":");
        return tokens.some(token => ["niri", "hyprland", "sway", "river", "wayfire", "labwc", "kde", "plasma",
                                     "cosmic", "ukui"].indexOf(token) >= 0);
    }
    // Clavis windows use wlr-layer-shell. GNOME/Mutter does not implement it,
    // so overlays that must remain visible fall back to ordinary toplevels.
    readonly property bool layerShellAvailable: root.isLayerShellCompositor
    readonly property bool floatingOverlays: !root.layerShellAvailable
    property string machine: ""
    readonly property bool isArm64: root.machine === "aarch64" || root.machine === "arm64"
    readonly property bool isX86_64: root.machine === "x86_64" || root.machine === "amd64"
    readonly property bool isUbuntuArm64: root.isUbuntu && root.isArm64
    property bool hasTouchscreen: false
    readonly property bool touchOptimized: String(Quickshell.env("CLAVIS_TOUCH") || "") === "1"
                                           || root.hasTouchscreen

    readonly property bool touchGesturesEnabled: root.touchOptimized && String(Quickshell.env(
                                                                                   "CLAVIS_TOUCH_GESTURES")
                                                                               || "1") !== "0"
    readonly property string compositorName: root.isNiri ? "niri" : root.isGnome ? "gnome" : root.isKde
                                                                                   ? "kde" : "other"

    property string distroId: ""
    property string distroName: ""
    property string distroLike: ""
    property string desktopWallpaper: ""
    readonly property bool isUbuntu: root.distroId === "ubuntu" || root.distroLike.split(" ").indexOf(
                                         "ubuntu") >= 0
    readonly property bool isDebian: root.isUbuntu || root.distroId === "debian" || root.distroLike.split(
                                         " ").indexOf("debian") >= 0
    readonly property bool isArch: root.distroId === "arch" || root.distroLike.split(" ").indexOf("arch") >= 0
    readonly property string packageManager: root.isArch ? "pacman" : root.isDebian ? "apt" : root.distroId
                                                                                      === "fedora" ? "dnf" :
                                                                                                     ""
    readonly property var logoutCommand: root.isNiri ? ["niri", "msg", "action", "quit",
                                                        "--skip-confirmation"] : root.isGnome
                                                       ? ["gnome-session-quit", "--logout", "--no-prompt"] :
                                                         ["loginctl", "terminate-session", String(
                                                              Quickshell.env("XDG_SESSION_ID") || "")]

    function requestLogout() {
        Quickshell.execDetached(root.logoutCommand);
    }

    function desktopWallpaperFrom(value) {
        let path = String(value || "").trim();
        if (path.startsWith("'") && path.endsWith("'"))
            path = path.substring(1, path.length - 1);
        if (path.startsWith("file://"))
            path = path.substring("file://".length);
        return path.startsWith("/") && !path.endsWith(".xml") ? path : "";
    }

    function overlayModeLabel() {
        return root.layerShellAvailable ? "layer-shell" : "floating";
    }

    FileView {
        path: "/etc/os-release"
        watchChanges: false
        onLoaded: {
            for (const rawLine of String(text || "").split("\n")) {
                const line = rawLine.trim();
                const separator = line.indexOf("=");
                if (separator <= 0)
                continue;
                const key = line.substring(0, separator);
                let value = line.substring(separator + 1).trim();
                if (value.length >= 2 && (value.startsWith("\"") && value.endsWith("\"") || value.startsWith(
                                              "'") && value.endsWith("'")))
                value = value.substring(1, value.length - 1);
                if (key === "ID")
                root.distroId = value.toLowerCase();
                else if (key === "NAME")
                root.distroName = value;
                else if (key === "ID_LIKE")
                root.distroLike = value.toLowerCase();
            }
        }
    }

    Process {
        command: ["uname", "-m"]
        running: true

        stdout: StdioCollector {
            id: machineOutput
        }
        onExited: exitCode => {
            if (exitCode === 0)
            root.machine = String(machineOutput.text || "").trim().toLowerCase();
        }
    }

    // udev marks both internal and USB touchscreens. This does not require
    // libinput access and lets the shell enlarge touch targets automatically.
    Process {
        command: ["udevadm", "info", "--export-db"]
        running: true

        stdout: StdioCollector {
            id: udevOutput
        }
        onExited: exitCode => {
            if (exitCode === 0)
            root.hasTouchscreen = String(udevOutput.text || "").indexOf("ID_INPUT_TOUCHSCREEN=1") >= 0;
        }
    }

    // Use the desktop's own wallpaper when Clavis has none configured. This
    // keeps the GNOME fallback visually consistent without writing settings.
    Process {
        command: ["gsettings", "get", "org.gnome.desktop.background", "picture-uri"]
        running: root.isGnome

        stdout: StdioCollector {
            id: wallpaperOutput
        }
        onExited: exitCode => {
            if (exitCode === 0)
            root.desktopWallpaper = root.desktopWallpaperFrom(wallpaperOutput.text);
        }
    }
}
