pragma ComponentBehavior: Bound

import "./SystemCardPalette.js" as CardPalette
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    property bool glassSurface: true
    property color foregroundColor: "#FFFFFF"
    property color secondaryForegroundColor: Qt.rgba(1, 1, 1, 0.78)
    property color accentColor: "#FFFFFF"
    readonly property var recent: {
        const source = NotificationManager.list;
        const items = source && typeof source.slice === "function" ? source.slice() : [];
        return items.sort((first, second) => second.receivedAt - first.receivedAt).slice(0, 3);
    }
    readonly property color rowHoverColor: Qt.rgba(1, 1, 1, 0.10)

    function appIconSource(icon) {
        const value = String(icon || "");
        if (value === "")
            return "";

        if (value.startsWith("/"))
            return "file://" + value;

        if (value.startsWith("file://") || value.startsWith("image://"))
            return value;

        return Quickshell.iconPath(value, "image-missing");
    }

    function appColor(notification) {
        const name = notification && notification.appName ? notification.appName : notification
                                                            ? notification.summary : "";
        return CardPalette.appColorFor(String(name || ""));
    }

    function openNotifications() {
        WidgetState.dashboardSidebarView = "info";
        WidgetState.dashboardSidebarOpen = true;
    }

    Accessible.name: qsTr("Notifications")

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
                    text: "notifications"
                    iconSize: 18
                    color: root.accentColor
                    fill: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Notifications")
                color: root.foregroundColor
                font.family: Fonts.ui
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                visible: NotificationManager.list.length > 0
                text: String(NotificationManager.list.length)
                color: root.secondaryForegroundColor
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.recent.length === 0
            text: qsTr("No notifications")
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.recent

            delegate: Rectangle {
                id: notifRow

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Appearance.rounding.normal
                color: rowPointer.containsMouse ? root.rowHoverColor : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: width / 2
                        color: root.appColor(notifRow.modelData)

                        ThemeIcon {
                            anchors.fill: parent
                            anchors.margins: 9
                            iconSource: root.appIconSource(notifRow.modelData.appIcon)
                            asynchronous: true
                            visible: iconSource.toString() !== ""
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: root.appIconSource(notifRow.modelData.appIcon) === ""
                            text: "notifications"
                            iconSize: 18
                            color: "#FFFFFF"
                            fill: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: notifRow.modelData.summary
                            color: root.foregroundColor
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: notifRow.modelData.body
                            textFormat: Text.StyledText
                            color: root.secondaryForegroundColor
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: notifRow.modelData.appName
                            color: root.secondaryForegroundColor
                            opacity: 0.75
                            font.family: Fonts.ui
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: rowPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openNotifications()
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: viewAllLabel.implicitWidth + Appearance.spacing.medium * 2
            Layout.preferredHeight: 32
            radius: height / 2
            color: viewAllPointer.containsMouse ? root.rowHoverColor : "transparent"

            Text {
                id: viewAllLabel

                anchors.centerIn: parent
                text: qsTr("View all")
                color: root.accentColor
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: viewAllPointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openNotifications()
            }
        }
    }
}
