import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Sidebars"),
            "icon": "side_navigation",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Sidebars"),
                    "icon": "side_navigation",
                    "source": "GeneralSidebarPage.qml",
                    "sectionId": "sidebars",
                    "targetId": "general.sidebar.section.sidebars"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Clock style"),
                    "icon": "schedule",
                    "source": "GeneralSidebarPage.qml",
                    "sectionId": "clock-style",
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
                    "source": "GeneralSidebarPage.qml",
                    "sectionId": "desktop-card-layout",
                    "targetId": "general.sidebar.section.desktop-card-layout"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "System cards"),
                    "icon": "widgets",
                    "source": "GeneralSidebarPage.qml",
                    "sectionId": "system-cards",
                    "targetId": "general.sidebar.section.system-cards"
                }
            ]
        }
    ]
}
