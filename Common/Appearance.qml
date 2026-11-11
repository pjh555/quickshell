pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string colorsPath: Paths.generatedHome + "/clavis/colors.json"
    property string matugenScheme: "scheme-tonal-spot"
    property string matugenMode: "dark"
    readonly property string effectiveMatugenMode: matugenMode.toLowerCase() === "light" ? "light" : "dark"
    property string currentWallpaperPreview: ""
    // macOS-style acrylic surfaces: keep enough tint for contrast while
    // letting the compositor blur the wallpaper through the shell.
    property real backgroundTransparency: 0.16
    property real contentTransparency: 0.78
    property QtObject m3colors
    property QtObject animationCurves
    property QtObject animation
    property QtObject colors
    property QtObject rounding
    property QtObject spacing
    property QtObject scrollBar
    property QtObject interaction

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function mix(color1, color2, percentage) {
        const amount = percentage === undefined ? 0.5 : percentage;
        const c1 = Qt.color(color1);
        const c2 = Qt.color(color2);
        return Qt.rgba(amount * c1.r + (1 - amount) * c2.r, amount * c1.g + (1 - amount) * c2.g, amount
                       * c1.b + (1 - amount) * c2.b, amount * c1.a + (1 - amount) * c2.a);
    }

    function transparentize(color, percentage) {
        const amount = percentage === undefined ? 1 : percentage;
        const c = Qt.color(color);
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - amount));
    }

    function applyAlpha(color, alpha) {
        const c = Qt.color(color);
        return Qt.rgba(c.r, c.g, c.b, clamp01(alpha));
    }

    function solveOverlayColor(baseColor, targetColor, overlayOpacity) {
        const opacity = clamp01(overlayOpacity);
        if (opacity <= 0)
            return transparentize(targetColor, 1);

        const base = Qt.color(baseColor);
        const target = Qt.color(targetColor);
        const invOpacity = 1 - opacity;
        return Qt.rgba(clamp01((target.r - base.r * invOpacity) / opacity), clamp01((target.g - base.g
                                                                                     * invOpacity) / opacity),
                       clamp01((target.b - base.b * invOpacity) / opacity), opacity);
    }

    function snakeToM3(key) {
        const parts = key.split("_");
        let result = "m3" + parts[0];
        for (let i = 1; i < parts.length; i += 1)
            result += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return result;
    }

    function applyGeneratedColors(text) {
        if (!text)
            return;

        const generatedColors = JSON.parse(text);
        for (let key in generatedColors) {
            const propertyName = root.snakeToM3(key);
            if (propertyName in root.m3colors)
                root.m3colors[propertyName] = Qt.color(generatedColors[key]);
        }
        root.applyMacPalette();
    }

    function applyMacPalette() {
        const dark = root.macos.dark;
        const palette = {
            "m3background": root.macos.background,
            "m3onBackground": root.macos.textPrimary,
            "m3surface": root.macos.surface,
            "m3onSurface": root.macos.textPrimary,
            "m3surfaceVariant": root.macos.surfaceTertiary,
            "m3onSurfaceVariant": root.macos.textSecondary,
            "m3outline": root.macos.textTertiary,
            "m3outlineVariant": root.macos.separator,
            "m3surfaceDim": dark ? "#000000" : "#e5e5ea",
            "m3surfaceBright": dark ? "#3a3a3c" : "#ffffff",
            "m3surfaceContainerLowest": dark ? "#141416" : "#ffffff",
            "m3surfaceContainerLow": dark ? "#1c1c1e" : "#f2f2f7",
            "m3surfaceContainer": dark ? "#2c2c2e" : "#ffffff",
            "m3surfaceContainerHigh": dark ? "#3a3a3c" : "#ffffff",
            "m3surfaceContainerHighest": dark ? "#48484a" : "#e5e5ea",
            "m3primary": root.macos.accent,
            "m3onPrimary": "#ffffff",
            "m3primaryContainer": dark ? "#0a3055" : "#d6e9ff",
            "m3onPrimaryContainer": dark ? "#d6e9ff" : "#003a66",
            "m3primaryFixed": dark ? "#0a3055" : "#d6e9ff",
            "m3primaryFixedDim": dark ? "#0a84ff" : "#007aff",
            "m3onPrimaryFixed": dark ? "#d6e9ff" : "#003a66",
            "m3onPrimaryFixedVariant": dark ? "#a6cfff" : "#00558f",
            "m3secondary": dark ? "#a1a1a6" : "#6e6e73",
            "m3onSecondary": dark ? "#1c1c1e" : "#ffffff",
            "m3secondaryContainer": dark ? "#3a3a3c" : "#e5e5ea",
            "m3onSecondaryContainer": dark ? "#f5f5f7" : "#1d1d1f",
            "m3secondaryFixed": dark ? "#3a3a3c" : "#e5e5ea",
            "m3secondaryFixedDim": dark ? "#48484a" : "#d1d1d6",
            "m3onSecondaryFixed": dark ? "#f5f5f7" : "#1d1d1f",
            "m3onSecondaryFixedVariant": dark ? "#d1d1d6" : "#3a3a3c",
            "m3tertiary": dark ? "#bf5af2" : "#af52de",
            "m3onTertiary": "#ffffff",
            "m3tertiaryContainer": dark ? "#4a2a59" : "#f2d7ff",
            "m3onTertiaryContainer": dark ? "#f2d7ff" : "#3a1a4a",
            "m3tertiaryFixed": dark ? "#4a2a59" : "#f2d7ff",
            "m3tertiaryFixedDim": dark ? "#bf5af2" : "#af52de",
            "m3onTertiaryFixed": dark ? "#f2d7ff" : "#3a1a4a",
            "m3onTertiaryFixedVariant": dark ? "#e0b3ff" : "#6b287e",
            "m3error": root.macos.error,
            "m3onError": "#ffffff",
            "m3errorContainer": dark ? "#93000a" : "#ffdad6",
            "m3onErrorContainer": dark ? "#ffdad6" : "#410002",
            "m3inverseSurface": dark ? "#f5f5f7" : "#1d1d1f",
            "m3inverseOnSurface": dark ? "#1d1d1f" : "#f5f5f7",
            "m3inversePrimary": dark ? "#007aff" : "#0a84ff",
            "m3scrim": "#000000",
            "m3shadow": "#000000",
            "m3surfaceTint": root.macos.accent,
            "m3sourceColor": root.macos.accent
        };

        for (const key in palette)
            root.m3colors[key] = Qt.color(palette[key]);
    }

    function reloadColors() {
        colorFile.reload();
    }

    m3colors: QtObject {
        property bool darkmode: root.effectiveMatugenMode === "dark"
        property color m3background: "#0f1416"
        property color m3error: "#ffb4ab"
        property color m3errorContainer: "#93000a"
        property color m3inverseOnSurface: "#2c3134"
        property color m3inversePrimary: "#09677f"
        property color m3inverseSurface: "#dee3e6"
        property color m3onBackground: "#dee3e6"
        property color m3onError: "#690005"
        property color m3onErrorContainer: "#ffdad6"
        property color m3onPrimary: "#003544"
        property color m3onPrimaryContainer: "#b8eaff"
        property color m3onPrimaryFixed: "#001f28"
        property color m3onPrimaryFixedVariant: "#004d61"
        property color m3onSecondary: "#1e333c"
        property color m3onSecondaryContainer: "#cfe6f1"
        property color m3onSecondaryFixed: "#071e26"
        property color m3onSecondaryFixedVariant: "#354a53"
        property color m3onSurface: "#dee3e6"
        property color m3onSurfaceVariant: "#bfc8cc"
        property color m3onTertiary: "#2c2d4d"
        property color m3onTertiaryContainer: "#e1e0ff"
        property color m3onTertiaryFixed: "#171837"
        property color m3onTertiaryFixedVariant: "#434465"
        property color m3outline: "#8a9296"
        property color m3outlineVariant: "#40484c"
        property color m3primary: "#88d0ec"
        property color m3primaryContainer: "#004d61"
        property color m3primaryFixed: "#b8eaff"
        property color m3primaryFixedDim: "#88d0ec"
        property color m3scrim: "#000000"
        property color m3secondary: "#b3cad5"
        property color m3secondaryContainer: "#354a53"
        property color m3secondaryFixed: "#cfe6f1"
        property color m3secondaryFixedDim: "#b3cad5"
        property color m3shadow: "#000000"
        property color m3sourceColor: "#669cb1"
        property color m3surface: "#0f1416"
        property color m3surfaceBright: "#353a3d"
        property color m3surfaceContainer: "#1b2023"
        property color m3surfaceContainerHigh: "#252b2d"
        property color m3surfaceContainerHighest: "#303638"
        property color m3surfaceContainerLow: "#171c1f"
        property color m3surfaceContainerLowest: "#0a0f11"
        property color m3surfaceDim: "#0f1416"
        property color m3surfaceTint: "#88d0ec"
        property color m3surfaceVariant: "#40484c"
        property color m3tertiary: "#c3c3eb"
        property color m3tertiaryContainer: "#434465"
        property color m3tertiaryFixed: "#e1e0ff"
        property color m3tertiaryFixedDim: "#c3c3eb"
    }

    // Fixed macOS-like neutral materials. Wallpaper-derived accent colors are
    // deliberately not allowed to tint menus, sidebars, or window chrome; the
    // shell should read as macOS in both light and dark appearance.
    readonly property QtObject macos: QtObject {
        readonly property bool dark: root.effectiveMatugenMode === "dark"
        readonly property color background: dark ? "#1c1c1e" : "#f2f2f7"
        readonly property color surface: dark ? "#1c1c1e" : "#ffffff"
        readonly property color surfaceSecondary: dark ? "#2c2c2e" : "#f2f2f7"
        readonly property color surfaceTertiary: dark ? "#3a3a3c" : "#e5e5ea"
        readonly property color surfaceElevated: dark ? "#2c2c2e" : "#ffffff"
        readonly property color textPrimary: dark ? "#f5f5f7" : "#1d1d1f"
        readonly property color textSecondary: dark ? "#a1a1a6" : "#6e6e73"
        readonly property color textTertiary: dark ? "#8e8e93" : "#8e8e93"
        readonly property color separator: dark ? "#3a3a3c" : "#d1d1d6"
        readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
        readonly property color glassBorder: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.58)
        readonly property color accent: dark ? "#0a84ff" : "#007aff"
        readonly property color keycap: dark ? "#4a4a4e" : "#ffffff"
        readonly property color keycapPressed: dark ? "#5a5a5e" : "#e5e5ea"
        readonly property color macFill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
        readonly property color macFillHover: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)
        readonly property color error: dark ? "#ff453a" : "#ff3b30"
        readonly property color shadow: "#000000"
    }

    colors: QtObject {
        property color colSubtext: root.macos.textSecondary

        property color colLayer0Base: root.macos.background
        property color colLayer0: root.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: root.macos.textPrimary
        property color colLayer0Hover: root.transparentize(root.mix(colLayer0, colOnLayer0, 0.9),
                                                           root.contentTransparency)

        property color colLayer0Active: root.transparentize(root.mix(colLayer0, colOnLayer0, 0.8),
                                                            root.contentTransparency)

        property color colLayer0Border: root.macos.hairline

        property color colLayer1Base: root.macos.surfaceElevated
        property color colLayer1: root.solveOverlayColor(colLayer0Base, colLayer1Base, 1
                                                         - root.contentTransparency)
        property color colOnLayer1: root.m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: root.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: root.transparentize(root.mix(colLayer1, colOnLayer1, 0.92),
                                                           root.contentTransparency)

        property color colLayer1Active: root.transparentize(root.mix(colLayer1, colOnLayer1, 0.85),
                                                            root.contentTransparency)

        property color colLayer2Base: root.m3colors.m3surfaceContainer
        property color colLayer2: root.solveOverlayColor(colLayer1Base, colLayer2Base, 1
                                                         - root.contentTransparency)
        property color colLayer2Hover: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base,
                                                                                      colOnLayer2, 0.90), 1
                                                              - root.contentTransparency)
        property color colLayer2Active: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base,
                                                                                       colOnLayer2, 0.80), 1
                                                               - root.contentTransparency)
        property color colLayer2Disabled: root.solveOverlayColor(colLayer1Base, root.mix(colLayer2Base,
                                                                                         root.m3colors.m3background,
                                                                                         0.8), 1 - root.contentTransparency)
        property color colOnLayer2: root.m3colors.m3onSurface
        property color colOnLayer2Disabled: root.mix(colOnLayer2, root.m3colors.m3background, 0.4)

        property color colLayer3Base: root.m3colors.m3surfaceContainerHigh
        property color colLayer3: root.solveOverlayColor(colLayer2Base, colLayer3Base, 1
                                                         - root.contentTransparency)
        property color colLayer3Hover: root.solveOverlayColor(colLayer2Base, root.mix(colLayer3Base,
                                                                                      colOnLayer3, 0.90), 1
                                                              - root.contentTransparency)
        property color colLayer3Active: root.solveOverlayColor(colLayer2Base, root.mix(colLayer3Base,
                                                                                       colOnLayer3, 0.80), 1
                                                               - root.contentTransparency)
        property color colOnLayer3: root.m3colors.m3onSurface

        property color colLayer4Base: root.m3colors.m3surfaceContainerHighest
        property color colLayer4: root.solveOverlayColor(colLayer3Base, colLayer4Base, 1
                                                         - root.contentTransparency)
        property color colLayer4Hover: root.solveOverlayColor(colLayer3Base, root.mix(colLayer4Base,
                                                                                      colOnLayer4, 0.90), 1
                                                              - root.contentTransparency)
        property color colLayer4Active: root.solveOverlayColor(colLayer3Base, root.mix(colLayer4Base,
                                                                                       colOnLayer4, 0.80), 1
                                                               - root.contentTransparency)
        property color colOnLayer4: root.m3colors.m3onSurface

        property color colPrimary: root.m3colors.m3primary
        property color colOnPrimary: root.m3colors.m3onPrimary
        property color colPrimaryHover: root.mix(colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: root.mix(colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: root.m3colors.m3primaryContainer
        property color colOnPrimaryContainer: root.m3colors.m3onPrimaryContainer
        property color colPrimaryContainerHover: root.mix(colPrimaryContainer, colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: root.mix(colPrimaryContainer, colOnPrimaryContainer, 0.8)
        property color colPrimaryFixed: root.m3colors.m3primaryFixed
        property color colPrimaryFixedDim: root.m3colors.m3primaryFixedDim
        property color colOnPrimaryFixed: root.m3colors.m3onPrimaryFixed
        property color colOnPrimaryFixedVariant: root.m3colors.m3onPrimaryFixedVariant

        property color colSecondary: root.m3colors.m3secondary
        property color colOnSecondary: root.m3colors.m3onSecondary
        property color colSecondaryHover: root.mix(colSecondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: root.mix(colSecondary, colLayer1Active, 0.4)
        property color colSecondaryContainer: root.m3colors.m3secondaryContainer
        property color colOnSecondaryContainer: root.m3colors.m3onSecondaryContainer
        property color colSecondaryContainerHover: root.mix(colSecondaryContainer, colOnSecondaryContainer,
                                                            0.90)
        property color colSecondaryContainerActive: root.mix(colSecondaryContainer, colOnSecondaryContainer,
                                                             0.54)
        property color colSecondaryFixed: root.m3colors.m3secondaryFixed
        property color colSecondaryFixedDim: root.m3colors.m3secondaryFixedDim
        property color colOnSecondaryFixed: root.m3colors.m3onSecondaryFixed
        property color colOnSecondaryFixedVariant: root.m3colors.m3onSecondaryFixedVariant

        property color colTertiary: root.m3colors.m3tertiary
        property color colOnTertiary: root.m3colors.m3onTertiary
        property color colTertiaryHover: root.mix(colTertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: root.mix(colTertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: root.m3colors.m3tertiaryContainer
        property color colOnTertiaryContainer: root.m3colors.m3onTertiaryContainer
        property color colTertiaryContainerHover: root.mix(colTertiaryContainer, colOnTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: root.mix(colTertiaryContainer, colLayer1Active, 0.54)
        property color colTertiaryFixed: root.m3colors.m3tertiaryFixed
        property color colTertiaryFixedDim: root.m3colors.m3tertiaryFixedDim
        property color colOnTertiaryFixed: root.m3colors.m3onTertiaryFixed
        property color colOnTertiaryFixedVariant: root.m3colors.m3onTertiaryFixedVariant

        property color colBackgroundSurfaceContainer: root.transparentize(root.m3colors.m3surfaceContainer,
                                                                          root.backgroundTransparency)
        property color colSurfaceContainerLow: root.solveOverlayColor(root.m3colors.m3background,
                                                                      root.m3colors.m3surfaceContainerLow, 1
                                                                      - root.contentTransparency)
        property color colSurfaceContainer: root.solveOverlayColor(root.m3colors.m3surfaceContainerLow,
                                                                   root.m3colors.m3surfaceContainer, 1
                                                                   - root.contentTransparency)
        property color colSurfaceContainerHigh: root.solveOverlayColor(root.m3colors.m3surfaceContainer,
                                                                       root.m3colors.m3surfaceContainerHigh,
                                                                       1 - root.contentTransparency)
        property color colSurfaceContainerHighest: root.solveOverlayColor(root.m3colors.m3surfaceContainerHigh,
                                                                          root.m3colors.m3surfaceContainerHighest,
                                                                          1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: root.mix(root.m3colors.m3surfaceContainerHighest,
                                                                 root.m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: root.mix(root.m3colors.m3surfaceContainerHighest,
                                                                  root.m3colors.m3onSurface, 0.85)
        property color colOnSurface: root.m3colors.m3onSurface
        property color colOnSurfaceVariant: root.m3colors.m3onSurfaceVariant
        property color colInversePrimary: root.m3colors.m3inversePrimary
        property color colOnImage: Qt.rgba(1.0, 1.0, 1.0, 0.96)
        property color colOnImageMuted: root.applyAlpha(colOnImage, 0.82)
        property color colWeatherCardSurface: root.m3colors.m3surfaceContainerLowest
        property color colOnWeatherCardSurface: root.m3colors.m3onSurface
        property color colOnWeatherCardSurfaceVariant: root.m3colors.m3onSurfaceVariant

        property color colTooltip: root.m3colors.m3inverseSurface
        property color colOnTooltip: root.m3colors.m3inverseOnSurface
        property color colScrim: root.transparentize(root.m3colors.m3scrim, 0.5)
        property color colShadow: root.transparentize(root.m3colors.m3shadow, 0.7)
        property color colOutline: root.macos.textTertiary
        property color colOutlineVariant: root.macos.separator

        property color colError: root.m3colors.m3error
        property color colOnError: root.m3colors.m3onError
        property color colErrorHover: root.mix(colError, colLayer1Hover, 0.85)
        property color colErrorActive: root.mix(colError, colLayer1Active, 0.7)
        property color colErrorContainer: root.m3colors.m3errorContainer
        property color colOnErrorContainer: root.m3colors.m3onErrorContainer
        property color colErrorContainerHover: root.mix(colErrorContainer, colOnErrorContainer, 0.90)
        property color colErrorContainerActive: root.mix(colErrorContainer, colOnErrorContainer, 0.70)
    }

    animationCurves: Animations.curves
    animation: Animations.animation

    interaction: QtObject {
        readonly property int rippleDuration: 520
        readonly property real rippleOpacity: 0.10
        readonly property int stateLayerTransitionDuration: Animations.durations.expressiveFastEffects
        readonly property real hoverStateLayerOpacity: 0.06
        readonly property real focusStateLayerOpacity: 0.08
        readonly property real pressedStateLayerOpacity: 0.10
        readonly property real selectedStateLayerOpacity: 0.10
        readonly property int rippleEasing: Easing.OutCubic
    }

    rounding: QtObject {
        property int extraSmall: 4
        property int small: 8
        property int normal: 12
        property int large: 16
        property int extraLarge: 22
        property int veryLarge: 26
        property int full: 9999
    }

    spacing: QtObject {
        property int xSmall: 4
        property int small: 8
        property int medium: 16
        property int large: 24
        property int panelPadding: 20
    }

    scrollBar: QtObject {
        property int width: 8
        property int margin: 4
        property int minLength: 24
        property int radius: root.rounding.full
        property real activeOpacity: 0.5
        property real inactiveOpacity: 0
        property color thumbColor: root.colors.colOnSurfaceVariant
    }

    Component.onCompleted: root.applyMacPalette()
    onEffectiveMatugenModeChanged: root.applyMacPalette()

    FileView {
        id: colorFile
        path: root.colorsPath
        watchChanges: true

        onLoaded: {
            try {
                root.applyGeneratedColors(colorFile.text());
            } catch (error) {}
        }

        onFileChanged: colorFile.reload()
    }
}
