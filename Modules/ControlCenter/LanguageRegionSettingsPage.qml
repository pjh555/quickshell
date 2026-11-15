import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Language & region"),
            "icon": "language",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Language"),
                    "icon": "translate",
                    "source": "LanguageAndRegionPage.qml",
                    "sectionId": "language",
                    "targetId": "general.language-region.section.language"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Region & weather location"),
                    "icon": "location_on",
                    "source": "LanguageAndRegionPage.qml",
                    "sectionId": "region-weather-location",
                    "targetId": "general.language-region.section.region-weather-location"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Units"),
                    "icon": "straighten",
                    "source": "LanguageAndRegionPage.qml",
                    "sectionId": "units",
                    "targetId": "general.language-region.section.units"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Time & date"),
                    "icon": "schedule",
                    "source": "LanguageAndRegionPage.qml",
                    "sectionId": "time-date",
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
                    "source": "LanguageAndRegionPage.qml",
                    "sectionId": "weather-map",
                    "targetId": "general.language-region.section.weather-map"
                }
            ]
        }
    ]
}
