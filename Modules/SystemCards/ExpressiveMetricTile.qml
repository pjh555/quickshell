import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string label: ""
    property string iconName: "monitoring"
    property string valueText: "—"
    property string supportingText: ""
    property string detailText: ""
    property string temperatureText: ""
    property real usage: -1
    property int shapeOverride: -999
    property var trendValues: []
    property bool chartActive: visible
    property int updateInterval: 1000
    property real decorationSize: 70
    property real valueSize: Typography.displaySmall.pixelSize
    property bool glassSurface: false
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color foregroundColor: Appearance.colors.colOnPrimaryContainer
    property color accentColor: Appearance.colors.colPrimary
    property color accentForegroundColor: Appearance.colors.colOnPrimary

    readonly property real normalizedUsage: Math.max(0, Math.min(1, root.usage))
    readonly property bool dense: root.width < 210 || root.height < 190
    readonly property int resolvedShape: {
        if (root.shapeOverride !== -999)
            return root.shapeOverride;
        if (root.usage < 0)
            return MaterialShape.Cookie4Sided;
        if (root.normalizedUsage >= 0.82)
            return MaterialShape.SoftBurst;
        if (root.normalizedUsage >= 0.48)
            return MaterialShape.Sunny;
        return MaterialShape.Cookie4Sided;
    }

    radius: root.glassSurface ? Appearance.rounding.veryLarge : Appearance.rounding.extraLarge
    color: root.glassSurface ? "transparent" : root.containerColor
    clip: true
    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    Accessible.name: [root.label, root.valueText, root.detailText, root.supportingText,
        root.temperatureText].filter(function (value) {
            return String(value || "").length > 0;
        }).join("，")

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    MaterialShape {
        id: metricShape

        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: -implicitSize * 0.18
            bottomMargin: -implicitSize * 0.2
        }
        implicitSize: Math.min(root.width * 0.38, root.height * 0.42, root.decorationSize * (1.08
                                                                                             + root.normalizedUsage
                                                                                             * 0.14))
        visible: !root.glassSurface
        rotation: 18
        shape: root.resolvedShape
        color: root.accentColor
        animationDuration: Appearance.animation.expressiveSlowSpatial.duration
        animationEasing.type: Easing.OutBack
        z: 4
        Accessible.name: root.label + qsTr(" icon")

        Behavior on implicitSize {
            NumberAnimation {
                duration: Appearance.animation.expressiveSlowSpatial.duration
                easing.type: Appearance.animation.expressiveSlowSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveSlowSpatial.bezierCurve
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.iconName
            color: root.accentForegroundColor
            iconSize: root.dense ? 21 : 25
            fill: 1
        }
    }

    Rectangle {
        id: glassBadge

        visible: root.glassSurface
        width: 40
        height: 40
        radius: Appearance.rounding.normal
        color: Qt.rgba(1, 1, 1, 0.16)
        z: 4

        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 16
            bottomMargin: 16
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.iconName
            color: root.accentColor
            iconSize: 24
            fill: 1
        }
    }

    Row {
        id: temperatureBadge

        visible: root.temperatureText.length > 0
        spacing: 3
        z: 5

        anchors {
            top: parent.top
            right: parent.right
            topMargin: root.glassSurface ? 16 : root.dense ? Appearance.spacing.small :
                                                             Appearance.spacing.medium
            rightMargin: root.glassSurface ? 16 : root.dense ? Appearance.spacing.small :
                                                               Appearance.spacing.medium
        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: "thermostat"
            color: root.foregroundColor
            iconSize: root.dense ? Typography.titleSmall.pixelSize : Typography.titleMedium.pixelSize
            fill: 1
            opacity: 0.78
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temperatureText
            color: root.foregroundColor
            font.family: Fonts.numeric
            font.pixelSize: root.dense ? Typography.titleSmall.pixelSize : Typography.titleMedium.pixelSize
            font.weight: Font.DemiBold
            opacity: 0.84
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.glassSurface ? 16 : root.dense ? Appearance.spacing.small :
                                                           Appearance.spacing.medium
        }
        spacing: root.glassSurface ? 4 : root.dense ? 2 : Appearance.spacing.xSmall

        Text {
            Layout.maximumWidth: Math.max(48, root.width - temperatureBadge.width - Appearance.spacing.large
                                          * 1.5)
            text: root.label
            color: root.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: root.glassSurface ? 18 : root.dense ? Typography.titleMedium.pixelSize + 2 :
                                                                  Typography.titleLarge.pixelSize
            font.weight: root.glassSurface ? Font.DemiBold : Font.Bold
            elide: Text.ElideRight
        }

        Text {
            Layout.maximumWidth: Math.max(48, root.width - root.decorationSize - Appearance.spacing.large)
            visible: !root.dense && text.length > 0
            text: root.detailText
            color: root.foregroundColor
            opacity: root.glassSurface ? 0.78 : 0.72
            font.family: Fonts.ui
            font.pixelSize: Typography.labelSmall.pixelSize
            elide: Text.ElideRight
        }

        SystemSparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dense ? Appearance.spacing.xSmall : 0
            Layout.minimumHeight: visible ? (root.dense ? 42 : 46) : 0
            visible: root.trendValues.length > 1 && root.height >= 112
            values: root.trendValues
            historyLength: 60
            updateInterval: root.updateInterval
            maximum: 0
            scaleHeadroom: 1.2
            showGuideLines: false
            active: root.chartActive
            accessibilityName: root.label + qsTr(" trend over the last minute")
            accessibilityDescription: qsTr("Current value ") + root.valueText
            lineColor: root.accentColor
            baselineColor: Appearance.applyAlpha(root.foregroundColor, 0.22)
            lineWidth: 2.2
            fillOpacity: root.glassSurface ? 0.20 : 0.12
        }

        Item {
            Layout.fillHeight: true
            visible: root.trendValues.length <= 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xSmall

            Text {
                Layout.fillWidth: true
                Layout.rightMargin: root.glassSurface ? 56 : root.decorationSize * 0.28
                text: root.valueText
                color: root.foregroundColor
                font.family: Fonts.numeric
                font.pixelSize: root.glassSurface ? 34 : root.valueSize
                font.weight: Font.Bold
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.rightMargin: root.glassSurface ? 56 : root.decorationSize * 0.5
            visible: !root.dense && text.length > 0
            text: root.supportingText
            color: root.foregroundColor
            opacity: root.glassSurface ? 0.78 : 0.74
            font.family: Fonts.ui
            font.pixelSize: root.glassSurface ? 13 : Typography.bodySmall.pixelSize
            elide: Text.ElideRight
        }
    }
}
