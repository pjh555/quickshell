import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("WallpaperPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Backgrounds"),
            "icon": "wallpaper",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Desktop wallpaper"),
                    "icon": "desktop_windows",
                    "targetId": "wallpaper.section.current-wallpaper"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Overview background"),
                    "icon": "view_carousel",
                    "targetId": "wallpaper.section.overview-background"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Motion"),
            "icon": "animation",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Transition"),
                    "icon": "transition_slide",
                    "targetId": "wallpaper.section.transition"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Parallax effects"),
                    "icon": "motion_photos_on",
                    "targetId": "wallpaper.section.parallax-effects"
                }
            ]
        }
    ]
}
