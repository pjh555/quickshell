import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Visual effects"),
            "icon": "blur_on",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Background transparency and blur"),
                    "icon": "blur_on",
                    "source": "GeneralEffectsPage.qml",
                    "sectionId": "background",
                    "targetId": "general.effects.section.background"
                }
            ]
        }
    ]
}
