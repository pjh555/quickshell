import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets.common

MouseArea {
    id: root

    required property var modelData
    property var screen: null
    property string edge: "top"
    property var barVisualItem: null

    signal menuOpened(var qsWindow)
    signal menuClosed

    property bool longPressTriggered: false
    property real pressX: 0
    property real pressY: 0

    implicitWidth: Sizes.barControlCircleSize
    implicitHeight: Sizes.barControlCircleSize
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function closeMenu() {
        if (menu.active && menu.item && typeof menu.item.close === "function")
            menu.item.close();
    }

    function closeOtherMenus() {
        if (!root.parent)
            return;

        const siblings = root.parent.children;
        for (let i = 0; i < siblings.length; i += 1) {
            const sibling = siblings[i];
            if (sibling === root)
                continue;
            if (typeof sibling.closeMenu === "function")
                sibling.closeMenu();
        }
    }

    function openSecondaryAction() {
        if (root.modelData.hasMenu || root.modelData.menu) {
            if (menu.active && menu.item && typeof menu.item.close === "function") {
                menu.item.close();
            } else {
                root.closeOtherMenus();
                menu.open();
            }
            return;
        }
        if (typeof root.modelData.secondaryActivate === "function")
            root.modelData.secondaryActivate();
    }

    onPressed: event => {
                   if (event.button === Qt.LeftButton) {
                       root.longPressTriggered = false;
                       root.pressX = event.x;
                       root.pressY = event.y;
                       longPressTimer.restart();
                   } else if (event.button === Qt.RightButton) {
                       root.longPressTriggered = true;
                       root.openSecondaryAction();
                   }
                   event.accepted = true;
               }
    onReleased: event => {
                    longPressTimer.stop();
                    if (event.button === Qt.LeftButton && !root.longPressTriggered) {
                        root.modelData.activate();
                        root.closeMenu();
                    }
                    root.longPressTriggered = false;
                    event.accepted = true;
                }
    onCanceled: longPressTimer.stop()
    onPositionChanged: event => {
                           if (pressed && Math.hypot(event.x - root.pressX, event.y - root.pressY) > 12)
                           longPressTimer.stop();
                       }

    Timer {
        id: longPressTimer

        interval: 550
        repeat: false
        onTriggered: {
            root.longPressTriggered = true;
            root.openSecondaryAction();
        }
    }

    Loader {
        id: menu

        active: false

        function open() {
            menu.active = true;
        }

        sourceComponent: TrayMenu {
            Component.onCompleted: this.open()

            trayItemMenuHandle: root.modelData.menu
            trayItemId: root.modelData.id || ""
            anchorItem: root
            screen: root.screen
            edge: root.edge
            barVisualItem: root.barVisualItem

            onMenuOpened: window => root.menuOpened(window)
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon

        source: root.modelData.icon || ""
        anchors.centerIn: parent
        width: Sizes.barIconSize
        height: Sizes.barIconSize
        asynchronous: true
        mipmap: true
    }

    PopupToolTip {
        extraVisibleCondition: root.containsMouse
        text: TrayService.getTooltipForItem(root.modelData)
    }
}
