import QtQuick
import qs.Services

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("ThemePage.qml")
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
                    "targetId": "theme.section.matugen-color-scheme"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Icons"),
                    "icon": "category",
                    "targetId": "theme.section.icon-theme"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Fonts"),
                    "icon": "font_download",
                    "targetId": "theme.section.fonts"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cursor"),
                    "icon": "mouse",
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
                    "targetId": "theme.section.settings-window"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Super key"),
                    "icon": "keyboard_command_key",
                    "targetId": "theme.section.super-key-appearance"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Lock screen"),
                    "icon": "lock",
                    "targetId": "theme.section.lock-screen"
                }
            ]
        }
    ]
}
