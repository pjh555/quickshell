import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Dock"),
            "icon": "dock_to_bottom",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Appearance"),
                    "icon": "palette",
                    "source": "DockPage.qml",
                    "sectionId": "appearance",
                    "targetId": "general.dock.section.appearance"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Behavior"),
                    "icon": "touch_app",
                    "source": "DockPage.qml",
                    "sectionId": "behavior",
                    "targetId": "general.dock.section.behavior"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Window previews"),
                    "icon": "preview",
                    "source": "DockPage.qml",
                    "sectionId": "previews",
                    "targetId": "general.dock.section.previews"
                }
            ]
        }
    ]
}
