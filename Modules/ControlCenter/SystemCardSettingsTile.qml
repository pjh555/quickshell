import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../SystemCards/SystemCardPalette.js" as CardPalette

Item {
    id: root

    required property string tileId
    property string title: ""
    property string iconName: "widgets"
    property string locationText: ""
    property bool checked: true
    readonly property var palette: CardPalette.paletteFor(root.tileId)

    signal toggled(bool checked)

    implicitHeight: 104
    Accessible.role: Accessible.CheckBox
    Accessible.name: [root.title, root.locationText].filter(value => String(value || "").length > 0).join(
        ", ")
    Accessible.checked: root.checked

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.width
                y2: root.height

                GradientStop {
                    position: 0
                    color: Appearance.applyAlpha(root.palette.start, BlurService.enabled ? 0.72 : 0.94)
                }

                GradientStop {
                    position: 0.55
                    color: Appearance.applyAlpha(root.palette.mid, BlurService.enabled ? 0.60 : 0.90)
                }

                GradientStop {
                    position: 1
                    color: Appearance.applyAlpha(root.palette.end, BlurService.enabled ? 0.72 : 0.94)
                }
            }

            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
                radius: Metrics.cornerM
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.cornerM
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)
    }

    GlassHighlight {
        anchors.fill: parent
        radius: Metrics.cornerM
        topStrength: 0.14
        bottomStrength: 0.03
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
                color: root.palette.foreground
                font.family: Typography.bodyLarge.family
                font.pixelSize: Typography.bodyLarge.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.locationText
                color: root.palette.secondary
                font.family: Typography.bodySmall.family
                font.pixelSize: Typography.bodySmall.pixelSize
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                text: root.checked ? "●" : "○"
                color: root.palette.secondary
                font.family: Fonts.ui
                font.pixelSize: Typography.labelSmall.pixelSize
                Accessible.ignored: true
            }
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignTop
            checked: root.checked
            activeColor: Qt.rgba(1, 1, 1, 0.44)
            inactiveColor: Qt.rgba(0, 0, 0, 0.25)
            Accessible.name: root.title
            onToggled: root.toggled(checked)
        }
    }
}
