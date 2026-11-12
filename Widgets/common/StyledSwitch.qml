import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common

Switch {
    id: root

    property real scale: 0.9
    property color activeColor: Appearance.colors.colPrimary
    property color inactiveColor: Appearance.colors.colSurfaceContainerHighest

    implicitWidth: 52 * root.scale
    implicitHeight: 32 * root.scale
    padding: 0

    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: height / 2
        color: root.checked ? root.activeColor : root.inactiveColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }

    indicator: Rectangle {
        width: 28 * root.scale
        height: 28 * root.scale
        radius: height / 2
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked ? 22 * root.scale : 2 * root.scale
        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowBlur: 0.35
            shadowVerticalOffset: 1
            autoPaddingEnabled: true
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }
    }
}
