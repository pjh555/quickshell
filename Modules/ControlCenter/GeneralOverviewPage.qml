import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    signal sectionRequested(string section)
    signal navigateRequested(string pageId)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(680, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        SettingsSection {
            id: searchSection0

            Layout.fillWidth: true
            title: searchAnchor0.title
            iconName: "dashboard"

            SettingsSearchAnchor {
                id: searchAnchor0

                target: searchSection0
                declaration:
                    '{"id":"general.section.interface","route":"general","title":"Interface","context":"GeneralOverviewPage","icon":"settings","aliases":[],"source":"GeneralOverviewPage.qml"}'
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "wallpaper"
                text: SpotlightCatalog.title("wallpaper")
                onClicked: root.navigateRequested("wallpaper")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "palette"
                text: SpotlightCatalog.title("theme")
                onClicked: root.navigateRequested("theme")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                text: SpotlightCatalog.title("general.effects")
                onClicked: root.sectionRequested("effects")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "toggle_off"
                text: SpotlightCatalog.title("keystone")
                onClicked: root.navigateRequested("keystone")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "dock_to_bottom"
                text: SpotlightCatalog.title("general.bar")
                onClicked: root.sectionRequested("bar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "dock_to_bottom"
                text: SpotlightCatalog.title("general.dock")
                onClicked: root.sectionRequested("dock")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                text: SpotlightCatalog.title("general.sidebar")
                onClicked: root.sectionRequested("sidebar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "search"
                text: "Spotlight"
                showDivider: false
                onClicked: root.sectionRequested("spotlight")
            }
        }

        SettingsSection {
            id: searchSection1

            Layout.fillWidth: true
            title: searchAnchor1.title
            iconName: "settings_suggest"

            SettingsSearchAnchor {
                id: searchAnchor1

                target: searchSection1
                declaration:
                    '{"id":"general.section.system","route":"general","title":"System","context":"GeneralOverviewPage","icon":"settings","aliases":[],"source":"GeneralOverviewPage.qml"}'
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "monitor"
                text: SpotlightCatalog.title("general.displays")
                onClicked: root.sectionRequested("displays")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "wifi"
                text: SpotlightCatalog.title("general.network")
                description: NetworkService.available ? NetworkService.activeConnection : qsTr(
                                                            "Network unavailable")
                onClicked: root.sectionRequested("network")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "devices_other"
                text: SpotlightCatalog.title("general.connected-devices")
                description: {
                    if (!BluetoothService.available)
                        return qsTr("Bluetooth unavailable");
                    if (!BluetoothService.enabled)
                        return qsTr("Bluetooth is off");
                    if (BluetoothService.connectedDevices.length === 1)
                        return BluetoothService.connectedDevices[0].name;
                    if (BluetoothService.connectedDevices.length > 1)
                        return qsTr("%1 devices connected").arg(BluetoothService.connectedDevices.length);
                    return "";
                }
                onClicked: root.sectionRequested("connected-devices")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "keyboard"
                text: SpotlightCatalog.title("general.shortcuts")
                onClicked: root.sectionRequested("shortcuts")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "language"
                text: SpotlightCatalog.title("general.language-region")
                showDivider: false
                onClicked: root.sectionRequested("language-region")
            }
        }

        SettingsSection {
            id: searchSection2

            Layout.fillWidth: true
            title: searchAnchor2.title
            iconName: "apps"

            SettingsSearchAnchor {
                id: searchAnchor2

                target: searchSection2
                declaration:
                    '{"id":"general.section.applications","route":"general","title":"Applications","context":"GeneralOverviewPage","icon":"settings","aliases":[],"source":"GeneralOverviewPage.qml"}'
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "smart_toy"
                text: SpotlightCatalog.title("agent")
                onClicked: root.navigateRequested("agent")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "android"
                text: SpotlightCatalog.title("android")
                onClicked: root.navigateRequested("android")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "rocket_launch"
                text: SpotlightCatalog.title("general.autostart")
                onClicked: root.sectionRequested("autostart")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "apps"
                text: SpotlightCatalog.title("general.default-apps")
                showDivider: false
                onClicked: root.sectionRequested("default-apps")
            }
        }
    }
}
