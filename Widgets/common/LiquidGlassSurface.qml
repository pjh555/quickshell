pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

// A compositor-backed Liquid Glass control/navigation surface. The Niri
// integration provides backdrop blur; these layers provide adaptive tint,
// edge light and elevation without turning content surfaces into glass.
Item {
    id: root

    property color baseColor: Appearance.colors.colLayer1Base
    property real radius: Appearance.rounding.extraLarge
    property real blurOpacity: 0.34
    property real fallbackOpacity: 0.94
    property real topHighlight: 0.16
    property real bottomReflection: 0.04
    property bool elevated: true
    property bool clipContent: false
    readonly property real effectiveOpacity: BlurService.enabled ? root.blurOpacity : root.fallbackOpacity
    default property alias content: contentLayer.data

    Rectangle {
        id: material

        anchors.fill: parent
        radius: root.radius
        color: Appearance.applyAlpha(Appearance.mix(root.baseColor, Appearance.macos.surfaceElevated, 0.82),
                                     root.effectiveOpacity)
        antialiasing: true
        layer.enabled: root.elevated

        layer.effect: MultiEffect {
            shadowEnabled: root.elevated
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.34)
            shadowBlur: 0.78
            shadowVerticalOffset: 10
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    GlassHighlight {
        anchors.fill: parent
        radius: root.radius
        topStrength: root.topHighlight
        bottomStrength: root.bottomReflection
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Appearance.macos.glassBorder
        antialiasing: true
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        clip: root.clipContent
    }
}
