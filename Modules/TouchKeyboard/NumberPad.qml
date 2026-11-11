pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

import "Layouts.js" as Layouts

Item {
    id: root

    property var style: null

    readonly property real gap: root.style ? root.style.gapX : 6
    readonly property real leftWidth: Math.max(52, Math.min(74, root.width * 0.10))
    readonly property real rightWidth: Math.max(60, Math.min(86, root.width * 0.12))
    readonly property real centerWidth: Math.max(120, root.width - root.leftWidth - root.rightWidth
                                                 - root.gap * 2)

    Row {
        anchors.fill: parent
        spacing: root.gap

        Item {
            id: leftColumn

            width: root.leftWidth
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: root.gap

                Repeater {
                    model: Layouts.numberPadLeft

                    delegate: KeyboardKey {
                        required property var modelData

                        width: leftColumn.width
                        height: (leftColumn.height - root.gap * 4) / 5
                        keyData: modelData
                        style: root.style
                        onActivated: (action, value) => TouchKeyboardService.press(action, value)
                    }
                }
            }
        }

        Item {
            id: centerColumn

            width: root.centerWidth
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: root.gap

                Repeater {
                    model: Layouts.numberPadCenterRows

                    delegate: Row {
                        id: numberRow

                        required property var modelData

                        readonly property real keyWidth: (centerColumn.width - root.gap * 2) / 3

                        width: centerColumn.width
                        height: (centerColumn.height - root.gap * 3) / 4
                        spacing: root.gap

                        Repeater {
                            model: numberRow.modelData

                            delegate: KeyboardKey {
                                required property var modelData

                                width: numberRow.keyWidth
                                height: numberRow.height
                                keyData: modelData
                                style: root.style
                                onActivated: (action, value) => TouchKeyboardService.press(action, value)
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: rightColumn

            width: root.rightWidth
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: root.gap

                Repeater {
                    model: Layouts.numberPadRight

                    delegate: KeyboardKey {
                        required property var modelData

                        width: rightColumn.width
                        height: (rightColumn.height - root.gap * 3) / 4
                        keyData: modelData
                        style: root.style
                        onActivated: (action, value) => TouchKeyboardService.press(action, value)
                    }
                }
            }
        }
    }
}
