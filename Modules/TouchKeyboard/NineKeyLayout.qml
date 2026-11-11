pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

import "Layouts.js" as Layouts

Item {
    id: root

    property var style: null

    readonly property real gap: root.style ? root.style.gapX : 6
    readonly property real leftWidth: Math.max(92, Math.min(168, root.width * 0.23))
    readonly property real rightWidth: Math.max(62, Math.min(90, root.width * 0.13))
    readonly property real centerWidth: Math.max(120, root.width - root.leftWidth - root.rightWidth
                                                 - root.gap * 2)
    readonly property var rightKeys: [
        {
            "id": "backspace",
            "icon": "backspace",
            "action": "backspace",
            "repeat": true,
            "swipeUp": {
                "action": "clear"
            },
            "style": "special"
        },
        {
            "id": "clear",
            "icon": "clear",
            "action": "clear",
            "style": "special"
        },
        {
            "id": "enter",
            "icon": "keyboard_return",
            "action": "enter",
            "style": "accent",
            "round": true
        }
    ]
    readonly property var punctuationKeys: [
        {
            "id": "t9_comma",
            "label": "，",
            "action": "commit",
            "value": "，",
            "style": "special"
        },
        {
            "id": "t9_period",
            "label": "。",
            "action": "commit",
            "value": "。",
            "style": "special"
        },
        {
            "id": "t9_question",
            "label": "？",
            "action": "commit",
            "value": "？",
            "style": "special"
        },
        {
            "id": "t9_exclamation",
            "label": "！",
            "action": "commit",
            "value": "！",
            "style": "special"
        }
    ]

    function showFor(item, options) {
        popup.showFor(item, options);
    }

    Column {
        anchors.fill: parent
        spacing: root.gap

        Flickable {
            id: segmentFlick

            width: parent.width
            height: visible ? 26 : 0
            visible: TouchKeyboardService.nineKeySegments.length > 1
            contentWidth: segmentRow.width
            contentHeight: 26
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            WheelHandler {
                onWheel: event => {
                    const maximum = Math.max(0, segmentFlick.contentWidth - segmentFlick.width);
                    segmentFlick.contentX = Math.max(0, Math.min(maximum, segmentFlick.contentX
                                                                 - event.angleDelta.y));
                }
            }

            Row {
                id: segmentRow

                width: implicitWidth
                height: 26
                spacing: 3

                Repeater {
                    model: TouchKeyboardService.nineKeySegments

                    delegate: Rectangle {
                        id: segmentButton

                        required property int index
                        required property var modelData

                        width: Math.max(44, segmentLabel.implicitWidth + 12)
                        height: 26
                        radius: 6
                        color: TouchKeyboardService.nineKeySegmentIndex === index ? (root.style
                                                                                     ? root.style.accentSoft :
                                                                                       "#D6E9FF") : (
                                                                                        segmentMouse.containsMouse
                                                                                        ? (root.style
                                                                                           ? root.style.keyHover :
                                                                                             "#F3F6F8") : (
                                                                                              root.style
                                                                                              ? root.style.candidate :
                                                                                                "#FFFFFF"))
                        border.width: 1
                        border.color: TouchKeyboardService.nineKeySegmentIndex === index ? (root.style
                                                                                            ? root.style.accent :
                                                                                              "#007AFF") : (
                                                                                               root.style
                                                                                               ? root.style.keyBorder :
                                                                                                 "#0000001A")

                        Text {
                            id: segmentLabel

                            anchors.centerIn: parent
                            text: String(segmentButton.modelData.text || "")
                            color: TouchKeyboardService.nineKeySegmentIndex === segmentButton.index ? (
                                                                                                          root.style
                                                                                                          ? root.style.accent :
                                                                                                            "#007AFF") :
                                                                                                      (root.style
                                                                                                       ? root.style.textSecondary :
                                                                                                         "#6E6E73")
                            font.family: Fonts.ui
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: segmentMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TouchKeyboardService.selectNineKeySegment(segmentButton.index)
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - segmentFlick.height - (segmentFlick.visible ? root.gap : 0)

            Row {
                anchors.fill: parent
                spacing: root.gap

                Item {
                    id: leftColumn

                    width: root.leftWidth
                    height: parent.height

                    Rectangle {
                        id: preeditPill

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: visible ? 22 : 0
                        radius: 6
                        color: root.style ? root.style.accentSoft : "#D6E9FF"
                        visible: TouchKeyboardService.composing
                                 && TouchKeyboardService.nineKeySegments.length <= 1

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            text: TouchKeyboardService.preedit
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            color: root.style ? root.style.accent : "#4DB6AC"
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    ListView {
                        id: candidateList

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: preeditPill.bottom
                        anchors.topMargin: 4
                        anchors.bottom: punctuationGrid.top
                        anchors.bottomMargin: 4
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: TouchKeyboardService.visibleCandidates

                        delegate: Rectangle {
                            id: candidateButton

                            required property int index
                            required property string modelData

                            width: ListView.view ? ListView.view.width : leftColumn.width
                            height: 32
                            radius: 7
                            color: candidateMouse.pressed ? (root.style ? root.style.candidatePressed :
                                                                          "#DDE5EA") : (root.style
                                                                                        ? root.style.candidate :
                                                                                          "#FFFFFF")
                            border.width: 1
                            border.color: root.style ? root.style.keyBorder : "#00000008"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                spacing: 5

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: candidateButton.index + 1
                                    color: root.style ? root.style.textMuted : "#80868B"
                                    font.family: Fonts.numeric
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20
                                    text: String(candidateButton.modelData || "")
                                    elide: Text.ElideRight
                                    color: root.style ? root.style.text : "#1F1F1F"
                                    font.family: Fonts.ui
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: candidateMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: TouchKeyboardService.commitCandidate(candidateButton.index)
                            }
                        }
                    }

                    Grid {
                        id: punctuationGrid

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        columns: 2
                        spacing: 4

                        Repeater {
                            model: root.punctuationKeys

                            delegate: KeyboardKey {
                                required property var modelData

                                width: (leftColumn.width - 4) / 2
                                height: 29
                                keyData: modelData
                                style: root.style
                                popupHost: root
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
                            model: Layouts.nineDigitRows

                            delegate: Row {
                                id: digitRow

                                required property var modelData

                                readonly property real keyWidth: (centerColumn.width - root.gap * 2) / 3

                                width: centerColumn.width
                                height: (centerColumn.height - root.gap * 3) / 4
                                spacing: root.gap

                                Repeater {
                                    model: digitRow.modelData

                                    delegate: KeyboardKey {
                                        required property var modelData

                                        width: digitRow.keyWidth
                                        height: digitRow.height
                                        keyData: modelData
                                        style: root.style
                                        popupHost: root
                                        onActivated: (action, value) => TouchKeyboardService.press(action,
                                                                                                   value)
                                    }
                                }
                            }
                        }

                        Row {
                            id: bottomRow

                            readonly property real totalWeight: 3.3
                            readonly property real availableWidth: centerColumn.width - root.gap * 2

                            width: centerColumn.width
                            height: (centerColumn.height - root.gap * 3) / 4
                            spacing: root.gap

                            Repeater {
                                model: Layouts.nineBottomRow

                                delegate: KeyboardKey {
                                    required property var modelData

                                    width: Math.max(1, bottomRow.availableWidth * Number(modelData.weight
                                                                                         || 1) / bottomRow.totalWeight)
                                    height: bottomRow.height
                                    keyData: modelData
                                    style: root.style
                                    popupHost: root
                                    onActivated: (action, value) => TouchKeyboardService.press(action, value)
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
                            model: root.rightKeys

                            delegate: KeyboardKey {
                                required property var modelData

                                width: rightColumn.width
                                height: (rightColumn.height - root.gap * 2) / 3
                                keyData: modelData
                                style: root.style
                                popupHost: root
                                onActivated: (action, value) => TouchKeyboardService.press(action, value)
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: TouchKeyboardService

        function onNineKeySegmentsChanged() {
            segmentFlick.contentX = 0;
        }
    }

    KeyPopupLayer {
        id: popup

        anchors.fill: parent
        style: root.style
        onOptionSelected: option => TouchKeyboardService.press(option.action || "commit", option.value || "")
    }
}
