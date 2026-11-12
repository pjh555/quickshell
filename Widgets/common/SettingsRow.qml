import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import "../../Common/functions/SettingsIconPalette.js" as IconPalette

Rectangle {
    id: root

    property string iconName: ""
    property string title: ""
    property string supportingText: ""
    property bool interactive: false
    property bool highlighted: false
    property bool showDivider: true
    property real iconFill: 1
    property color iconContainerColor: IconPalette.backgroundFor(root.iconName)
    property color iconColor: IconPalette.foregroundFor(root.iconName)
    property Component leading
    property alias trailing: trailingSlot.data

    signal clicked

    implicitHeight: Math.max(Metrics.controlHeightXL, rowLayout.implicitHeight + Metrics.spacingS * 2)
    radius: Metrics.cornerS
    color: {
        if (root.highlighted)
            return Appearance.colors.colPrimaryContainer;
        if (!root.interactive)
            return "transparent";
        if (pointer.pressed)
            return Appearance.colors.colLayer1Active;
        if (pointer.containsMouse)
            return Appearance.colors.colLayer1Hover;
        return "transparent";
    }
    opacity: enabled ? 1 : 0.45

    RowLayout {
        id: rowLayout

        z: 1
        spacing: Metrics.spacingM

        anchors {
            fill: parent
            leftMargin: Metrics.spacingS
            rightMargin: Metrics.spacingS
            topMargin: Metrics.spacingS
            bottomMargin: Metrics.spacingS
        }

        Loader {
            visible: root.leading !== null
            active: visible
            Layout.preferredWidth: visible ? Metrics.controlHeightM : 0
            Layout.preferredHeight: visible ? Metrics.controlHeightM : 0
            sourceComponent: root.leading
        }

        Rectangle {
            visible: root.leading === null && root.iconName.length > 0
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 8
            color: root.iconContainerColor

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                iconSize: 20
                fill: root.iconFill
                color: root.iconColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Metrics.dividerWidth

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnSurface
                font.family: Typography.bodyLarge.family
                font.pixelSize: Typography.bodyLarge.pixelSize
                font.weight: Font.Normal
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.supportingText.length > 0
                text: root.supportingText
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Typography.bodySmall.family
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }

        RowLayout {
            id: trailingSlot

            Layout.alignment: Qt.AlignVCenter
            spacing: Metrics.spacingXS
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: root.iconName.length > 0 || root.leading !== null ? 52 : Metrics.spacingM
        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacingS
        anchors.bottom: parent.bottom
        height: Metrics.dividerWidth
        visible: root.showDivider
        color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.5)
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled && root.interactive
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }
    }
}
