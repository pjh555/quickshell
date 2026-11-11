pragma Singleton

import QtQuick
import Quickshell
import Clavis.Niri
import qs.Services

// A recent-window source for the macOS-style Stage Manager strip. Niri owns
// the tiling layout; this service only exposes background windows so the left
// thumbnail rail can focus and restore them without fighting the compositor.
Singleton {
    id: root

    readonly property bool available: PlatformService.isNiri && Niri.connected
    property var windows: []
    property bool visible: false
    property int revision: 0
    property string consumer: ""

    function updateTargets() {
        if (!root.visible) {
            if (root.consumer !== "") {
                WindowPreviewService.release(root.consumer);
                root.consumer = "";
            }
            return;
        }
        if (!WindowPreviewService.supported)
            return;
        if (root.consumer === "")
            root.consumer = WindowPreviewService.createConsumer();
        WindowPreviewService.setTargets(root.consumer, root.windows.map(window => String(window.id)));
    }

    function refresh() {
        root.windows = root.available ? Niri.searchWindows("").filter(window => !window.isFocused) : [];
        root.revision++;
        if (root.visible)
            Qt.callLater(root.updateTargets);
    }

    function open() {
        if (!root.available || root.visible)
            return false;
        root.refresh();
        root.visible = true;
        Qt.callLater(root.updateTargets);
        return true;
    }

    function close() {
        if (!root.visible)
            return false;
        root.visible = false;
        root.revision++;
        root.updateTargets();
        return true;
    }

    function toggle() {
        if (root.visible) {
            root.close();
            return false;
        }
        return root.open();
    }

    function focusWindow(id) {
        const window = root.windows.find(candidate => Number(candidate.id) === Number(id));
        if (!window)
            return false;
        if (window.isMinimized)
            return Niri.restoreWindow(id, Niri.currentOutput || "");
        return Niri.focusWindow(id);
    }

    Connections {
        target: Niri
        function onWindowsChanged() {
            root.refresh();
        }
        function onFocusedWindowChanged() {
            root.refresh();
        }
    }

    Connections {
        target: WindowPreviewService
        function onConnectedChanged() {
            if (root.visible)
                Qt.callLater(root.updateTargets);
        }
    }
}
