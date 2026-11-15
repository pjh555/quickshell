import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string title: ""
    property string iconName: "settings"
    property string backAccessibleName: qsTr("Back to General settings")
    signal backRequested

    implicitHeight: 52

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingM
        anchors.rightMargin: Metrics.spacingM
        spacing: Metrics.spacingS

        IconButton {
            iconName: "arrow_back"
            iconColor: Appearance.colors.colOnSurface
            accessibleName: root.backAccessibleName
            hoverStateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            onClicked: root.backRequested()
        }

        Rectangle {
            visible: root.iconName !== ""
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 8
            color: Appearance.colors.colSecondaryContainer

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                iconSize: 20
                fill: 1
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            font.family: Typography.titleLarge.family
            font.pixelSize: Typography.titleLarge.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.36)
    }
}
