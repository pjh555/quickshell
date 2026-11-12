import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import "../../Common/functions/SettingsIconPalette.js" as IconPalette

TabButton {
    id: root

    property bool active: false
    property bool toggled: root.active
    property string iconName: "settings"
    property string label: ""
    property string buttonIcon: root.iconName
    property real buttonIconRotation: 0
    property string buttonText: root.label
    property bool expanded: false
    property bool showToggledHighlight: true
    property color iconContainerColor: IconPalette.backgroundFor(root.buttonIcon)
    property real baseSize: 48
    property real baseHighlightHeight: 48

    Layout.fillWidth: true
    implicitWidth: baseSize
    implicitHeight: baseSize
    padding: 0
    background: null

    contentItem: Item {
        id: buttonContent

        implicitWidth: root.baseSize
        implicitHeight: root.baseSize

        Rectangle {
            anchors.fill: parent
            radius: Metrics.cornerS
            color: root.toggled ? Appearance.colors.colPrimaryContainer : root.down ? Appearance.colors.colLayer1Active :
                                                                                      root.hovered
                                                                                      ? Appearance.colors.colLayer1Hover :
                                                                                        "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }

        Item {
            id: itemIconBackground

            width: root.baseSize
            height: root.baseSize
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 8
                color: root.iconContainerColor
            }

            MaterialSymbol {
                anchors.centerIn: parent
                rotation: root.buttonIconRotation
                iconSize: 19
                fill: 1
                text: root.buttonIcon
                color: "white"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }
        }

        Text {
            id: itemText

            anchors.left: itemIconBackground.right
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: root.buttonText
            color: Appearance.colors.colOnLayer1
            font.family: Typography.bodyLarge.family
            font.pixelSize: Typography.bodyLarge.pixelSize
            font.weight: root.toggled ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }
    }
}
