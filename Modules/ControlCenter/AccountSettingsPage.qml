import QtQuick
import qs.Services

SettingsBusinessHub {
    id: root

    readonly property string languageLabel: {
        const entry = I18nService.supportedLanguages.find(option => option.code === UiPreferences.language);
        return entry ? entry.label : "";
    }

    legacySource: Qt.resolvedUrl("AccountPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Account"),
            "icon": "account_circle",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Profile and devices"),
                    "icon": "person",
                    "sectionFilter": "profile"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Language & region"),
                    "icon": "language",
                    "value": root.languageLabel,
                    "targetId": "account.section.language"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Connections"),
            "icon": "link",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Bluetooth devices"),
                    "icon": "settings_bluetooth",
                    "targetId": "account.section.bluetooth-devices"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cloud storage"),
                    "icon": "cloud",
                    "targetId": "account.section.cloud-storage"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Personalization"),
            "icon": "tune",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Personalization"),
                    "icon": "palette",
                    "targetId": "account.section.personalization"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keyboard shortcuts"),
                    "icon": "keyboard",
                    "targetId": "account.section.keyboard-shortcuts"
                }
            ]
        }
    ]
}
