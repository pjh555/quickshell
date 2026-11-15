import QtQuick
import qs.Services

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Bluetooth"),
            "icon": "settings_bluetooth",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Saved devices"),
                    "icon": "devices",
                    "value": BluetoothService.connectedDevices.length > 0 ? String(
                                                                                BluetoothService.connectedDevices.length) :
                                                                            "",
                    "source": "ConnectedDevicesPage.qml",
                    "sectionId": "saved-devices",
                    "targetId": "general.connected-devices.section.saved-devices"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Bluetooth adapter"),
                    "icon": "settings_bluetooth",
                    "source": "ConnectedDevicesPage.qml",
                    "sectionId": "bluetooth-adapter",
                    "targetId": "general.connected-devices.section.bluetooth-adapter"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Advanced settings"),
                    "icon": "tune",
                    "source": "ConnectedDevicesPage.qml",
                    "sectionId": "advanced-settings",
                    "targetId": "general.connected-devices.section.advanced-settings"
                }
            ]
        }
    ]
}
