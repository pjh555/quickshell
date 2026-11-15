import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("ShortcutsPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Keyboard shortcuts"),
            "icon": "keyboard",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "All shortcuts"),
                    "icon": "keyboard",
                    "initialProperties": {
                        "category": "all"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Assigned shortcuts"),
                    "icon": "check_circle",
                    "initialProperties": {
                        "category": "assigned"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Managed shortcuts"),
                    "icon": "admin_panel_settings",
                    "initialProperties": {
                        "category": "managed"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Unassigned shortcuts"),
                    "icon": "add_circle",
                    "initialProperties": {
                        "category": "unassigned"
                    }
                }
            ]
        }
    ]
}
