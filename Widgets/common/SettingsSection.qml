import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import "../../Common/functions/SettingsIconPalette.js" as IconPalette

Item {
    id: root

    property string title: ""
    property string iconName: ""
    property string supportingText: ""
    property real pullExpansion: 0
    property real contentSpacing: 0
    property bool flat: false
    property bool flatIconContainer: true
    property bool compact: false
    property color iconContainerColor: IconPalette.backgroundFor(root.iconName)
    property color iconColor: IconPalette.foregroundFor(root.iconName)
    property alias headerTrailing: headerTrailingSlot.data
    default property alias content: body.data

    implicitHeight: sectionLayout.implicitHeight

    ColumnLayout {
        id: sectionLayout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: (root.compact ? 6 : Metrics.spacingS) + root.pullExpansion * 0.5

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Metrics.spacingXS
            Layout.rightMargin: Metrics.spacingXS
            visible: root.title.length > 0 || root.iconName.length > 0 || headerTrailingSlot.children.length
                     > 0
            spacing: Metrics.spacingS

            Rectangle {
                visible: root.iconName.length > 0
                Layout.preferredWidth: root.compact ? 26 : 28
                Layout.preferredHeight: root.compact ? 26 : 28
                radius: root.compact ? 6 : 7
                color: root.iconContainerColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: root.compact ? 17 : 18
                    fill: 1
                    color: root.iconColor
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.title.length > 0
                text: root.title
                color: Appearance.colors.colOnSurface
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                opacity: 0.86
            }

            RowLayout {
                id: headerTrailingSlot

                visible: children.length > 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Metrics.spacingS
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Metrics.spacingXS
            Layout.rightMargin: Metrics.spacingXS
            visible: root.supportingText.length > 0
            text: root.supportingText
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Typography.bodySmall.family
            font.pixelSize: Typography.bodySmall.pixelSize
            wrapMode: Text.Wrap
        }

        Rectangle {
            id: bodySurface

            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + (root.compact ? 6 : Metrics.spacingS) * 2
            radius: Metrics.cornerM
            color: root.flat ? Appearance.macos.background : Appearance.macos.surface
            border.width: Metrics.dividerWidth
            border.color: Appearance.macos.separator
            clip: true

            ColumnLayout {
                id: body

                anchors.fill: parent
                anchors.margins: root.compact ? 6 : Metrics.spacingS
                spacing: root.contentSpacing + root.pullExpansion
            }
        }
    }

    Behavior on implicitHeight {
        enabled: root.pullExpansion === 0
        ElementMoveAnimation {}
    }
}
