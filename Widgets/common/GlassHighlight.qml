import QtQuick
import qs.Common

// Specular highlight and inner reflection for a translucent glass surface.
// The compositor supplies the backdrop blur; this layer gives the material a
// lit top edge and a faint bottom bounce so it reads as glass rather than a
// flat tinted rectangle.
Item {
    id: root

    property real radius: Appearance.rounding.extraLarge
    property real topStrength: 0.11
    property real bottomStrength: 0.035

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, root.topStrength)
            }

            GradientStop {
                position: 0.22
                color: Qt.rgba(1, 1, 1, root.topStrength * 0.32)
            }

            GradientStop {
                position: 0.55
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, parent.height * 0.32)
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, root.bottomStrength)
            }
        }
    }
}
