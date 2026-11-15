import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("DockPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Dock"),
            "icon": "dock_to_bottom",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Appearance"),
                    "icon": "palette",
                    "targetId": "general.dock.section.appearance"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Behavior"),
                    "icon": "touch_app",
                    "targetId": "general.dock.section.behavior"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Window previews"),
                    "icon": "preview",
                    "targetId": "general.dock.section.previews"
                }
            ]
        }
    ]
}
