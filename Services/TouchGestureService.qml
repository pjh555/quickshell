pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal actionRequested(string action, string screenName)

    property string lastAction: ""
    property string lastScreen: ""

    readonly property var actions: ["home", "overview", "quick-settings", "notifications", "app-previous",
        "app-next", "workspace-previous", "workspace-next", "stage-manager", "touch-keyboard"]

    function trigger(action, screenName) {
        const normalized = String(action || "").trim().toLowerCase();
        if (root.actions.indexOf(normalized) < 0)
            return false;
        const target = String(screenName || "");
        root.lastAction = normalized;
        root.lastScreen = target;
        // Gesture handlers fire while a touch point is still being delivered.
        // Showing a new layer surface or hiding the current one in that stack
        // can leave Qt's pointer handlers with a point that no longer exists.
        // Let the event finish first, then perform the shell action.
        Qt.callLater(() => root.actionRequested(normalized, target));
        return true;
    }
}
