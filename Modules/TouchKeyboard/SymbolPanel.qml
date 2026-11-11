pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

import "SymbolData.js" as SymbolData

Item {
    id: root

    property var style: null
    property int categoryIndex: 0

    readonly property int tabCount: SymbolData.categories.length + 1
    readonly property int columnCount: Math.max(8, Math.min(15, Math.floor(root.width / 50)))
    readonly property var currentSymbols: root.categoryIndex === 0 ? TouchKeyboardService.recentSymbols : (
                                                                         SymbolData.categories[root.categoryIndex
                                                                                               - 1].symbols)

    Component.onCompleted: {
        if (TouchKeyboardService.recentSymbols.length === 0)
        root.categoryIndex = 1;
    }

    function tabName(index) {
        return index === 0 ? "🕘" : SymbolData.categories[index - 1].name;
    }

    function selectCategory(index) {
        root.categoryIndex = index;
        symbolGrid.positionViewAtBeginning();
    }

    Column {
        anchors.fill: parent
        spacing: root.style ? root.style.toolbarGap : 6

        Row {
            id: topRow

            width: parent.width
            height: 34
            spacing: root.style ? root.style.gapX : 6

            KeyboardKey {
                width: 34
                height: 34
                keyData: ({
                              "id": "back",
                              "icon": "arrow_back",
                              "action": "letters"
                          })
                style: root.style
                onActivated: (action, value) => TouchKeyboardService.press(action, value)
            }

            Flickable {
                id: tabFlick

                width: parent.width - 34 - (root.style ? root.style.gapX : 6)
                height: 34
                contentWidth: tabRow.width
                contentHeight: 34
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: tabRow

                    width: implicitWidth
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: root.tabCount

                        delegate: Rectangle {
                            id: tabButton

                            required property int index

                            width: 44
                            height: 34
                            radius: 8
                            color: root.categoryIndex === tabButton.index ? (root.style ? root.style.accentSoft :
                                                                                          "#D6E9FF") : (
                                                                                tabMouse.containsMouse ? (
                                                                                                             root.style
                                                                                                             ? root.style.keyHover :
                                                                                                               "#F3F6F8") :
                                                                                                         "transparent")
                            border.width: root.categoryIndex === tabButton.index ? 1 : 0
                            border.color: root.style ? root.style.accent : "#007AFF"

                            Text {
                                anchors.centerIn: parent
                                text: root.tabName(tabButton.index)
                                color: root.categoryIndex === tabButton.index ? (root.style
                                                                                 ? root.style.accent :
                                                                                   "#007AFF") : (root.style
                                                                                                 ? root.style.textSecondary :
                                                                                                   "#6E6E73")
                                font.family: Fonts.ui
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: tabMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectCategory(tabButton.index)
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - topRow.height - bottomRow.height - (root.style ? root.style.toolbarGap :
                                                                                     6) * 2

            GridView {
                id: symbolGrid

                anchors.fill: parent
                cellWidth: width / root.columnCount
                cellHeight: cellWidth
                model: root.currentSymbols
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                delegate: Item {
                    id: symbolCell

                    required property string modelData

                    width: symbolGrid.cellWidth
                    height: symbolGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: root.style ? root.style.keyRadius : 9
                        color: symbolMouse.pressed ? (root.style ? root.style.keyPressed : "#E5E5EA") : (
                                                         symbolMouse.containsMouse ? (root.style
                                                                                      ? root.style.keyHover :
                                                                                        "#F3F6F8") : (
                                                                                         root.style
                                                                                         ? root.style.key :
                                                                                           "#FFFFFF"))
                        border.width: 1
                        border.color: root.style ? root.style.keyBorder : "#0000001A"

                        Text {
                            anchors.centerIn: parent
                            text: symbolCell.modelData
                            color: root.style ? root.style.text : "#1D1D1F"
                            font.family: Fonts.ui
                            font.pixelSize: Math.max(14, Math.min(22, symbolCell.width * 0.42))
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: symbolMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            TouchKeyboardService.noteRecentSymbol(symbolCell.modelData);
                            TouchKeyboardService.press("commit", symbolCell.modelData);
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.currentSymbols.length === 0
                text: qsTr("No recent symbols")
                color: root.style ? root.style.textMuted : "#8E8E93"
                font.family: Fonts.ui
                font.pixelSize: 14
            }
        }

        Row {
            id: bottomRow

            width: parent.width
            height: 38

            Item {
                width: parent.width - deleteButton.width
                height: parent.height
            }

            KeyboardKey {
                id: deleteButton

                width: 84
                height: 38
                keyData: ({
                              "id": "delete",
                              "icon": "backspace",
                              "action": "backspace",
                              "repeat": true
                          })
                style: root.style
                onActivated: (action, value) => TouchKeyboardService.press(action, value)
            }
        }
    }
}
