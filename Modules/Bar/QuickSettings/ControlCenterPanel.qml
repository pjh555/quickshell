import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Modules.QuickSettings
import qs.Services
import qs.Widgets.common
import "../../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property var screen: null
    property bool active: true
    signal closeRequested

    readonly property int columns: 2
    readonly property real gap: 8
    readonly property real panelPadding: 12
    readonly property bool recordingActive: RecordingService.isActive && !root.recordingSelecting
    readonly property bool recordingSelecting: RecordingService.transientState === "selecting"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.panelPadding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            MaterialSymbol {
                text: "tune"
                iconSize: 20
                color: Appearance.colors.colPrimary
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("控制中心")
                font.family: Fonts.ui
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
            IconButton {
                iconName: "open_in_new"
                iconSize: 18
                tooltipText: qsTr("打开完整设置")
                controlSize: 32
                onClicked: {
                    root.closeRequested();
                    ControlCenterService.open();
                }
            }
            IconButton {
                iconName: "close"
                iconSize: 18
                tooltipText: qsTr("关闭")
                controlSize: 32
                onClicked: root.closeRequested()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: sliders.implicitHeight

            QuickSliders {
                id: sliders
                width: parent.width
                screen: root.screen
                detailed: false
                verticalPadding: 10
                horizontalPadding: 12
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.columns
            columnSpacing: root.gap
            rowSpacing: root.gap

            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("Wi-Fi")
                subtitle: !NetworkService.available ? qsTr("不可用") : !NetworkService.wifiAvailable ? qsTr(
                                                                                                        "无无线网卡") :
                                                                                                    NetworkService.wifiEnabled
                                                                                                    ? (NetworkService.activeConnection
                                                                                                       || qsTr("已开启")) :
                                                                                                      qsTr("关闭")
                icon: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                toggled: NetworkService.wifiEnabled
                available: NetworkService.available && NetworkService.wifiAvailable
                onClicked: NetworkService.toggleWifi()
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("蓝牙")
                subtitle: !BluetoothService.available ? qsTr("不可用") : BluetoothService.enabled ? (
                                                                                                     BluetoothService.connectedName
                                                                                                     || qsTr("已开启")) :
                                                                                                 qsTr("关闭")
                icon: BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled
                                                   ? "bluetooth" : "bluetooth_disabled"
                toggled: BluetoothService.enabled
                available: BluetoothService.available
                onClicked: BluetoothService.toggle()
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("深色模式")
                subtitle: PersonalizationConfig.themeMode === "dark" ? qsTr("深色") : qsTr("浅色")
                icon: PersonalizationConfig.themeMode === "dark" ? "dark_mode" : "light_mode"
                toggled: PersonalizationConfig.themeMode === "dark"
                onClicked: ThemeService.setThemeMode(PersonalizationConfig.themeMode === "dark" ? "light" :
                                                                                                  "dark")
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("夜间模式")
                subtitle: !DisplayColor.available ? qsTr("不可用") : DisplayColor.preferences.nightEnabled ? qsTr(
                                                                                                              "%1 K").arg(
                                                                                                              DisplayColor.schedule.temperature) :
                                                                                                          qsTr("关闭")
                icon: "nightlight"
                toggled: DisplayColor.available && DisplayColor.preferences.nightEnabled
                available: DisplayColor.available
                onClicked: DisplayColor.setPreference("nightEnabled", !DisplayColor.preferences.nightEnabled)
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("免打扰")
                subtitle: UiPreferences.dndEnabled ? qsTr("已开启") : qsTr("关闭")
                icon: UiPreferences.dndEnabled ? "notifications_paused" : "notifications"
                toggled: UiPreferences.dndEnabled
                onClicked: UiPreferences.toggleDnd()
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                title: qsTr("麦克风")
                subtitle: Volume.sourceMuted ? qsTr("已静音") : qsTr("已开启")
                icon: Volume.sourceMuted ? "mic_off" : "mic"
                toggled: !Volume.sourceMuted
                onClicked: Volume.toggleSourceMute()
            }
            ControlTile {
                Layout.fillWidth: true
                Layout.columnSpan: root.columns
                Layout.preferredHeight: 54
                title: qsTr("台前调度")
                subtitle: StageManagerService.visible ? qsTr("已开启") : qsTr("在左侧显示其他窗口")
                icon: "view_sidebar"
                toggled: StageManagerService.visible
                available: StageManagerService.available
                onClicked: {
                    StageManagerService.toggle();
                    root.closeRequested();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 12
            color: Appearance.colors.colLayer1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 14

                Text {
                    text: "CPU " + Format.percent(SystemMonitorService.cpu.usagePercent, 0)
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 11
                }
                Text {
                    text: qsTr("内存 %1").arg(Format.percent(SystemMonitorService.memory.usagePercent, 0))
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 11
                }
                Text {
                    text: qsTr("磁盘 %1").arg(Format.percent(Format.rootDisk(
                                                               SystemMonitorService.disks).usagePercent, 0))
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 11
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: PowerService.present && PowerService.percentage >= 0 ? Math.round(
                                                                                     PowerService.percentage
                                                                                     * 100) + "%" : qsTr("电源")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 11
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 8

            ControlButton {
                Layout.fillWidth: true
                icon: "photo_camera"
                label: qsTr("截屏")
                available: ScreenshotService.available
                onClicked: {
                    root.closeRequested();
                    // Let the panel surface disappear before niri freezes the screen.
                    ScreenshotService.capture(250);
                }
            }
            ControlButton {
                Layout.fillWidth: true
                icon: root.recordingSelecting ? "close" : root.recordingActive ? "stop_circle" :
                                                                                 "screen_record"
                label: root.recordingSelecting ? qsTr("取消") : root.recordingActive ? qsTr("停止录制") : qsTr("录屏")
                selected: root.recordingActive
                danger: root.recordingActive
                onClicked: {
                    root.closeRequested();
                    if (root.recordingSelecting)
                        RecordingService.cancelSelection();
                    else if (root.recordingActive)
                        RecordingService.stop();
                    else
                        RecordingService.start("video", {
                                                   "audio": "none",
                                                   "fps": 60,
                                                   "output": UiPreferences.recordingVideoDirectory
                                               });
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            spacing: 10

            PowerAction {
                Layout.fillWidth: true
                icon: "restart_alt"
                label: qsTr("重启")
                onClicked: {
                    root.closeRequested();
                    PowerMenuService.request("reboot");
                }
            }
            PowerAction {
                Layout.fillWidth: true
                icon: "lock"
                label: qsTr("锁屏")
                onClicked: {
                    root.closeRequested();
                    PowerMenuService.request("lock");
                }
            }
            PowerAction {
                Layout.fillWidth: true
                icon: "power_settings_new"
                label: qsTr("关机")
                dangerous: true
                onClicked: {
                    root.closeRequested();
                    PowerMenuService.request("poweroff");
                }
            }
        }
    }

    onActiveChanged: root.syncSystemMonitor()
    Component.onCompleted: root.syncSystemMonitor()
    Component.onDestruction: SystemMonitorService.clearConsumer("control-center")

    function syncSystemMonitor() {
        if (root.active)
            SystemMonitorService.setConsumerModules("control-center", ["cpu", "memory", "disk"]);
        else
            SystemMonitorService.clearConsumer("control-center");
    }

    component ControlTile: Rectangle {
        id: tile

        property string title: ""
        property string subtitle: ""
        property string icon: ""
        property bool toggled: false
        property bool available: true
        signal clicked

        radius: 14
        color: tile.toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
        border.width: 1
        border.color: tile.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: tile.available ? 1 : 0.5

        MouseArea {
            anchors.fill: parent
            enabled: tile.available
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: tile.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tile.icon
                    iconSize: 18
                    color: tile.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: tile.title
                    color: tile.toggled ? Appearance.colors.colOnPrimaryContainer :
                                          Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: tile.subtitle
                    color: tile.toggled ? Appearance.colors.colOnPrimaryContainer :
                                          Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }

    component PowerAction: Item {
        id: action

        property string icon: ""
        property string label: ""
        property bool dangerous: false
        signal clicked

        implicitHeight: 74

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                width: 54
                height: 54
                radius: 27
                anchors.horizontalCenter: parent.horizontalCenter
                color: action.dangerous ? (mouse.pressed ? Appearance.colors.colErrorContainerActive :
                                                           mouse.containsMouse
                                                           ? Appearance.colors.colErrorContainerHover :
                                                             Appearance.colors.colErrorContainer) :
                                          mouse.pressed ? Appearance.colors.colLayer2Active :
                                                          mouse.containsMouse ? Appearance.colors.colLayer2 :
                                                                                Appearance.colors.colLayer1
                border.width: 1
                border.color: action.dangerous ? Appearance.colors.colError :
                                                 Appearance.colors.colLayer0Border

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: action.icon
                    iconSize: 22
                    color: action.dangerous ? Appearance.colors.colOnErrorContainer :
                                              Appearance.colors.colOnSurface
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: action.label
                color: action.dangerous ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }

    component ControlButton: Rectangle {
        id: button

        property string icon: ""
        property string label: ""
        property bool available: true
        property bool selected: false
        property bool danger: false
        signal clicked

        implicitHeight: 40
        radius: 12
        color: !button.available ? Appearance.colors.colLayer1 : button.danger ? (mouse.pressed
                                                                                  ? Appearance.colors.colErrorContainerActive :
                                                                                    mouse.containsMouse
                                                                                    ? Appearance.colors.colErrorContainerHover :
                                                                                      Appearance.colors.colErrorContainer) :
                                                                                 button.selected
                                                                                 ? Appearance.colors.colPrimaryContainer :
                                                                                   mouse.pressed
                                                                                   ? Appearance.colors.colLayer2Active :
                                                                                     mouse.containsMouse
                                                                                     ? Appearance.colors.colLayer2 :
                                                                                       Appearance.colors.colLayer1
        border.width: 1
        border.color: button.danger ? Appearance.colors.colError : button.selected ? Appearance.colors.colPrimary :
                                                                                     Appearance.colors.colLayer0Border
        opacity: button.available ? 1 : 0.5

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: button.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: button.icon
                iconSize: 17
                color: button.danger ? Appearance.colors.colOnErrorContainer : button.selected
                                       ? Appearance.colors.colOnPrimaryContainer :
                                         Appearance.colors.colOnSurface
            }
            Text {
                text: button.label
                color: button.danger ? Appearance.colors.colOnErrorContainer : button.selected
                                       ? Appearance.colors.colOnPrimaryContainer :
                                         Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
