import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("GeneralBarPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Bar"),
            "icon": "dock_to_bottom",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Position"),
                    "icon": "align_vertical_bottom",
                    "targetId": "general.bar.section.position"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Size and spacing"),
                    "icon": "space_bar",
                    "targetId": "general.bar.section.size-spacing"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Components"),
                    "icon": "view_week",
                    "targetId": "general.bar.section.components"
                }
            ]
        }
    ]
}
