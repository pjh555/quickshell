import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property var screen: null
    property var barVisualItem: null

    implicitWidth: button.implicitWidth + 2 * root.pillPadding
    implicitHeight: root.pillThickness

    BarLabelButton {
        id: button

        anchors.centerIn: parent
        iconName: "keyboard"
        tooltipText: qsTr("Touch keyboard")
        selected: TouchKeyboardService.visible
        onClicked: {
            if (!TouchKeyboardService.visible)
                StatusMenuService.close();
            TouchKeyboardService.toggle();
        }
    }
}
