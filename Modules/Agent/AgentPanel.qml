import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// The native top-bar Agent surface. It is a layer-shell overlay, not a toplevel
// application: opening it from the top bar never creates a taskbar/window-manager
// item and it follows the active Niri output.
PanelWindow {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property bool open: AgentService.panelOpen
    readonly property bool fleetMode: AgentFleetService.panelOpen
    readonly property color panelColor: BlurService.backgroundColor(Appearance.colors.colLayer0)

    screen: root.targetScreen
    visible: root.open
    color: "transparent"
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-agent"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: backdrop
    }

    onVisibleChanged: {
        if (!visible)
            AgentFleetService.panelOpen = false;
    }

    MouseArea {
        id: backdrop

        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: AgentService.closePanel()
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: event => {
                                  AgentService.closePanel();
                                  event.accepted = true;
                              }

        Rectangle {
            id: panel

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 62
            anchors.rightMargin: 18
            width: Math.min(500, parent.width - 36)
            height: Math.min(660, parent.height - 90)
            radius: 24
            color: root.panelColor
            border.width: 1
            border.color: Appearance.macos.glassBorder

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 9
                        color: Appearance.colors.colPrimaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.fleetMode ? "radar" : "smart_toy"
                            iconSize: 19
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.fleetMode ? qsTr("Agent Mission Control")
                                                 : (AgentService.config.name || qsTr("Clavis Agent"))
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.fleetMode
                                  ? AgentFleetService.summaryText + qsTr(" · 自动刷新")
                                  : (AgentService.online ? (AgentService.config.model || qsTr("已连接"))
                                                         : qsTr("后端未连接"))

                            color: root.fleetMode ? Appearance.colors.colOnSurfaceVariant
                                                  : (AgentService.online ? Appearance.colors.colOnSurfaceVariant
                                                                         : Appearance.colors.colError)
                            font.family: Fonts.ui
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        controlSize: 30
                        iconSize: 17
                        iconName: root.fleetMode ? "arrow_back" : "radar"
                        tooltipText: root.fleetMode ? qsTr("返回对话") : qsTr("Agent 监控中心")
                        onClicked: root.fleetMode ? AgentFleetService.closePanel()
                                                  : AgentFleetService.openPanel()
                    }

                    IconButton {
                        controlSize: 30
                        iconSize: 17
                        iconName: "settings"
                        tooltipText: qsTr("Agent 设置")
                        onClicked: AgentService.openSettings()
                    }

                    IconButton {
                        controlSize: 30
                        iconSize: 17
                        iconName: "add_comment"
                        tooltipText: qsTr("新对话")
                        visible: !root.fleetMode
                        onClicked: AgentService.newSession()
                    }

                    IconButton {
                        controlSize: 30
                        iconSize: 17
                        iconName: "close"
                        tooltipText: qsTr("关闭")
                        onClicked: AgentService.closePanel()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Appearance.macos.hairline
                }

                AgentFleetView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.fleetMode
                }

                ListView {
                    id: messages
                    visible: !root.fleetMode

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: AgentService.messages
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: Qt.callLater(positionViewAtEnd)

                    delegate: Item {
                        required property int index
                        required property var modelData

                        width: messages.width
                        // The delegate must reserve the bubble's real height.
                        // Using Rectangle.implicitHeight here was 0 and made
                        // every message paint on top of the previous one.
                        height: bubble.height + 2

                        Rectangle {
                            id: bubble

                            width: Math.min(messages.width - 8, 430)
                            height: bubbleColumn.implicitHeight + 16
                            x: modelData.role === "user" ? parent.width - width - 2 : 2
                            radius: 12
                            color: modelData.role === "user" ? Appearance.colors.colPrimaryContainer :
                                                               modelData.role === "error"
                                                               ? Appearance.applyAlpha(
                                                                     Appearance.colors.colError, 0.14) :
                                                                 Appearance.colors.colLayer1
                            border.width: 1
                            border.color: modelData.role === "user" ? Appearance.colors.colPrimary :
                                                                      Appearance.macos.hairline

                            Column {
                                id: bubbleColumn

                                anchors.centerIn: parent
                                width: Math.min(messages.width - 40, 400)
                                spacing: 6

                                Text {
                                    id: bubbleText

                                    width: parent.width
                                    visible: modelData.text !== ""
                                    text: modelData.text
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    color: modelData.role === "user"
                                           ? Appearance.colors.colOnPrimaryContainer : modelData.role
                                             === "error" ? Appearance.colors.colError :
                                                           Appearance.colors.colOnSurface
                                    font.family: Fonts.ui
                                    font.pixelSize: 13
                                }

                                Flow {
                                    width: parent.width
                                    visible: modelData.files && modelData.files.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: modelData.files || []

                                        Rectangle {
                                            id: fileChip

                                            required property var modelData

                                            height: 24
                                            width: Math.min(fileChipRow.implicitWidth + 22, 230)
                                            radius: 8
                                            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.1)
                                            border.width: 1
                                            border.color: Appearance.applyAlpha(Appearance.colors.colPrimary,
                                                                                0.35)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: AgentService.openFile(fileChip.modelData.path)
                                            }

                                            Row {
                                                id: fileChipRow

                                                anchors.centerIn: parent
                                                spacing: 4

                                                MaterialSymbol {
                                                    text: "description"
                                                    iconSize: 12
                                                    color: Appearance.colors.colPrimary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: fileChip.modelData.name
                                                    width: Math.min(implicitWidth, 170)
                                                    elide: Text.ElideMiddle
                                                    color: Appearance.colors.colOnSurface
                                                    font.family: Fonts.ui
                                                    font.pixelSize: 11
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                MaterialSymbol {
                                                    text: "open_in_new"
                                                    iconSize: 12
                                                    color: Appearance.colors.colPrimary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    visible: modelData.attachments && modelData.attachments.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: modelData.attachments || []

                                        Rectangle {
                                            id: chip

                                            required property string modelData

                                            height: 22
                                            width: Math.min(chipRow.implicitWidth + 22, 190)
                                            radius: 8
                                            color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.08)

                                            Row {
                                                id: chipRow

                                                anchors.centerIn: parent
                                                spacing: 4

                                                MaterialSymbol {
                                                    text: "attach_file"
                                                    iconSize: 12
                                                    color: Appearance.colors.colOnSurfaceVariant
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: chip.modelData
                                                    width: Math.min(implicitWidth, 150)
                                                    elide: Text.ElideMiddle
                                                    color: Appearance.colors.colOnSurfaceVariant
                                                    font.family: Fonts.ui
                                                    font.pixelSize: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }
                                }
                                Column {
                                    width: parent.width
                                    visible: modelData.artifacts && modelData.artifacts.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: modelData.artifacts || []

                                        Rectangle {
                                            id: artifactCard

                                            required property var modelData

                                            readonly property bool previewVisible: modelData.kind === "image"
                                                                                   || (modelData.kind
                                                                                       === "video" && !
                                                                                       !modelData.preview) || (
                                                                                       modelData.kind
                                                                                       === "webpage" && !
                                                                                       !modelData.html)

                                            width: parent.width
                                            height: artifactColumn.implicitHeight + 12
                                            radius: 10
                                            color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.06)
                                            border.width: 1
                                            border.color: Appearance.macos.hairline

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: AgentService.openFile(artifactCard.modelData.path)
                                            }

                                            Column {
                                                id: artifactColumn

                                                anchors.centerIn: parent
                                                width: parent.width - 12
                                                spacing: 4

                                                Item {
                                                    width: parent.width
                                                    height: artifactCard.previewVisible ? (
                                                                                              artifactCard.modelData.kind
                                                                                              === "webpage"
                                                                                              ? 190 : 150) : 0
                                                    visible: artifactCard.previewVisible

                                                    MaterialSymbol {
                                                        text: artifactCard.modelData.kind === "image"
                                                              ? "broken_image" : "movie"
                                                        iconSize: 28
                                                        color: Appearance.colors.colOnSurfaceVariant
                                                        anchors.centerIn: parent
                                                        visible: (artifactCard.modelData.kind === "image"
                                                                  || artifactCard.modelData.kind === "video")
                                                                 && previewImage.status === Image.Error
                                                    }

                                                    Image {
                                                        id: previewImage

                                                        anchors.fill: parent
                                                        source: artifactCard.modelData.kind === "video"
                                                                ? encodeURI("file://"
                                                                            + artifactCard.modelData.preview) :
                                                                  encodeURI("file://"
                                                                            + artifactCard.modelData.path)
                                                        sourceSize.height: 300
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: artifactCard.modelData.kind === "webpage"
                                                        radius: 8
                                                        color: "#f8f8f6"
                                                        border.width: 1
                                                        border.color: Appearance.macos.hairline
                                                        clip: true

                                                        Text {
                                                            anchors.fill: parent
                                                            anchors.margins: 10
                                                            textFormat: Text.RichText
                                                            text: artifactCard.modelData.html || ""
                                                            wrapMode: Text.Wrap
                                                            color: "#202124"
                                                            font.family: Fonts.ui
                                                            font.pixelSize: 12
                                                            clip: true
                                                        }
                                                    }

                                                    MaterialSymbol {
                                                        text: "play_circle"
                                                        iconSize: 34
                                                        color: Appearance.colors.colOnSurface
                                                        anchors.centerIn: parent
                                                        visible: artifactCard.modelData.kind === "video"
                                                                 && previewImage.status === Image.Ready
                                                    }
                                                }

                                                Row {
                                                    width: parent.width
                                                    spacing: 5

                                                    MaterialSymbol {
                                                        text: artifactCard.modelData.kind === "image"
                                                              ? "image" : artifactCard.modelData.kind
                                                                === "video" ? "movie" :
                                                                              artifactCard.modelData.kind
                                                                              === "audio" ? "graphic_eq" :
                                                                                            artifactCard.modelData.kind
                                                                                            === "document"
                                                                                            ? "description" :
                                                                                              artifactCard.modelData.kind
                                                                                              === "webpage"
                                                                                              ? "language" :
                                                                                                "draft"
                                                        iconSize: 14
                                                        color: Appearance.colors.colPrimary
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        text: artifactCard.modelData.name
                                                        width: parent.width - sizeText.width - 40
                                                        elide: Text.ElideMiddle
                                                        color: Appearance.colors.colOnSurface
                                                        font.family: Fonts.ui
                                                        font.pixelSize: 11
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        id: sizeText

                                                        text: root.formatArtifactSize(
                                                                  artifactCard.modelData.bytes)
                                                        color: Appearance.colors.colOnSurfaceVariant
                                                        font.family: Fonts.ui
                                                        font.pixelSize: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    MaterialSymbol {
                                                        text: "open_in_new"
                                                        iconSize: 12
                                                        color: Appearance.colors.colPrimary
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    visible: !!artifactCard.modelData.excerpt
                                                    text: artifactCard.modelData.excerpt
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.Wrap
                                                    color: Appearance.colors.colOnSurfaceVariant
                                                    font.family: Fonts.ui
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: AgentService.busy && !root.fleetMode
                    spacing: 8

                    MaterialSymbol {
                        text: "progress_activity"
                        iconSize: 16
                        color: Appearance.colors.colPrimary
                    }
                    Text {
                        text: qsTr("Agent 正在思考…")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: AgentService.error !== "" && !root.fleetMode
                    height: visible ? 34 : 0
                    radius: 9
                    color: Appearance.applyAlpha(Appearance.colors.colError, 0.12)
                    border.width: 1
                    border.color: Appearance.applyAlpha(Appearance.colors.colError, 0.4)

                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: AgentService.error
                        color: Appearance.colors.colError
                        font.family: Fonts.ui
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: AgentService.pendingAttachments.length > 0 && !root.fleetMode
                    spacing: 6

                    Repeater {
                        model: AgentService.pendingAttachments

                        Rectangle {
                            id: pendingChip

                            required property var modelData
                            required property int index

                            height: 26
                            width: pendingRow.implicitWidth + 34
                            radius: 9
                            color: Appearance.macos.macFill
                            border.width: 1
                            border.color: Appearance.macos.hairline

                            Row {
                                id: pendingRow

                                anchors.centerIn: parent
                                spacing: 5

                                MaterialSymbol {
                                    text: "attach_file"
                                    iconSize: 13
                                    color: Appearance.colors.colOnSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: pendingChip.modelData.name
                                    width: Math.min(implicitWidth, 160)
                                    elide: Text.ElideMiddle
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Fonts.ui
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MaterialSymbol {
                                text: "close"
                                iconSize: 12
                                color: Appearance.colors.colOnSurfaceVariant
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AgentService.removeAttachment(pendingChip.index)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: !root.fleetMode
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 11
                        color: Appearance.macos.macFill
                        border.width: 1
                        border.color: input.activeFocus ? Appearance.colors.colPrimary :
                                                          Appearance.macos.hairline

                        TextInput {
                            id: input

                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Appearance.colors.colOnSurface
                            selectionColor: Appearance.colors.colPrimary
                            selectedTextColor: Appearance.colors.colOnPrimary
                            font.family: Fonts.ui
                            font.pixelSize: 13
                            clip: true
                            enabled: AgentService.online && !AgentService.busy
                            onAccepted: root.submit()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: {
                                if (AgentService.voiceState === "listening")
                                    return AgentService.voicePartial || qsTr("Listening… pause to send");
                                if (!AgentService.online)
                                    return qsTr("Configure the Agent to start chatting");
                                return qsTr("Ask the Agent…");
                            }
                            color: AgentService.voiceState === "listening" ? Appearance.colors.colPrimary :
                                                                             Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: 13
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 11
                        color: Appearance.macos.macFill

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "attach_file"
                            iconSize: 19
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AgentService.requestAttachmentPick()
                        }
                    }

                    Rectangle {
                        id: voiceButton

                        readonly property bool listening: AgentService.voiceState === "listening"
                        readonly property bool speaking: AgentService.voiceState === "speaking"

                        width: 40
                        height: 40
                        radius: 11
                        color: listening ? Appearance.colors.colError : Appearance.macos.macFill

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: parent.listening ? "graphic_eq" : (parent.speaking ? "stop" : "mic")
                            iconSize: 19
                            color: voiceButton.listening ? Appearance.colors.colOnPrimary :
                                                           Appearance.colors.colOnSurfaceVariant
                        }

                        SequentialAnimation on opacity {
                            running: voiceButton.listening
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1
                                to: 0.55
                                duration: 550
                            }
                            NumberAnimation {
                                from: 0.55
                                to: 1
                                duration: 550
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (voiceButton.listening)
                                    AgentService.stopVoice();
                                else if (voiceButton.speaking)
                                    AgentService.stopSpeaking();
                                else
                                    AgentService.startVoice();
                            }
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 11
                        color: AgentService.busy || !AgentService.online ? Appearance.macos.macFill :
                                                                           Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: AgentService.busy ? "hourglass_top" : "send"
                            iconSize: 19
                            color: AgentService.busy || !AgentService.online
                                   ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submit()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.fleetMode
                    text: {
                        const traceCount = AgentService.lastTrace.length;
                        if (traceCount > 0 && AgentService.lastUsage.total_tokens)
                            return qsTr("已执行 %1 个电脑操作 · %2 tokens").arg(traceCount).arg(
                                        AgentService.lastUsage.total_tokens);
                        if (traceCount > 0)
                            return qsTr("已执行 %1 个电脑操作").arg(traceCount);
                        if (AgentService.lastUsage.total_tokens)
                            return qsTr("本次 %1 tokens").arg(AgentService.lastUsage.total_tokens);
                        return qsTr("本地服务 · 配置保存在设置");
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: panel
        radius: 24
    }

    DropArea {
        anchors.fill: parent
        onEntered: drag => drag.accept(Qt.CopyAction)
        onDropped: drop => {
                       if (drop.hasUrls)
                       drop.urls.forEach(url => AgentService.addAttachmentPath(url));
                   }
    }

    function formatArtifactSize(bytes) {
        const value = Number(bytes) || 0;
        if (value >= 1048576)
            return (value / 1048576).toFixed(1) + " MB";
        if (value >= 1024)
            return Math.round(value / 1024) + " KB";
        return value + " B";
    }

    function submit() {
        if (input.text.trim() === "")
            return;
        const value = input.text;
        input.text = "";
        AgentService.send(value);
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(() => input.forceActiveFocus());
            Qt.callLater(() => messages.positionViewAtEnd());
        }
    }
}
