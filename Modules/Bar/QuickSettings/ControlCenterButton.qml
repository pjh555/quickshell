import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Modules.QuickSettings
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property var screen: null
    property var barVisualItem: null

    implicitWidth: button.implicitWidth + 2 * root.pillPadding
    implicitHeight: root.pillThickness

    Connections {
        target: StatusMenuService

        function onToggleRequested() {
            menu.opened ? menu.close() : menu.open();
        }

        function onCloseRequested() {
            menu.close();
        }
    }

    BarLabelButton {
        id: button

        anchors.centerIn: parent
        iconName: "tune"
        iconSource: Qt.resolvedUrl("../../../assets/icons/panda-hacker-theme.svg")
        tooltipText: qsTr("Control Center")
        selected: menu.opened
        onClicked: menu.opened ? menu.close() : menu.open()
    }

    // A layer-shell surface is more reliable than an xdg popup on niri. The
    // surface only exists while the menu is open, so it cannot swallow desktop
    // clicks or cover the bar when closed.
    PanelWindow {
        id: menu

        property bool opened: false
        property bool openGuard: false

        function open() {
            if (!root.screen || opened)
                return;
            opened = true;
            StatusMenuService.setOpened(true);
            openGuard = true;
            visible = true;
            guardTimer.restart();
            Qt.callLater(() => keyScope.forceActiveFocus());
        }

        function close() {
            opened = false;
            StatusMenuService.setOpened(false);
            openGuard = false;
            visible = false;
        }

        Timer {
            id: guardTimer
            interval: 600
            repeat: false
            onTriggered: menu.openGuard = false
        }

        visible: false
        screen: root.screen
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-status-menu"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: backdrop
        }

        MouseArea {
            id: backdrop

            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {
                if (!menu.openGuard)
                    menu.close();
            }
        }

        FocusScope {
            id: keyScope

            anchors.fill: parent
            focus: menu.opened

            Keys.onEscapePressed: event => {
                                      menu.close();
                                      event.accepted = true;
                                  }

            Rectangle {
                id: menuBackground

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: PersonalizationConfig.barEdgeSpacing + PersonalizationConfig.barThickness
                                   + Sizes.barPopupGap
                anchors.rightMargin: Sizes.barPopupScreenMargin
                width: 382
                height: Math.min(700, parent.height - anchors.topMargin - Sizes.barPopupScreenMargin)
                radius: 22
                color: BlurService.backgroundColor(Appearance.colors.colLayer0)
                border.width: 1
                border.color: Appearance.macos.glassBorder

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: event => event.accepted = true
                }

                ControlCenterPanel {
                    anchors.fill: parent
                    anchors.margins: 4
                    screen: root.screen
                    active: menu.opened
                    onCloseRequested: menu.close()
                }
            }
        }

        CompositorBlurRegion {
            targetWindow: menu
            backgroundItem: menuBackground
            radius: 22
        }
    }
}
