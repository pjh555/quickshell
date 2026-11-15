import QtQuick
import qs.Services

SettingsBusinessHub {
    id: root

    readonly property string languageLabel: {
        const entry = I18nService.supportedLanguages.find(option => option.code === UiPreferences.language);
        return entry ? entry.label : "";
    }

    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Account"),
            "icon": "account_circle",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Profile and devices"),
                    "icon": "person",
                    "source": "AccountPage.qml",
                    "sectionId": "profile"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Language & region"),
                    "icon": "language",
                    "value": root.languageLabel,
                    "source": "AccountPage.qml",
                    "sectionId": "language",
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
                    "source": "AccountPage.qml",
                    "sectionId": "bluetooth-devices",
                    "targetId": "account.section.bluetooth-devices"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Cloud storage"),
                    "icon": "cloud",
                    "source": "AccountPage.qml",
                    "sectionId": "cloud-storage",
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
                    "source": "AccountPage.qml",
                    "sectionId": "personalization",
                    "targetId": "account.section.personalization"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Keyboard shortcuts"),
                    "icon": "keyboard",
                    "source": "AccountPage.qml",
                    "sectionId": "keyboard-shortcuts",
                    "targetId": "account.section.keyboard-shortcuts"
                }
            ]
        }
    ]
}
