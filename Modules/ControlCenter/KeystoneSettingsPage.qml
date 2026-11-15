import QtQuick
import qs.Services

SettingsBusinessHub {
    id: root

    readonly property string keystoneStyleLabel: {
        const entry = PersonalizationConfig.keystoneStyles.find(option => option.value
                                                                === PersonalizationConfig.keystoneStyle);
        return entry ? entry.label : "";
    }

    legacySource: Qt.resolvedUrl("KeystonePage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Appearance"),
            "icon": "toggle_off",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keystone style"),
                    "icon": "web_asset",
                    "value": root.keystoneStyleLabel,
                    "targetId": "keystone.section.keystone-style"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Size and spacing"),
                    "icon": "space_bar",
                    "targetId": "keystone.section.size-spacing"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Horizontal clock"),
                    "icon": "schedule",
                    "targetId": "keystone.section.horizontal-clock",
                    "targetPrefixes": ["keystone.horizontal-clock"],
                    "source": "HorizontalClockPage.qml",
                    "pathSegment": "horizontal-clock"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Interaction"),
            "icon": "touch_app",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Mouse actions"),
                    "icon": "mouse",
                    "targetId": "keystone.section.mouse-actions"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Media controls"),
                    "icon": "music_note",
                    "targetId": "keystone.section.media-controls"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keyhole"),
                    "icon": "dashboard",
                    "targetId": "keystone.section.keyhole"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "System"),
            "icon": "settings",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keyboard indicators"),
                    "icon": "keyboard",
                    "available": KeyboardLockService.available,
                    "targetId": "keystone.section.keyboard-indicators"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Recording"),
                    "icon": "video_camera_front",
                    "targetId": "keystone.section.recording"
                }
            ]
        }
    ]
}
