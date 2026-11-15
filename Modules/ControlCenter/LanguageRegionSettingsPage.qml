import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("LanguageAndRegionPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Language & region"),
            "icon": "language",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Language"),
                    "icon": "translate",
                    "targetId": "general.language-region.section.language"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Region & weather location"),
                    "icon": "location_on",
                    "targetId": "general.language-region.section.region-weather-location"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Units"),
                    "icon": "straighten",
                    "targetId": "general.language-region.section.units"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Time & date"),
                    "icon": "schedule",
                    "targetId": "general.language-region.section.time-date"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Weather"),
            "icon": "map",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Weather map"),
                    "icon": "map",
                    "targetId": "general.language-region.section.weather-map"
                }
            ]
        }
    ]
}
