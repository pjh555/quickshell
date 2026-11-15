import QtQuick
import qs.Services

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Appearance"),
            "icon": "palette",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Color scheme"),
                    "icon": "colors",
                    "value": PersonalizationConfig.themeMode === "light" ? qsTranslate("SettingsBusinessHub",
                                                                                       "Light") : qsTranslate(
                                                                               "SettingsBusinessHub", "Dark"),
                    "source": "ThemePage.qml",
                    "sectionId": "matugen-color-scheme",
                    "targetId": "theme.section.matugen-color-scheme"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Icons"),
                    "icon": "category",
                    "source": "ThemePage.qml",
                    "sectionId": "icon-theme",
                    "targetId": "theme.section.icon-theme"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Fonts"),
                    "icon": "font_download",
                    "source": "ThemePage.qml",
                    "sectionId": "fonts",
                    "targetId": "theme.section.fonts"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cursor"),
                    "icon": "mouse",
                    "source": "ThemePage.qml",
                    "sectionId": "cursor-theme",
                    "targetId": "theme.section.cursor-theme"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Interface"),
            "icon": "web_asset",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Settings window"),
                    "icon": "window",
                    "source": "ThemePage.qml",
                    "sectionId": "settings-window",
                    "targetId": "theme.section.settings-window"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Super key"),
                    "icon": "keyboard_command_key",
                    "source": "ThemePage.qml",
                    "sectionId": "super-key-appearance",
                    "targetId": "theme.section.super-key-appearance"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Lock screen"),
                    "icon": "lock",
                    "source": "ThemePage.qml",
                    "sectionId": "lock-screen",
                    "targetId": "theme.section.lock-screen"
                }
            ]
        }
    ]
}
