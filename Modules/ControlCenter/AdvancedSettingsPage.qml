import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("AdvancedPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Services"),
            "icon": "cloud",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Map and weather services"),
                    "icon": "map",
                    "targetId": "advanced.section.map-and-weather-services"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cloud storage"),
                    "icon": "cloud_sync",
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
                    "targetId": "advanced.section.matugen-template-generation"
                }
            ]
        }
    ]
}
