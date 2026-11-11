pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    property var style: null
    property var targetItem: null
    property var options: []
    property bool opened: false

    signal optionSelected(var option)

    anchors.fill: parent
    visible: root.opened
    z: 100

    function hide() {
        root.opened = false;
        root.targetItem = null;
        root.options = [];
    }

    function optionWidth(option) {
        const label = String(option && (option.label || option.value) || "");
        return Math.max(44, Math.min(92, 18 + label.length * 11));
    }

    function showFor(item, optionList) {
        if (!item || !optionList || optionList.length === 0)
            return;
        root.targetItem = item;
        root.options = optionList;
        root.opened = true;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Rectangle {
        id: bubble

        readonly property real bubbleWidth: {
            let width = 8;
            for (let index = 0; index < root.options.length; ++index)
            width += root.optionWidth(root.options[index]) + 6;
            return Math.min(root.width - 16, width);
        }
        readonly property real bubbleHeight: 56
        readonly property var anchorPoint: root.targetItem ? root.targetItem.mapToItem(root, 0, 0) : Qt.point(0,
                                                                                                              0)
        readonly property bool above: root.targetItem ? (anchorPoint.y + root.targetItem.height / 2
                                                         > root.height * 0.45) : true

        x: Math.max(8, Math.min(root.width - bubbleWidth - 8, anchorPoint.x + (root.targetItem
                                                                               ? root.targetItem.width : 0)
                                / 2 - bubbleWidth / 2))
        y: {
            if (!root.targetItem)
            return 8;
            return Math.max(8, Math.min(root.height - bubbleHeight - 8, above ? anchorPoint.y - bubbleHeight - 8 :
                                                                                anchorPoint.y
                                                                                + root.targetItem.height
                                                                                + 8));
        }
        width: bubbleWidth
        height: bubbleHeight
        radius: root.style ? root.style.popupRadius : 12
        color: root.style ? root.style.popupBackground : "#FFFFFF"
        border.width: 1
        border.color: root.style ? root.style.popupBorder : "#00000014"
        scale: root.opened ? 1 : 0.94

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.options

                delegate: Rectangle {
                    id: optionButton

                    required property var modelData

                    readonly property string optionLabel: String(modelData.label || modelData.value || "")

                    width: root.optionWidth(modelData)
                    height: 40
                    radius: 8
                    color: optionMouse.pressed ? (root.style ? root.style.candidatePressed : "#DDE5EA") :
                                                 "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: optionButton.optionLabel
                        color: root.style ? root.style.text : "#1F1F1F"
                        font.family: Fonts.ui
                        font.pixelSize: optionButton.optionLabel.length <= 2 ? 18 : 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: optionMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.optionSelected(optionButton.modelData);
                            root.hide();
                        }
                    }
                }
            }
        }
    }
}
