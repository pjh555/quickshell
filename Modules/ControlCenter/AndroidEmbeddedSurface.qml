//! Host-side nested compositor for the embedded Android Settings task.
//!
//! droidloom-wayland exports the selected task over a private control socket.
//! droidloom-embedded-view listens on that socket, then connects to this
//! compositor as an ordinary Wayland client and attaches the exported frames.
//! The resulting shell surfaces are rendered in-place here; no desktop
//! toplevel or shortcut is created.

pragma ComponentBehavior: Bound

import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: true
    property bool stopping: false
    // A fixed Wayland socket name makes QtWaylandCompositor abort the whole
    // shell if a previous page/crash left the socket behind. Each page owns a
    // private socket; the control socket remains the single fixed rendezvous
    // point with droidloom-wayland.
    property string socketName: "droidloom-embedded-settings-" + Math.floor(Math.random() * 1000000000)
    property string controlSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000")
                                   + "/droidloom-embedded-settings.sock"
    property string executable: Quickshell.env("DROIDLOOM_EMBED_VIEW") || "/usr/bin/droidloom-embedded-view"
    property bool ready: false
    property bool started: false
    property var pendingSurfaceRemovals: []
    readonly property int surfaceCount: surfaces.count

    signal settingsReady
    signal processExited(int code)

    function queueSurfaceRemoval(surface) {
        pendingSurfaceRemovals.push(surface);
        surfaceRemovalTimer.restart();
    }

    function resizeSurfaces() {
        const width = Math.max(1, Math.round(root.width));
        const height = Math.max(1, Math.round(root.height));
        if (width <= 1 || height <= 1)
            return;
        for (let index = 0; index < surfaces.count; ++index) {
            const surface = surfaces.get(index);
            if (surface && surface.toplevel)
                surface.toplevel.sendConfigure(Qt.size(width, height), []);
        }
    }

    function removeSurface(surface) {
        for (let index = 0; index < surfaces.count; ++index) {
            if (surfaces.get(index).shellSurface === surface) {
                surfaces.remove(index);
                break;
            }
        }
    }

    ListModel {
        id: surfaces
    }

    Timer {
        id: surfaceRemovalTimer
        interval: 0
        repeat: false
        onTriggered: {
            const pending = root.pendingSurfaceRemovals;
            root.pendingSurfaceRemovals = [];
            for (let index = 0; index < pending.length; ++index)
            root.removeSurface(pending[index]);
        }
    }

    WaylandCompositor {
        id: compositor
        socketName: root.socketName

        XdgShell {
            onToplevelCreated: (toplevel, xdgSurface) => {
                while (surfaces.count > 0)
                surfaces.remove(0);
                surfaces.append({
                                    shellSurface: xdgSurface,
                                    toplevel: toplevel,
                                    title: toplevel.title
                                });
                root.resizeSurfaces();
            }
        }
    }

    Repeater {
        model: surfaces

        delegate: Item {
            required property var shellSurface
            required property string title

            width: root.width
            height: root.height

            ShellSurfaceItem {
                id: shellItem
                anchors.fill: parent
                shellSurface: parent.shellSurface
                autoCreatePopupItems: true
                touchEventsEnabled: true
                focusOnClick: false

                onSurfaceDestroyed: {
                    // QtWayland emits this while the client's wl_surface is
                    // being destroyed. Mutating the ListModel synchronously
                    // invalidates Qt's own model iterators and crashes the
                    // shell; defer the row removal until dispatch returns.
                    root.queueSurfaceRemoval(shellItem.shellSurface);
                }
            }
        }
    }

    Timer {
        id: startTimer
        interval: 250
        repeat: false
        onTriggered: root.started = root.active
    }

    Timer {
        id: restartTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.active && !root.stopping)
            root.started = true;
        }
    }

    Process {
        id: viewProcess

        command: ["/usr/bin/env", "WAYLAND_DISPLAY=" + root.socketName, "DROIDLOOM_EMBED_SETTINGS_SOCKET="
            + root.controlSocket, "DROIDLOOM_EMBED_WIDTH=" + Math.max(1, Math.round(root.width)),
            "DROIDLOOM_EMBED_HEIGHT=" + Math.max(1, Math.round(root.height)), "QT_QPA_PLATFORM=wayland",
            root.executable]
        running: root.active && root.started && !root.stopping

        stdout: SplitParser {
            onRead: line => {
                if (String(line).trim() !== "ready")
                return;
                root.ready = true;
                root.settingsReady();
            }
        }

        onExited: code => {
            root.ready = false;
            root.started = false;
            if (root.stopping)
            return;
            root.processExited(code);
            restartTimer.restart();
        }
    }

    onWidthChanged: resizeSurfaces()
    onHeightChanged: resizeSurfaces()

    onActiveChanged: {
        ready = false;
        started = false;
        if (active)
        startTimer.restart();
    }

    Component.onCompleted: startTimer.start()

    Component.onDestruction: {
        stopping = true;
        active = false;
        if (viewProcess.running)
        viewProcess.signal(15);
        viewProcess.running = false;
    }
}
