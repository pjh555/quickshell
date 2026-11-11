import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services

// Agent Mission Control content. It intentionally has no panel chrome: the
// Agent chat panel supplies the glass background, header, close/back buttons
// and the shared 14px content margin so both modes look like one surface.
Item {
    id: root

    ListModel {
        id: agentModel
    }

    function syncModel() {
        const list = AgentFleetService.agents || [];
        for (let i = agentModel.count - 1; i >= 0; i--) {
            let found = false;
            for (let j = 0; j < list.length; j++) {
                if (String(list[j].id) === String(agentModel.get(i).agentId)) {
                    found = true;
                    break;
                }
            }
            if (!found)
                agentModel.remove(i);
        }
        for (let j = 0; j < list.length; j++) {
            const a = list[j];
            const row = {
                "agentId": String(a.id || ""),
                "kind": String(a.kind || ""),
                "name": String(a.name || a.kind || ""),
                "status": String(a.status || "idle"),
                "statusLabel": String(a.statusLabel || AgentFleetService.statusLabel(a.status)),
                "title": String(a.title || ""),
                "task": String(a.task || ""),
                "cwd": String(a.cwd || ""),
                "modelName": String(a.model || ""),
                "tokens": Number(a.tokens || 0),
                "cost": Number(a.cost || 0),
                "sessionId": String(a.sessionId || ""),
                "sessionPath": String(a.sessionPath || ""),
                "updatedAt": Number(a.updatedAt || 0),
                "active": a.active === true,
                "canChat": a.canChat === true,
                "pid": Number(a.pid || 0),
                "agentJson": JSON.stringify(a)
            };
            let index = -1;
            for (let i = 0; i < agentModel.count; i++) {
                if (String(agentModel.get(i).agentId) === row.agentId) {
                    index = i;
                    break;
                }
            }
            if (index >= 0)
                agentModel.set(index, row);
            else
                agentModel.insert(j, row);
        }
    }

    function sendPrompt() {
        const text = String(promptInput.text || "").trim();
        if (text === "")
            return;
        AgentService.openPanel();
        AgentService.send(text);
        promptInput.text = "";
        AgentFleetService.closePanel();
    }

    Connections {
        target: AgentFleetService

        function onAgentsChanged() {
            root.syncModel();
        }
    }

    Component.onCompleted: root.syncModel()

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { "label": "活动", "value": AgentFleetService.activeCount, "color": Appearance.colors.colPrimary },
                    { "label": "工作", "value": AgentFleetService.workingCount, "color": Appearance.colors.colPrimary },
                    { "label": "等待", "value": AgentFleetService.waitingCount, "color": Appearance.colors.colTertiary },
                    { "label": "错误", "value": AgentFleetService.errorCount, "color": Appearance.colors.colError }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: 9
                    color: Appearance.macos.macFill

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.color
                        }

                        Text {
                            text: modelData.label + " " + modelData.value
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Rectangle {
                width: 30
                height: 30
                radius: 9
                color: refreshMouse.containsMouse ? Appearance.macos.macFill : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 17
                    color: Appearance.colors.colOnSurfaceVariant
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AgentFleetService.refresh()
                }
            }
        }

        ListView {
            id: agentList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: agentModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width: agentList.width
                height: cardColumn.implicitHeight + 18
                radius: 12
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: active ? AgentFleetService.statusColor(status) : Appearance.macos.hairline

                ColumnLayout {
                    id: cardColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 8
                            color: Appearance.macos.macFill

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: AgentFleetService.statusIcon(kind)
                                iconSize: 15
                                color: AgentFleetService.statusColor(status)
                            }
                        }

                        Text {
                            text: name
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: AgentFleetService.statusColor(status)
                            }

                            Text {
                                text: statusLabel
                                color: AgentFleetService.statusColor(status)
                                font.family: Fonts.ui
                                font.pixelSize: 9
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: AgentFleetService.ago(updatedAt)
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: title || name
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }

                    Text {
                        Layout.fillWidth: true
                        text: task || qsTr("暂无任务详情")
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 9
                    }

                    Text {
                        Layout.fillWidth: true
                        text: [modelName, cwd,
                               tokens > 0 ? AgentFleetService.tokenText(tokens) + " tok" : "",
                               pid > 0 ? "pid " + pid : ""]
                              .filter(function (v) { return v !== ""; }).join(" · ")
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 8
                        opacity: 0.8
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Layout.topMargin: 1

                        Rectangle {
                            height: 24
                            width: viewLabel.implicitWidth + 18
                            radius: 7
                            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.1)
                            border.width: 1
                            border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.35)

                            Text {
                                id: viewLabel
                                anchors.centerIn: parent
                                text: qsTr("让 Clavis 看")
                                color: Appearance.colors.colPrimary
                                font.family: Fonts.ui
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AgentFleetService.askAbout(JSON.parse(agentJson))
                            }
                        }

                        Rectangle {
                            visible: kind !== "clavis"
                            height: 24
                            width: delegateLabel.implicitWidth + 18
                            radius: 7
                            color: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.1)
                            border.width: 1
                            border.color: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.35)

                            Text {
                                id: delegateLabel
                                anchors.centerIn: parent
                                text: qsTr("派活")
                                color: Appearance.colors.colTertiary
                                font.family: Fonts.ui
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AgentFleetService.delegateTo(JSON.parse(agentJson))
                            }
                        }

                        Rectangle {
                            height: 24
                            width: openLabel.implicitWidth + 18
                            radius: 7
                            color: openMouse.containsMouse ? Appearance.macos.macFill : "transparent"
                            border.width: 1
                            border.color: Appearance.macos.hairline

                            Text {
                                id: openLabel
                                anchors.centerIn: parent
                                text: kind === "clavis" ? qsTr("打开对话") : qsTr("目录")
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                font.pixelSize: 9
                            }

                            MouseArea {
                                id: openMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const agent = JSON.parse(agentJson);
                                    if (agent.kind === "clavis") {
                                        AgentService.openPanel();
                                        AgentFleetService.closePanel();
                                    } else {
                                        AgentFleetService.openAgent(agent);
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 9
            color: summaryMouse.containsMouse ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.14)
                                              : Appearance.macos.macFill
            border.width: 1
            border.color: summaryMouse.containsMouse ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.4)
                                                     : Appearance.macos.hairline

            Row {
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: "summarize"
                    iconSize: 15
                    color: Appearance.colors.colPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: qsTr("让 Clavis 汇总全部 Agent")
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: summaryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AgentFleetService.sendSummary()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 11
            color: Appearance.macos.macFill
            border.width: 1
            border.color: promptInput.activeFocus ? Appearance.colors.colPrimary : Appearance.macos.hairline

            TextInput {
                id: promptInput

                anchors.left: parent.left
                anchors.right: sendButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                height: parent.height - 10
                verticalAlignment: TextInput.AlignVCenter
                color: Appearance.colors.colOnSurface
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colOnPrimary
                font.family: Fonts.ui
                font.pixelSize: 13
                clip: true
                onAccepted: root.sendPrompt()
            }

            Text {
                anchors.left: promptInput.left
                anchors.verticalCenter: promptInput.verticalCenter
                text: qsTr("让 Clavis 派活或汇总…")
                visible: promptInput.text.length === 0
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 13
                opacity: 0.7
            }

            Rectangle {
                id: sendButton

                width: 40
                height: 40
                radius: 11
                anchors.right: parent.right
                anchors.rightMargin: -1
                anchors.verticalCenter: parent.verticalCenter
                color: sendMouse.containsMouse ? Appearance.colors.colPrimary : Appearance.macos.macFill

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "send"
                    iconSize: 19
                    color: sendMouse.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sendPrompt()
                }
            }
        }
    }
}
