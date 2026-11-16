import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import "../SystemCards/SystemCardPalette.js" as CardPalette

Item {
    id: root

    required property string tileId
    property string title: ""
    property string iconName: "widgets"
    property string locationText: ""
    property bool checked: true
    readonly property var palette: CardPalette.paletteFor(root.tileId)
    readonly property string surfaceStyle: String(root.palette.style || "neutral")
    readonly property bool usesFullColorSurface: root.surfaceStyle === "fullColor" || root.surfaceStyle
                                                 === "media"
    readonly property color foregroundColor: root.usesFullColorSurface ? root.palette.foreground : (
                                                                             UiPreferences.darkMode
                                                                             ? "#F5F5F7" : "#1C1C1E")
    readonly property color secondaryColor: root.usesFullColorSurface ? root.palette.secondary : (
                                                                            UiPreferences.darkMode
                                                                            ? "#AEAEB2" : "#636366")

    signal toggled(bool checked)

    implicitHeight: 104
    Accessible.role: Accessible.CheckBox
    Accessible.name: [root.title, root.locationText].filter(value => String(value || "").length > 0).join(
        ", ")
    Accessible.checked: root.checked

    Rectangle {
        anchors.fill: parent
        radius: Metrics.cornerM
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: root.usesFullColorSurface ? root.palette.start : (UiPreferences.darkMode ? "#353537" :
                                                                                                  "#FFFFFF")
            }

            GradientStop {
                position: 1
                color: root.usesFullColorSurface ? root.palette.end : (UiPreferences.darkMode ? "#242426" :
                                                                                                "#F2F2F7")
            }
        }
        border.width: 1
        border.color: root.usesFullColorSurface ? Qt.rgba(1, 1, 1, 0.18) : (UiPreferences.darkMode ? Qt.rgba(1,
                                                                                                             1, 1, 0.12) :
                                                                                                     Qt.rgba(0,
                                                                                                             0, 0, 0.08))
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingM
        spacing: Metrics.spacingM

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignTop
            radius: 11
            color: root.palette.accentBackground

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                iconSize: 24
                fill: 1
                color: root.palette.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.spacingXS

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.foregroundColor
                font.family: Typography.bodyLarge.family
                font.pixelSize: Typography.bodyLarge.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.locationText
                color: root.secondaryColor
                font.family: Typography.bodySmall.family
                font.pixelSize: Typography.bodySmall.pixelSize
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                text: root.checked ? "●" : "○"
                color: root.secondaryColor
                font.family: Fonts.ui
                font.pixelSize: Typography.labelSmall.pixelSize
                Accessible.ignored: true
            }
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignTop
            checked: root.checked
            activeColor: "#34C759"
            inactiveColor: UiPreferences.darkMode ? "#636366" : "#AEAEB2"
            Accessible.name: root.title
            onToggled: root.toggled(checked)
        }
    }
}
