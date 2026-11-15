import QtQuick

SettingsBusinessHub {
    legacySource: Qt.resolvedUrl("AgentPage.qml")
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Connection"),
            "icon": "hub",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Agent backend"),
                    "icon": "smart_toy",
                    "targetId": "agent.section.connection"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Provider"),
                    "icon": "key",
                    "targetId": "agent.section.provider"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Capabilities"),
            "icon": "extension",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Computer control"),
                    "icon": "computer",
                    "targetId": "agent.section.computer"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "MCP servers"),
                    "icon": "dns",
                    "targetId": "agent.section.mcp"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Agent skills"),
                    "icon": "auto_awesome",
                    "targetId": "agent.section.skills"
                }
            ]
        },
        {
            "title": qsTranslate("SettingsBusinessHub", "Presence"),
            "icon": "pets",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Desktop pet"),
                    "icon": "pets",
                    "targetId": "agent.section.pet"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Conversation"),
                    "icon": "chat",
                    "sectionFilter": "conversation"
                }
            ]
        }
    ]
}
