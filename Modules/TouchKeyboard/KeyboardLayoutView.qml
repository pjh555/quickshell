pragma ComponentBehavior: Bound

import QtQuick
import qs.Services

Item {
    id: root

    property var style: null
    property var rows: []

    function rowWeight(keys) {
        let total = 0;
        for (let index = 0; index < keys.length; ++index)
            total += Number(keys[index].weight || 1);
        return Math.max(1, total);
    }

    function keyActive(data) {
        if (data === null || data === undefined)
            return false;
        switch (data.action) {
        case "shift":
            return TouchKeyboardService.effectiveShift;
        case "ctrl":
            return TouchKeyboardService.ctrlLatch;
        case "alt":
            return TouchKeyboardService.altLatch;
        case "super":
            return TouchKeyboardService.superLatch;
        case "symbols":
            return TouchKeyboardService.page === "symbols";
        case "numbers":
            return TouchKeyboardService.page === "numbers";
        case "letters":
            return TouchKeyboardService.page === "letters";
        default:
            return false;
        }
    }

    function showFor(item, options) {
        popup.showFor(item, options);
    }

    Column {
        id: layoutColumn

        anchors.fill: parent
        spacing: root.style ? root.style.rowGap : 9

        Repeater {
            model: root.rows

            delegate: Row {
                id: keyRow

                required property var modelData

                readonly property var rowKeys: modelData
                readonly property real rowHeight: (layoutColumn.height - layoutColumn.spacing * Math.max(0,
                                                                                                         root.rows.length
                                                                                                         - 1)) / Math.max(
                                                      1, root.rows.length)

                width: layoutColumn.width
                height: Math.max(root.style ? root.style.minimumKeyHeight : 34, rowHeight)
                spacing: root.style ? root.style.gapX : 6

                Repeater {
                    model: keyRow.rowKeys

                    delegate: KeyboardKey {
                        id: key

                        required property var modelData

                        width: Math.max(1, (keyRow.width - keyRow.spacing * Math.max(0, keyRow.rowKeys.length
                                                                                     - 1)) * Number(
                                            modelData.weight || 1) / root.rowWeight(keyRow.rowKeys))
                        height: keyRow.height
                        keyData: modelData
                        style: root.style
                        popupHost: root
                        active: root.keyActive(modelData)
                        onActivated: (action, value) => TouchKeyboardService.press(action, value)
                    }
                }
            }
        }
    }

    KeyPopupLayer {
        id: popup

        anchors.fill: parent
        style: root.style
        onOptionSelected: option => TouchKeyboardService.press(option.action || "commit", option.value || "")
    }
}
