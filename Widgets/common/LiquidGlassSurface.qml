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
    property real blurOpacity: 0.36
    property real fallbackOpacity: 0.94
    property real topHighlight: 0.26
    property real bottomReflection: 0.065
    property bool clearMaterial: false
    property bool elevated: true
    property bool clipContent: false
    readonly property real effectiveOpacity: BlurService.enabled ? root.blurOpacity : root.fallbackOpacity
    readonly property real materialOpacity: root.clearMaterial && BlurService.enabled ? root.effectiveOpacity
                                                                                        * 0.72 : root.effectiveOpacity
    default property alias content: contentLayer.data

    Rectangle {
        id: material

        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0.0
                color: Appearance.applyAlpha(Appearance.mix(root.baseColor, Appearance.macos.surfaceElevated,
                                                            root.clearMaterial ? 0.70 : 0.92),
                                             root.materialOpacity)
            }

            GradientStop {
                position: 1.0
                color: Appearance.applyAlpha(Appearance.mix(root.baseColor, Appearance.macos.background,
                                                            root.clearMaterial ? 0.38 : 0.62),
                                             root.materialOpacity)
            }
        }
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

    // A clear material catches broad, moving-looking reflections while the
    // compositor supplies the actual wallpaper blur behind it.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.clearMaterial
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0.0
                color: Appearance.applyAlpha(Appearance.macos.textPrimary, 0.055)
            }

            GradientStop {
                position: 0.28
                color: "transparent"
            }

            GradientStop {
                position: 0.72
                color: "transparent"
            }

            GradientStop {
                position: 1.0
                color: Appearance.applyAlpha(Appearance.macos.textPrimary, 0.035)
            }
        }
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.clearMaterial ? Appearance.applyAlpha(Appearance.macos.textPrimary, 0.22) :
                                           Appearance.macos.glassBorder
        antialiasing: true
    }

    // Inner rim: glass thickness, not another outline.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Appearance.applyAlpha(Appearance.macos.textPrimary, root.clearMaterial ? 0.12 : 0.09)
        antialiasing: true
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        clip: root.clipContent
    }
}
