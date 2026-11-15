import QtQuick
import qs.Services

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Displays"),
            "icon": "monitor",
            "entries": [
                {
                    "title": SpotlightCatalog.title("general.displays.configuration"),
                    "icon": "monitor",
                    "source": "DisplayConfigurationPage.qml",
                    "pathSegment": "configuration",
                    "targetId": "general.displays.configuration.section.layout",
                    "targetPrefixes": ["general.displays.configuration"]
                },
                {
                    "title": SpotlightCatalog.title("general.displays.gamma"),
                    "icon": "brightness_6",
                    "source": "GammaControlPage.qml",
                    "pathSegment": "gamma",
                    "targetId": "general.displays.gamma.section.color",
                    "targetPrefixes": ["general.displays.gamma"]
                }
            ]
        }
    ]
}
