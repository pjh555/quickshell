import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Default applications"),
            "icon": "apps",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Internet"),
                    "icon": "language",
                    "source": "DefaultAppsPage.qml",
                    "sectionId": "internet",
                    "targetId": "general.default-apps.section.internet"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Utilities"),
                    "icon": "construction",
                    "source": "DefaultAppsPage.qml",
                    "sectionId": "utilities",
                    "targetId": "general.default-apps.section.utilities"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Documents"),
                    "icon": "description",
                    "source": "DefaultAppsPage.qml",
                    "sectionId": "documents",
                    "targetId": "general.default-apps.section.documents"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Multimedia"),
                    "icon": "perm_media",
                    "source": "DefaultAppsPage.qml",
                    "sectionId": "multimedia",
                    "targetId": "general.default-apps.section.multimedia"
                }
            ]
        }
    ]
}
