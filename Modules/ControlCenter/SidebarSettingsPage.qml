import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("GeneralSidebarPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Sidebars"),
            "icon": "side_navigation",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Sidebars"),
                    "icon": "side_navigation",
                    "targetId": "general.sidebar.section.sidebars"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Clock style"),
                    "icon": "schedule",
                    "targetId": "general.sidebar.section.clock-style"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Cards"),
            "icon": "widgets",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Desktop card layout"),
                    "icon": "dashboard_customize",
                    "targetId": "general.sidebar.section.desktop-card-layout"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "System cards"),
                    "icon": "widgets",
                    "targetId": "general.sidebar.section.system-cards"
                }
            ]
        }
    ]
}
