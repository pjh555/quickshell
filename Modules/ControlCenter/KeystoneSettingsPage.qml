import QtQuick
import qs.Services

SettingsBusinessHub {
    id: root

    readonly property string keystoneStyleLabel: {
        const entry = PersonalizationConfig.keystoneStyles.find(option => option.value
                                                                === PersonalizationConfig.keystoneStyle);
        return entry ? entry.label : "";
    }

    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Appearance"),
            "icon": "toggle_off",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keystone style"),
                    "icon": "web_asset",
                    "value": root.keystoneStyleLabel,
                    "source": "KeystonePage.qml",
                    "sectionId": "keystone-style",
                    "targetId": "keystone.section.keystone-style"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Size and spacing"),
                    "icon": "space_bar",
                    "source": "KeystonePage.qml",
                    "sectionId": "size-spacing",
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
                    "source": "KeystonePage.qml",
                    "sectionId": "mouse-actions",
                    "targetId": "keystone.section.mouse-actions"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Media controls"),
                    "icon": "music_note",
                    "source": "KeystonePage.qml",
                    "sectionId": "media-controls",
                    "targetId": "keystone.section.media-controls"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keyhole"),
                    "icon": "dashboard",
                    "source": "KeystonePage.qml",
                    "sectionId": "keyhole",
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
                    "source": "KeystonePage.qml",
                    "sectionId": "keyboard-indicators",
                    "targetId": "keystone.section.keyboard-indicators"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Recording"),
                    "icon": "video_camera_front",
                    "source": "KeystonePage.qml",
                    "sectionId": "recording",
                    "targetId": "keystone.section.recording"
                }
            ]
        }
    ]
}
