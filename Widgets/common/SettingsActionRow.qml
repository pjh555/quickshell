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
    property string valueText: ""
    property bool showDivider: true
    property color iconContainerColor: IconPalette.backgroundFor(root.iconName)
    property color iconColor: IconPalette.foregroundFor(root.iconName)

    implicitHeight: description === "" ? 50 : 62
    leftPadding: Metrics.spacingS
    rightPadding: Metrics.spacingS
    topPadding: 0
    bottomPadding: 0
    buttonRadius: Metrics.cornerS
    containerColor: root.highlighted ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.14) :
                                       "transparent"
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
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 7
                color: root.iconContainerColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: 19
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

            Text {
                visible: root.valueText !== ""
                Layout.maximumWidth: Math.max(72, root.width * 0.32)
                text: root.valueText
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
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
            anchors.leftMargin: root.iconName !== "" ? 42 : Metrics.spacingXS
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacingXS
            anchors.bottom: parent.bottom
            height: Metrics.dividerWidth
            visible: root.showDivider
            color: Appearance.applyAlpha(Appearance.macos.textPrimary, 0.12)
        }
    }
}
