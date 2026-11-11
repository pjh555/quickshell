import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Modules.Launchpad
import qs.Services

PanelWindow {
    id: root

    property var targetScreen: null
    readonly property bool launchpadActive: LaunchpadService.visible && root.targetScreen && String(
                                                root.targetScreen.name) === LaunchpadService.targetScreenName

    screen: root.targetScreen
    // Keep this layer surface mapped for the lifetime of the output. Repeatedly
    // unmapping and remapping a fullscreen overlay crashes some Qt/Wayland
    // stacks during the surface transition. The content and input region are
    // still fully inactive while Launchpad is closed.
    visible: root.targetScreen !== null
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clavis-shell-launchpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.launchpadActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region {
        id: activeInput

        item: launchpadSurface
    }
    Region {
        id: inactiveInput
    }
    mask: root.launchpadActive ? activeInput : inactiveInput

    // Create the icon cache early so the first open reuses rasterized PNGs
    // instead of rasterizing every SVG on the open path.
    Component.onCompleted: Qt.callLater(LaunchpadIconCache.build)

    LaunchpadSurface {
        id: launchpadSurface

        anchors.fill: parent
        // Render one near-invisible frame after startup so icon sources are
        // registered and the PNG icon cache is built before the first open.
        visible: root.launchpadActive || root.warmup
        opacity: root.launchpadActive ? 1 : 0.04
        targetScreen: root.targetScreen
    }

    property bool warmup: true

    Timer {
        id: warmupTimer

        interval: 1600
        repeat: false
        running: true
        onTriggered: {
            root.warmup = false;
            if (!root.launchpadActive)
                launchpadSurface.openProgress = 0;
        }
    }

    onTargetScreenChanged: {
        if (root.targetScreen !== null && !root.launchpadActive)
            launchpadSurface.openProgress = 1;
    }
}
