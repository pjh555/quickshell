import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("AutostartPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Autostart"),
            "icon": "rocket_launch",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Applications"),
                    "icon": "apps",
                    "targetId": "general.autostart.section.user-autostart-applications"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Add application"),
                    "icon": "add_circle",
                    "targetId": "general.autostart.section.add-application-to-autostart"
                }
            ]
        }
    ]
}
