import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Modules.Gestures
import qs.Services

PanelWindow {
    id: root

    property var targetScreen: null

    readonly property real topEdgeHeight: 12
    readonly property real bottomEdgeHeight: 16
    readonly property real sideEdgeWidth: 14
    readonly property string screenName: root.targetScreen ? String(root.targetScreen.name) : ""

    screen: root.targetScreen
    // Keep the gesture layer mapped while Launchpad is open. The Launchpad uses
    // the Overlay layer, so it still receives input first; toggling this layer
    // surface from a touch handler can otherwise invalidate Qt's active point.
    visible: root.targetScreen !== null && PlatformService.touchGesturesEnabled
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clavis-touch-gestures"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The middle of the screen stays click-through. Only the four edge strips
    // are part of the input region.
    mask: Region {
        Region {
            item: leftEdge
        }
        Region {
            item: rightEdge
        }
        Region {
            item: topEdge
        }
        Region {
            item: bottomEdge
        }
    }

    EdgeSwipeArea {
        id: leftEdge
        enabled: !LaunchpadService.visible

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.topEdgeHeight
        anchors.bottomMargin: root.bottomEdgeHeight
        width: root.sideEdgeWidth
        screenName: root.screenName
        horizontal: true
        direction: 1
        shortAction: "app-previous"
        longAction: "workspace-previous"
        longDistance: 150

        onTriggered: (action, screen) => TouchGestureService.trigger(action, screen)
    }

    EdgeSwipeArea {
        id: rightEdge
        enabled: !LaunchpadService.visible

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.topEdgeHeight
        anchors.bottomMargin: root.bottomEdgeHeight
        width: root.sideEdgeWidth
        screenName: root.screenName
        horizontal: true
        direction: -1
        shortAction: "app-next"
        longAction: "workspace-next"
        longDistance: 150

        onTriggered: (action, screen) => TouchGestureService.trigger(action, screen)
    }

    EdgeSwipeArea {
        id: topEdge
        enabled: !LaunchpadService.visible

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.topEdgeHeight
        screenName: root.screenName
        horizontal: false
        direction: 1
        shortAction: "quick-settings"
        longAction: "notifications"
        longDistance: 150

        onTriggered: (action, screen) => TouchGestureService.trigger(action, screen)
    }

    EdgeSwipeArea {
        id: bottomEdge
        enabled: !LaunchpadService.visible

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.bottomEdgeHeight
        screenName: root.screenName
        horizontal: false
        direction: -1
        shortAction: "home"
        longAction: "overview"
        longDistance: 180

        onTriggered: (action, screen) => TouchGestureService.trigger(action, screen)
    }

    GestureHint {
        active: leftEdge.active
        progress: leftEdge.progress
        icon: leftEdge.longReached ? "workspaces" : "arrow_back"
        label: leftEdge.longReached ? qsTr("Previous workspace") : qsTr("Previous app")
        x: 22 + leftEdge.progress * 18
        anchors.verticalCenter: parent.verticalCenter
        z: 10
    }

    GestureHint {
        active: rightEdge.active
        progress: rightEdge.progress
        icon: rightEdge.longReached ? "workspaces" : "arrow_forward"
        label: rightEdge.longReached ? qsTr("Next workspace") : qsTr("Next app")
        x: root.width - width - 22 - rightEdge.progress * 18
        anchors.verticalCenter: parent.verticalCenter
        z: 10
    }

    GestureHint {
        active: topEdge.active
        progress: topEdge.progress
        icon: topEdge.longReached ? "notifications" : "tune"
        label: topEdge.longReached ? qsTr("Notifications") : qsTr("Quick settings")
        y: 18 + topEdge.progress * 18
        anchors.horizontalCenter: parent.horizontalCenter
        z: 10
    }

    GestureHint {
        active: bottomEdge.active
        progress: bottomEdge.progress
        icon: bottomEdge.longReached ? "grid_view" : "apps"
        label: bottomEdge.longReached ? qsTr("Overview") : qsTr("Launchpad")
        y: root.height - 92 - bottomEdge.progress * 68
        anchors.horizontalCenter: parent.horizontalCenter
        z: 10
    }
}
