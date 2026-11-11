import QtQuick
import qs.Common

QtObject {
    id: root

    readonly property bool dark: Appearance.macos.dark
    // Restore the original Clavis/macOS material palette.  The keyboard keeps
    // the Gboard-derived geometry and gestures, but keys use the same keycap
    // surfaces, hairlines and accent containers as the rest of the shell.
    readonly property color panelBase: Appearance.macos.surfaceSecondary
    readonly property color key: Appearance.macos.keycap
    readonly property color keySpecial: Appearance.macos.keycap
    readonly property color keyPressed: Appearance.macos.keycapPressed
    readonly property color keyHover: Appearance.mix(Appearance.macos.keycap, Appearance.macos.textPrimary,
                                                     0.94)
    readonly property color keyBorder: Appearance.macos.hairline
    readonly property color text: Appearance.macos.textPrimary
    readonly property color textSecondary: Appearance.macos.textSecondary
    readonly property color textMuted: Appearance.macos.textTertiary
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color onAccent: Appearance.colors.colOnPrimary
    readonly property color accentSoft: Appearance.colors.colPrimaryContainer
    readonly property color panelBorder: Appearance.macos.glassBorder
    readonly property color candidate: Appearance.colors.colLayer1
    readonly property color candidatePressed: Appearance.colors.colLayer1Active
    readonly property color popupBackground: Appearance.macos.surfaceElevated
    readonly property color popupBorder: Appearance.macos.hairline

    readonly property real panelRadius: 24
    readonly property real panelPadding: 12
    readonly property real toolbarHeight: 38
    readonly property real toolbarGap: 6
    readonly property real keyRadius: 9
    readonly property real popupRadius: 12
    readonly property real gapX: 6
    readonly property real rowGap: 6
    readonly property real minimumKeyHeight: 34
}
