import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services

// In-surface pet action menu. Layer-shell surfaces cannot host xdg_popups, so
// this is a normal Item rendered inside the pet's own full-screen surface.
// AgentPet expands its input region while this menu is open.
Item {
    id: root

    property var entries: []
    property string menuTitle: ""
    property int menuWidth: 218
    readonly property int headerHeight: 27
    readonly property real contentHeight: headerHeight + menuColumn.implicitHeight + 12

    signal actionTriggered(string action)

    width: menuWidth
    height: contentHeight
    visible: false
    z: 50

    function open() {
        visible = true;
        closeTimer.restart();
    }

    function close() {
        visible = false;
        closeTimer.stop();
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: BlurService.solidBackgroundColor(Appearance.colors.colLayer0)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Item {
            id: header

            width: parent.width
            height: root.headerHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.menuTitle || qsTr("Actions")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: 22
                height: 22
                radius: 6
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                color: closeMouse.containsMouse ? Appearance.colors.colLayer2Base : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 13
                    color: Appearance.colors.colOnSurfaceVariant
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Column {
            id: menuColumn

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 1

            Repeater {
                model: root.entries

                delegate: Item {
                    width: menuColumn.width
                    height: modelData.separator === true ? 7 : 32

                    Rectangle {
                        visible: modelData.separator === true
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 8
                        x: 4
                        height: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    Rectangle {
                        id: row

                        anchors.fill: parent
                        visible: modelData.separator !== true
                        radius: 8
                        color: rowMouse.containsMouse ? Appearance.colors.colLayer2Base : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 7

                            MaterialSymbol {
                                visible: modelData.icon !== undefined && modelData.icon !== ""
                                text: modelData.icon || ""
                                iconSize: 15
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label || ""
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                root.actionTriggered(modelData.action || modelData.id || "");
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer

        interval: 12000
        onTriggered: root.close()
    }
}
