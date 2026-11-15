import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Autostart"),
            "icon": "rocket_launch",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Applications"),
                    "icon": "apps",
                    "source": "AutostartPage.qml",
                    "sectionId": "user-autostart-applications",
                    "targetId": "general.autostart.section.user-autostart-applications"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Add application"),
                    "icon": "add_circle",
                    "source": "AutostartPage.qml",
                    "sectionId": "add-application-to-autostart",
                    "targetId": "general.autostart.section.add-application-to-autostart"
                }
            ]
        }
    ]
}
