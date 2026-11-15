import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Spotlight"),
            "icon": "search",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Applications"),
                    "icon": "apps",
                    "source": "SpotlightPage.qml",
                    "sectionId": "applications",
                    "targetId": "general.spotlight.section.applications"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Web search"),
                    "icon": "language",
                    "source": "SpotlightPage.qml",
                    "sectionId": "web-search",
                    "targetId": "general.spotlight.section.web-search"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Clipboard"),
                    "icon": "content_paste",
                    "source": "SpotlightPage.qml",
                    "sectionId": "clipboard",
                    "targetId": "general.spotlight.section.clipboard"
                }
            ]
        }
    ]
}
