pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property bool available: PlatformService.isNiri || PlatformService.isSway
    property int _pendingDelay: 0

    // Shell surfaces such as the control center must be gone before the
    // compositor freezes the screen, otherwise they end up in the capture.
    function capture(delayMs) {
        if (!root.available)
            return false;
        const delay = Number(delayMs) || 0;
        if (delay <= 0) {
            root._launch();
            return true;
        }
        root._pendingDelay = delay;
        delayedCapture.restart();
        return true;
    }

    function _launch() {
        if (PlatformService.isNiri) {
            // Use niri's native screenshot surface so the user can choose a
            // region, window or output and get its normal save/copy UI.
            Quickshell.execDetached(["niri", "msg", "action", "screenshot"]);
            return;
        }
        if (PlatformService.isSway) {
            Quickshell.execDetached(["sh", "-c",
                                     "mkdir -p \"$HOME/Pictures/Screenshots\" && grim -g \"$(slurp)\" "
                                     + "\"$HOME/Pictures/Screenshots/Screenshot-$(date +%Y%m%d-%H%M%S).png\""]);
        }
    }

    Timer {
        id: delayedCapture
        interval: Math.max(1, root._pendingDelay)
        repeat: false
        onTriggered: root._launch()
    }
}
