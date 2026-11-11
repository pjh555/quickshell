import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Modules.WindowOverview
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    property var targetScreen: null

    readonly property string screenName: root.targetScreen ? String(root.targetScreen.name) : ""
    readonly property bool overviewActive: WindowManagerService.visible && root.targetScreen && String(
                                               root.targetScreen.name)
                                           === WindowManagerService.targetScreenName
    readonly property int count: WindowManagerService.count
    readonly property int columns: count <= 1 ? 1 : count <= 4 ? 2 : count <= 9 ? 3 : 4
    readonly property int rows: Math.max(1, Math.ceil(count / columns))
    readonly property real margin: Math.max(24, Math.min(72, width * 0.035))
    readonly property real gap: Math.max(12, Math.min(24, width * 0.014))
    readonly property real headerHeight: Math.max(58, Math.min(76, height * 0.07))
    readonly property real topZone: Math.max(92, height * 0.12)
    readonly property real gridTop: root.headerHeight + root.margin
    readonly property real gridWidth: Math.max(1, width - root.margin * 2)
    readonly property real gridHeight: Math.max(1, height - root.gridTop - root.margin)
    readonly property real cellWidth: count === 0 ? root.gridWidth : Math.max(1, (root.gridWidth - root.gap * (
                                                                                      root.columns - 1))
                                                                              / root.columns)
    readonly property real cellHeight: count === 0 ? root.gridHeight : Math.max(1, (root.gridHeight
                                                                                    - root.gap * (root.rows
                                                                                                  - 1)) / root.rows)

    property int dragIndex: -1
    property int hoverIndex: -1
    property bool hoverFullscreen: false

    readonly property bool dragging: root.dragIndex >= 0

    function cellX(index) {
        return root.margin + (index % root.columns) * (root.cellWidth + root.gap);
    }
    function cellY(index) {
        return root.gridTop + Math.floor(index / root.columns) * (root.cellHeight + root.gap);
    }
    function pointForScene(sceneX, sceneY) {
        return content.mapFromItem(null, sceneX, sceneY);
    }
    function beginDrag(index) {
        root.dragIndex = index;
        root.hoverIndex = index;
        root.hoverFullscreen = false;
        content.forceActiveFocus();
    }
    function updateDrag(index, point) {
        if (index !== root.dragIndex)
            return;
        root.hoverFullscreen = point.y < root.topZone;
        if (root.hoverFullscreen) {
            root.hoverIndex = -1;
            return;
        }
        const column = Math.floor((point.x - root.margin) / Math.max(1, root.cellWidth + root.gap));
        const row = Math.floor((point.y - root.gridTop) / Math.max(1, root.cellHeight + root.gap));
        const candidate = row * root.columns + column;
        root.hoverIndex = column >= 0 && column < root.columns && row >= 0 && row < root.rows && point.x
                >= root.margin && point.y >= root.gridTop && candidate >= 0 && candidate < root.count
                ? candidate : -1;
    }
    function finishDrag(index, point) {
        if (index !== root.dragIndex)
            return;
        root.updateDrag(index, point);
        const source = WindowManagerService.windows[index] || null;
        if (source) {
            if (root.hoverFullscreen) {
                WindowManagerService.toggleFullscreen(source.id);
            } else if (root.hoverIndex >= 0 && root.hoverIndex !== index) {
                const target = WindowManagerService.windows[root.hoverIndex];
                if (target)
                    WindowManagerService.swapWindows(source.id, target.id);
            }
        }
        root.dragIndex = -1;
        root.hoverIndex = -1;
        root.hoverFullscreen = false;
    }
    function activate(index) {
        const window = WindowManagerService.windows[index];
        if (window)
            WindowManagerService.focusWindow(window.id);
    }
    function fullscreenAt(index) {
        const window = WindowManagerService.windows[index];
        if (window)
            WindowManagerService.toggleFullscreen(window.id);
    }

    screen: root.targetScreen
    // The overview is intentionally unmapped when closed. An always-mapped
    // fullscreen Overlay layer can turn an empty input Region into a full
    // input surface on some wlroots versions, swallowing every desktop click.
    visible: root.targetScreen !== null && root.overviewActive
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clavis-window-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.overviewActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region {
        id: activeInput

        item: content
    }
    Region {
        id: inactiveInput
    }
    mask: root.overviewActive ? activeInput : inactiveInput

    Item {
        id: content

        anchors.fill: parent
        visible: root.overviewActive
        focus: true

        Keys.onEscapePressed: {
            WindowManagerService.close();
            event.accepted = true;
        }

        Rectangle {
            id: overviewBackground

            anchors.fill: parent
            color: BlurService.backgroundColor(Appearance.macos.background)
        }

        Rectangle {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.headerHeight
            color: BlurService.backgroundColor(Appearance.macos.surfaceElevated)
            border.width: 1
            border.color: Appearance.macos.hairline

            Column {
                anchors.left: parent.left
                anchors.leftMargin: root.margin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: qsTr("窗口布局")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    text: WindowManagerService.niriBackend ? qsTr("拖动窗口到顶部全屏") : qsTr("拖动窗口交换位置，拖到顶部使其全屏")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 12
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.margin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.count === 0 ? "" : qsTr("%1 个窗口").arg(root.count)
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 88
                    height: 38
                    radius: 19
                    color: doneMouse.pressed ? Appearance.m3colors.m3primaryContainer :
                                               Appearance.macos.macFill

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("完成")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: doneMouse
                        anchors.fill: parent
                        onClicked: WindowManagerService.close()
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            z: -1

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: WindowManagerService.close()
            }
        }

        Item {
            id: cardsLayer

            anchors.fill: parent

            Repeater {
                model: WindowManagerService.windows

                delegate: WindowOverviewCard {
                    required property int index
                    required property var modelData

                    overview: root
                    windowData: modelData
                    windowIndex: index
                    cellX: root.cellX(index)
                    cellY: root.cellY(index)
                    cellWidth: root.cellWidth
                    cellHeight: root.cellHeight
                    opacity: root.dragging && root.dragIndex === index ? 0.92 : 1
                    z: root.dragging && root.dragIndex === index ? 50 : 1
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: root.count === 0 && !WindowManagerService.loading
            spacing: 10

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "web_asset_off"
                iconSize: 44
                color: Appearance.colors.colOnSurfaceVariant
            }
            Text {
                text: qsTr("当前没有可管理的窗口")
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 16
            }
            Text {
                text: WindowManagerService.error
                visible: WindowManagerService.error !== ""
                color: Appearance.colors.colError
                font.family: Fonts.ui
                font.pixelSize: 12
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.topZone
            visible: root.dragging
            color: root.hoverFullscreen ? Appearance.applyAlpha(Appearance.macos.accent, 0.20) :
                                          Appearance.macos.macFill

            border.width: root.hoverFullscreen ? 2 : 1
            border.color: root.hoverFullscreen ? Appearance.macos.accent : Appearance.macos.hairline
            radius: 0
            enabled: false
            z: 80

            Text {
                anchors.centerIn: parent
                text: root.hoverFullscreen ? qsTr("松开以全屏显示") : qsTr("拖到此处全屏")
                color: root.hoverFullscreen ? Appearance.macos.accent : Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 15
                font.weight: Font.Medium
            }
        }

        Item {
            id: loadingIndicator

            anchors.centerIn: parent
            visible: WindowManagerService.loading
            width: 140
            height: 36

            Text {
                anchors.centerIn: parent
                text: qsTr("正在准备窗口缩略图…")
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 13
            }
        }
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: overviewBackground
        radius: 0
    }

    Connections {
        target: WindowManagerService
        function onVisibleChanged() {
            if (WindowManagerService.visible && root.overviewActive)
                content.forceActiveFocus();
        }
    }
}
