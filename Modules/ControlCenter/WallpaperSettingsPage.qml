import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Backgrounds"),
            "icon": "wallpaper",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Desktop wallpaper"),
                    "icon": "desktop_windows",
                    "source": "WallpaperPage.qml",
                    "sectionId": "current-wallpaper",
                    "targetId": "wallpaper.section.current-wallpaper"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Overview background"),
                    "icon": "view_carousel",
                    "source": "WallpaperPage.qml",
                    "sectionId": "overview-background",
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
                    "source": "WallpaperPage.qml",
                    "sectionId": "transition",
                    "targetId": "wallpaper.section.transition"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Parallax effects"),
                    "icon": "motion_photos_on",
                    "source": "WallpaperPage.qml",
                    "sectionId": "parallax-effects",
                    "targetId": "wallpaper.section.parallax-effects"
                }
            ]
        }
    ]
}
