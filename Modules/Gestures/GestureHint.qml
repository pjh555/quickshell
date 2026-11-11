import QtQuick
import qs.Common
import qs.Components

Rectangle {
    id: root

    property bool active: false
    property real progress: 0
    property string icon: "apps"
    property string label: ""

    readonly property real reveal: Math.min(1, Math.max(0, root.progress) * 2.4)

    width: Math.max(132, labelText.implicitWidth + 62)
    height: 48
    radius: 24
    color: Qt.rgba(0.06, 0.07, 0.09, 0.9)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)
    opacity: root.active ? root.reveal : 0
    scale: 0.92 + 0.08 * root.reveal

    Behavior on opacity {
        NumberAnimation {
            duration: 90
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 9

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            iconSize: 21
            color: "#ffffffff"
        }

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: "#ffffffff"
            font.family: Fonts.ui
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}
