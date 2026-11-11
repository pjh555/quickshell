pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

import "Layouts.js" as Layouts

Item {
    id: root

    property var style: null
    property int categoryIndex: 0
    readonly property int columnCount: Math.max(6, Math.min(10, Math.floor(root.width / 42)))
    readonly property var currentEmojis: root.categoryIndex === 0 ? TouchKeyboardService.recentEmojis : (
                                                                        Layouts.emojiCategories[root.categoryIndex
                                                                                                - 1].emojis)
    readonly property var bottomKeys: [
        {
            "id": "letters",
            "label": "ABC",
            "action": "letters",
            "style": "special",
            "weight": 1.3
        },
        {
            "id": "space",
            "action": "space",
            "weight": 4.7,
            "style": "flat"
        },
        {
            "id": "backspace",
            "icon": "backspace",
            "action": "backspace",
            "repeat": true,
            "weight": 1.4,
            "style": "special"
        },
        {
            "id": "enter",
            "icon": "keyboard_return",
            "action": "enter",
            "weight": 2,
            "style": "accent",
            "round": true
        }
    ]

    function tabIcon(index) {
        return index === 0 ? "🕘" : Layouts.emojiCategories[index - 1].icon;
    }

    Component.onCompleted: {
        if (TouchKeyboardService.recentEmojis.length === 0)
        root.categoryIndex = 1;
    }

    function rowWeight(keys) {
        let total = 0;
        for (let index = 0; index < keys.length; ++index)
            total += Number(keys[index].weight || 1);
        return Math.max(1, total);
    }

    Column {
        anchors.fill: parent
        spacing: root.style ? root.style.toolbarGap : 6

        Item {
            id: categoryHost

            width: parent.width
            height: 34

            Row {
                id: categoryRow

                anchors.centerIn: parent
                height: 30
                spacing: 4

                Repeater {
                    model: Layouts.emojiCategories.length + 1

                    delegate: Rectangle {
                        id: categoryButton

                        required property int index

                        width: 42
                        height: 30
                        radius: 8
                        color: root.categoryIndex === index ? (root.style ? root.style.accentSoft : "#D6E9FF") :
                                                              (categoryMouse.containsMouse ? (root.style
                                                                                              ? root.style.keyHover :
                                                                                                "#F3F6F8") :
                                                                                             "transparent")
                        border.width: root.categoryIndex === index ? 1 : 0
                        border.color: root.style ? root.style.accent : "#4DB6AC"

                        Text {
                            anchors.centerIn: parent
                            text: root.tabIcon(categoryButton.index)
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: categoryMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.categoryIndex = categoryButton.index
                        }
                    }
                }
            }
        }

        GridView {
            id: emojiGrid

            width: parent.width
            height: parent.height - categoryHost.height - (root.style ? root.style.toolbarGap : 6) - bottomBar.height
                    - (root.style ? root.style.toolbarGap : 6)
            cellWidth: width / root.columnCount
            cellHeight: cellWidth
            model: root.currentEmojis
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            delegate: Item {
                id: emojiCell

                required property string modelData

                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 8
                    color: emojiMouse.pressed ? (root.style ? root.style.keyPressed : "#D8E0E5") : (
                                                    emojiMouse.containsMouse ? (root.style
                                                                                ? root.style.keyHover :
                                                                                  "#F3F6F8") : "transparent")
                }

                Text {
                    anchors.centerIn: parent
                    text: emojiCell.modelData
                    font.family: "Noto Color Emoji"
                    font.pixelSize: Math.min(31, emojiCell.width * 0.58)
                }

                MouseArea {
                    id: emojiMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        TouchKeyboardService.press("commit", emojiCell.modelData);
                        TouchKeyboardService.noteRecentEmoji(emojiCell.modelData);
                    }
                }
            }
        }

        Row {
            id: bottomBar

            readonly property real availableWidth: width - root.style.gapX * (root.bottomKeys.length - 1)

            width: parent.width
            height: 40
            spacing: root.style ? root.style.gapX : 6

            Repeater {
                model: root.bottomKeys

                delegate: KeyboardKey {
                    required property var modelData

                    width: Math.max(1, bottomBar.availableWidth * Number(modelData.weight || 1)
                                    / root.rowWeight(root.bottomKeys))
                    height: bottomBar.height
                    keyData: modelData
                    style: root.style
                    onActivated: (action, value) => TouchKeyboardService.press(action, value)
                }
            }
        }
    }
}
