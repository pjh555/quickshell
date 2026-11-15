import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Services"),
            "icon": "cloud",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Map and weather services"),
                    "icon": "map",
                    "source": "AdvancedPage.qml",
                    "sectionId": "map-and-weather-services",
                    "targetId": "advanced.section.map-and-weather-services"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cloud storage"),
                    "icon": "cloud_sync",
                    "source": "AdvancedPage.qml",
                    "sectionId": "cloud-storage",
                    "targetId": "advanced.section.cloud-storage"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Generation"),
            "icon": "data_object",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Matugen templates"),
                    "icon": "code",
                    "source": "AdvancedPage.qml",
                    "sectionId": "matugen-template-generation",
                    "targetId": "advanced.section.matugen-template-generation"
                }
            ]
        }
    ]
}
