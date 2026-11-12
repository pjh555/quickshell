import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import "../../Common/functions/SettingsIconPalette.js" as IconPalette

RippleButton {
    id: root

    property string iconName: ""
    property string trailingIconName: "chevron_right"
    property string description: ""
    property bool showDivider: true
    property color iconContainerColor: IconPalette.backgroundFor(root.iconName)
    property color iconColor: IconPalette.foregroundFor(root.iconName)

    implicitHeight: description === "" ? Metrics.controlHeightXL : 68
    leftPadding: Metrics.spacingS
    rightPadding: Metrics.spacingS
    topPadding: 0
    bottomPadding: 0
    buttonRadius: Metrics.cornerS
    containerColor: "transparent"
    rippleColor: Appearance.colors.colOnSurface
    stateLayerColor: Appearance.colors.colOnSurface
    pressedStateLayerColor: Appearance.colors.colOnSurface
    focusStateLayerColor: Appearance.colors.colOnSurface
    stateLayerOpacity: Appearance.interaction.hoverStateLayerOpacity
    pressedStateLayerOpacity: Appearance.interaction.pressedStateLayerOpacity
    focusStateLayerOpacity: Appearance.interaction.focusStateLayerOpacity
    focusPolicy: Qt.StrongFocus

    contentItem: Item {
        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spacingM

            Rectangle {
                visible: root.iconName !== ""
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 8
                color: root.iconContainerColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: 20
                    fill: 1
                    color: root.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.text
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.bodyLarge.family
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.description !== ""
                    text: root.description
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.bodySmall.family
                    font.pixelSize: Typography.bodySmall.pixelSize
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.preferredWidth: Metrics.iconM
                Layout.fillHeight: true
                visible: root.trailingIconName !== ""

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.trailingIconName
                    iconSize: 18
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: root.iconName !== "" ? 44 : Metrics.spacingXS
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacingXS
            anchors.bottom: parent.bottom
            height: Metrics.dividerWidth
            visible: root.showDivider
            color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.5)
        }
    }
}
