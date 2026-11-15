import QtQuick
import qs.Services

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("NetworkPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Connections"),
            "icon": "wifi",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Wi-Fi"),
                    "icon": "wifi",
                    "value": NetworkService.available && NetworkService.wifiEnabled
                             ? NetworkService.activeConnection : "",
                    "targetId": "general.network.section.wi-fi"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Wired connections"),
                    "icon": "lan",
                    "targetId": "general.network.section.wired-connections"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Details"),
            "icon": "info",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Connection information"),
                    "icon": "info",
                    "targetId": "general.network.section.connection-information"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Other settings"),
                    "icon": "tune",
                    "targetId": "general.network.section.other-settings"
                }
            ]
        }
    ]
}
