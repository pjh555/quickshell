import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("GeneralEffectsPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Visual effects"),
            "icon": "blur_on",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Background transparency and blur"),
                    "icon": "blur_on",
                    "targetId": "general.effects.section.background"
                }
            ]
        }
    ]
}
