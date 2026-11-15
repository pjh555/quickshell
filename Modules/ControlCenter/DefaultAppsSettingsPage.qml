import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("DefaultAppsPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Default applications"),
            "icon": "apps",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Internet"),
                    "icon": "language",
                    "targetId": "general.default-apps.section.internet"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Utilities"),
                    "icon": "construction",
                    "targetId": "general.default-apps.section.utilities"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Documents"),
                    "icon": "description",
                    "targetId": "general.default-apps.section.documents"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Multimedia"),
                    "icon": "perm_media",
                    "targetId": "general.default-apps.section.multimedia"
                }
            ]
        }
    ]
}
