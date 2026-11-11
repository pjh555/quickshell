pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property var style: null

    component ToolbarPill: Rectangle {
        id: pill

        property var style: null
        property string label: ""
        property bool active: false
        property string accessibleName: ""

        signal clicked

        width: Math.max(30, pillLabel.implicitWidth + 14)
        height: 30
        radius: 8
        color: pillMouse.pressed ? (pill.style ? pill.style.candidatePressed : "#DDE5EA") : pill.active ? (
                                                                                                              pill.style
                                                                                                              ? pill.style.accentSoft :
                                                                                                                "#D6E9FF") :
                                                                                                          (pillMouse.containsMouse
                                                                                                           ? (pill.style
                                                                                                              ? pill.style.keyHover :
                                                                                                                "#F3F6F8") :
                                                                                                             (pill.style
                                                                                                              ? pill.style.candidate :
                                                                                                                "#FFFFFF"))
        border.width: 1
        border.color: pill.active ? (pill.style ? pill.style.accent : "#4DB6AC") : (pill.style
                                                                                    ? pill.style.keyBorder :
                                                                                      "#00000008")
        Accessible.name: pill.accessibleName
        Accessible.role: Accessible.Button
        Accessible.onPressAction: pill.clicked()

        Text {
            id: pillLabel

            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? (pill.style ? pill.style.accent : "#4DB6AC") : (pill.style ? pill.style.text :
                                                                                              "#1F1F1F")
            font.family: Fonts.ui
            font.pixelSize: 12
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
        }

        MouseArea {
            id: pillMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 6

        MaterialSymbol {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            visible: root.width > 560
            text: "keyboard"
            iconSize: 20
            color: root.style ? root.style.textSecondary : "#5F6368"
        }

        Flickable {
            id: candidateFlick

            Layout.fillWidth: true
            Layout.preferredHeight: 30
            contentWidth: candidateRow.width
            contentHeight: 30
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: candidateRow

                width: implicitWidth
                height: parent.height
                spacing: 4

                Rectangle {
                    width: preeditLabel.implicitWidth + 16
                    height: 28
                    radius: 7
                    color: root.style ? root.style.accentSoft : "#D6E9FF"
                    visible: TouchKeyboardService.composing && !TouchKeyboardService.rawCandidateVisible
                             && TouchKeyboardService.layoutMode !== "nine"

                    Text {
                        id: preeditLabel

                        anchors.centerIn: parent
                        text: TouchKeyboardService.preedit
                        color: root.style ? root.style.accent : "#4DB6AC"
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                }

                Text {
                    width: Math.max(0, candidateFlick.width - 90)
                    height: 30
                    visible: !TouchKeyboardService.composing || TouchKeyboardService.layoutMode === "nine"
                    text: qsTr("Touch keyboard")
                    color: root.style ? root.style.textSecondary : "#5F6368"
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Repeater {
                    model: TouchKeyboardService.layoutMode === "nine" ? [] :
                                                                        TouchKeyboardService.visibleCandidates.slice(
                                                                            0, 8)

                    delegate: Rectangle {
                        id: candidateButton

                        required property int index
                        required property string modelData

                        width: Math.max(36, Math.min(172, candidateText.implicitWidth + (candidateButton.index
                                                                                         < 9 ? 30 : 18)))
                        height: 28
                        radius: 7
                        color: candidateMouse.pressed ? (root.style ? root.style.candidatePressed : "#DDE5EA") :
                                                        (root.style ? root.style.candidate : "#FFFFFF")
                        border.width: 1
                        border.color: root.style ? root.style.keyBorder : "#00000008"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                visible: candidateButton.index < 9
                                text: candidateButton.index === TouchKeyboardService.rawCandidateIndex ? "EN" :
                                                                                                         candidateButton.index
                                                                                                         - (TouchKeyboardService.rawCandidateVisible
                                                                                                            ? 1 : 0)
                                                                                                         + 1
                                color: candidateButton.index === TouchKeyboardService.rawCandidateIndex ? (
                                                                                                              root.style
                                                                                                              ? root.style.accent :
                                                                                                                "#007AFF") :
                                                                                                          (root.style
                                                                                                           ? root.style.textMuted :
                                                                                                             "#80868B")
                                font.family: Fonts.numeric
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                id: candidateText

                                width: Math.max(10, candidateButton.width - 30)
                                text: candidateButton.modelData
                                elide: Text.ElideRight
                                color: root.style ? root.style.text : "#1F1F1F"
                                font.family: Fonts.ui
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                textFormat: Text.PlainText
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

                Text {
                    width: 14
                    height: 30
                    visible: TouchKeyboardService.candidatePending && TouchKeyboardService.layoutMode
                             !== "nine"
                    text: "…"
                    color: root.style ? root.style.textMuted : "#80868B"
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ToolbarPill {
            style: root.style
            label: TouchKeyboardService.layoutMode === "nine" ? "9" : "26"
            accessibleName: TouchKeyboardService.layoutMode === "nine" ? qsTr("Switch to QWERTY") : qsTr(
                                                                             "Switch to nine-key")
            onClicked: TouchKeyboardService.press("layout", "")
        }

        ToolbarPill {
            style: root.style
            label: "Fn"
            active: TouchKeyboardService.page === "keys"
            accessibleName: qsTr("Desktop keys")
            onClicked: TouchKeyboardService.press("keys", "")
        }

        ToolbarPill {
            style: root.style
            label: "中/EN"
            active: TouchKeyboardService.chinese
            accessibleName: qsTr("Switch language")
            onClicked: TouchKeyboardService.press("language", "")
        }

        IconButton {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            controlSize: 30
            iconSize: 18
            iconName: "keyboard_hide"
            iconColor: root.style ? root.style.textSecondary : "#5F6368"
            tooltipText: qsTr("Hide touch keyboard")
            onClicked: TouchKeyboardService.close()
        }
    }
}
