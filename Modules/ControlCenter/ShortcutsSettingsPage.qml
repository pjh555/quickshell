import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Keyboard shortcuts"),
            "icon": "keyboard",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "All shortcuts"),
                    "icon": "keyboard",
                    "source": "ShortcutsPage.qml",
                    "initialProperties": {
                        "category": "all"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Assigned shortcuts"),
                    "icon": "check_circle",
                    "source": "ShortcutsPage.qml",
                    "initialProperties": {
                        "category": "assigned"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Managed shortcuts"),
                    "icon": "admin_panel_settings",
                    "source": "ShortcutsPage.qml",
                    "initialProperties": {
                        "category": "managed"
                    }
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Unassigned shortcuts"),
                    "icon": "add_circle",
                    "source": "ShortcutsPage.qml",
                    "initialProperties": {
                        "category": "unassigned"
                    }
                }
            ]
        }
    ]
}
