import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Bar"),
            "icon": "dock_to_bottom",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Position"),
                    "icon": "align_vertical_bottom",
                    "source": "GeneralBarPage.qml",
                    "sectionId": "position",
                    "targetId": "general.bar.section.position"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Size and spacing"),
                    "icon": "space_bar",
                    "source": "GeneralBarPage.qml",
                    "sectionId": "size-spacing",
                    "targetId": "general.bar.section.size-spacing"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Components"),
                    "icon": "view_week",
                    "source": "GeneralBarPage.qml",
                    "sectionId": "components",
                    "targetId": "general.bar.section.components"
                }
            ]
        }
    ]
}
