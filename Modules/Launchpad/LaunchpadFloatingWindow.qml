import QtQuick
import Quickshell
import qs.Modules.Launchpad
import qs.Services

// GNOME/Mutter does not implement wlr-layer-shell. A fullscreen toplevel is
// the closest supported surface, and works on any Wayland compositor.
FloatingWindow {
    id: root

    property var targetScreen: null

    screen: root.targetScreen
    visible: LaunchpadService.visible && root.targetScreen && String(root.targetScreen.name)
             === LaunchpadService.targetScreenName
    color: "transparent"
    title: qsTr("Launchpad")
    implicitWidth: root.targetScreen ? root.targetScreen.width : 1280
    implicitHeight: root.targetScreen ? root.targetScreen.height : 720
    fullscreen: true

    LaunchpadSurface {
        anchors.fill: parent
        targetScreen: root.targetScreen
    }
}
