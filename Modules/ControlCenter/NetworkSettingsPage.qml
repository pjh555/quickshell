import QtQuick
import qs.Services

SettingsBusinessHub {
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
                    "source": "NetworkPage.qml",
                    "sectionId": "wi-fi",
                    "targetId": "general.network.section.wi-fi"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Wired connections"),
                    "icon": "lan",
                    "source": "NetworkPage.qml",
                    "sectionId": "wired-connections",
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
                    "source": "NetworkPage.qml",
                    "sectionId": "connection-information",
                    "targetId": "general.network.section.connection-information"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Other settings"),
                    "icon": "tune",
                    "source": "NetworkPage.qml",
                    "sectionId": "other-settings",
                    "targetId": "general.network.section.other-settings"
                }
            ]
        }
    ]
}
