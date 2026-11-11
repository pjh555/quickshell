pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    readonly property bool nineKey: TouchKeyboardService.layoutMode === "nine"
    readonly property real panelWidth: {
        const screenWidth = root.screen ? root.screen.width : 1280;
        if (root.nineKey)
        return Math.min(640, Math.max(500, screenWidth * 0.44));
        if (TouchKeyboardService.page === "numbers")
        return Math.min(620, Math.max(480, screenWidth * 0.42));
        return Math.min(920, Math.max(620, screenWidth * 0.64));
    }
    readonly property real panelHeight: {
        const screenHeight = root.screen ? root.screen.height : 900;
        if (root.nineKey)
        return Math.min(410, Math.max(340, screenHeight * 0.42));
        if (TouchKeyboardService.page === "emoji" || TouchKeyboardService.page === "symbolsall")
        return Math.min(430, Math.max(330, screenHeight * 0.44));
        if (TouchKeyboardService.page === "letters")
        return Math.min(450, Math.max(360, screenHeight * 0.44));
        return Math.min(400, Math.max(330, screenHeight * 0.40));
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: TouchKeyboardService.visible
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        bottom: true
    }

    implicitWidth: root.screen ? root.screen.width : 1280
    implicitHeight: root.panelHeight + 20
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clavis-touch-keyboard"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: panel
    }

    KeyboardStyle {
        id: keyboardStyle
    }

    KeyboardPanel {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: root.panelWidth
        height: root.panelHeight
        style: keyboardStyle
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: panel
        radius: keyboardStyle.panelRadius
    }
}
