import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("SpotlightPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Spotlight"),
            "icon": "search",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Applications"),
                    "icon": "apps",
                    "targetId": "general.spotlight.section.applications"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Web search"),
                    "icon": "language",
                    "targetId": "general.spotlight.section.web-search"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Clipboard"),
                    "icon": "content_paste",
                    "targetId": "general.spotlight.section.clipboard"
                }
            ]
        }
    ]
}
