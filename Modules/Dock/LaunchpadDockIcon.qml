import QtQuick

// A Dock-sized Launchpad mark: a silver tile containing the familiar 3x3
// grid of colourful application squares. Drawn in QML so it stays sharp at
// every Dock magnification level and follows the icon's exact slot size.
Item {
    id: root

    readonly property real cellSize: width * 0.20
    readonly property real cellGap: width * 0.06
    readonly property real gridSize: cellSize * 3 + cellGap * 2
    readonly property var colors: ["#FF5F57", "#FEBC2E", "#28C840", "#0A84FF", "#BF5AF2", "#FF9F0A", "#64D2FF",
        "#FF375F", "#30D158"]

    Rectangle {
        anchors.fill: parent
        radius: width * 0.225
        border.width: Math.max(1, width * 0.012)
        border.color: "#B6B6BE"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#FFFFFF"
            }
            GradientStop {
                position: 1
                color: "#E6E6EC"
            }
        }
    }

    Repeater {
        model: 9
        delegate: Rectangle {
            required property int index
            width: root.cellSize
            height: width
            radius: width * 0.28
            x: (root.width - root.gridSize) / 2 + (index % 3) * (root.cellSize + root.cellGap)
            y: (root.height - root.gridSize) / 2 + Math.floor(index / 3) * (root.cellSize + root.cellGap)
            color: root.colors[index]
        }
    }
}
