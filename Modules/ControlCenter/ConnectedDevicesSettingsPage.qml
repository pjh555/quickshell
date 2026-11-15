import QtQuick
import qs.Services

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("ConnectedDevicesPage.qml")
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
                    "targetId": "general.connected-devices.section.saved-devices"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Bluetooth adapter"),
                    "icon": "settings_bluetooth",
                    "targetId": "general.connected-devices.section.bluetooth-adapter"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Advanced settings"),
                    "icon": "tune",
                    "targetId": "general.connected-devices.section.advanced-settings"
                }
            ]
        }
    ]
}
