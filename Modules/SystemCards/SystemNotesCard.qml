pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool glassSurface: true
    property color foregroundColor: "#FFFFFF"
    property color secondaryForegroundColor: Qt.rgba(1, 1, 1, 0.78)
    property color accentColor: "#FFD60A"
    readonly property var items: Array.isArray(TodoService.list) ? TodoService.list.slice(0, 4) : []
    readonly property color rowHoverColor: Qt.rgba(1, 1, 1, 0.10)

    function addNote() {
        const text = noteInput.text.trim();
        if (text.length === 0)
            return;

        if (TodoService.addTask(text))
            noteInput.text = "";
    }

    Accessible.name: qsTr("Notes")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Appearance.rounding.small
                color: Qt.rgba(1, 1, 1, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "sticky_note_2"
                    iconSize: 18
                    color: root.accentColor
                    fill: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Notes")
                color: root.foregroundColor
                font.family: Fonts.ui
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                visible: TodoService.list.length > 0
                text: String(TodoService.list.length)
                color: root.secondaryForegroundColor
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.items.length === 0
            text: qsTr("No notes yet")
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: noteRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Appearance.rounding.small
                color: notePointer.containsMouse ? root.rowHoverColor : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    spacing: 6

                    MaterialSymbol {
                        text: noteRow.modelData.done ? "check_circle" : "radio_button_unchecked"
                        iconSize: 19
                        fill: noteRow.modelData.done ? 1 : 0
                        color: noteRow.modelData.done ? root.accentColor : root.secondaryForegroundColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: noteRow.modelData.content
                        color: noteRow.modelData.done ? root.secondaryForegroundColor : root.foregroundColor
                        font.family: Fonts.ui
                        font.pixelSize: 14
                        font.strikeout: noteRow.modelData.done
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: notePointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TodoService.setDone(noteRow.index, !noteRow.modelData.done)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Appearance.rounding.normal
            color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.24)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 2
                spacing: 4

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: noteInput

                        anchors.fill: parent
                        color: root.foregroundColor
                        selectionColor: root.accentColor
                        selectedTextColor: "#FFFFFF"
                        font.family: Fonts.ui
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onAccepted: root.addNote()
                    }

                    Text {
                        anchors.fill: parent
                        visible: noteInput.text.length === 0
                        text: qsTr("Add a note")
                        color: root.secondaryForegroundColor
                        font: noteInput.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                IconButton {
                    iconName: "add"
                    accessibleName: qsTr("Add note")
                    controlSize: 30
                    iconSize: 18
                    enabled: noteInput.text.trim().length > 0
                    iconColor: root.foregroundColor
                    normalContainerColor: "transparent"
                    selectedContainerColor: "transparent"
                    normalHoverStateLayerColor: Qt.rgba(1, 1, 1, 0.14)
                    normalPressedStateLayerColor: Qt.rgba(1, 1, 1, 0.20)
                    onClicked: root.addNote()
                }
            }
        }
    }
}
