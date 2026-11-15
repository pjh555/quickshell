import QtQuick

SettingsBusinessHub {
    groups: [
        {
            "title": qsTranslate("SettingsBusinessHub", "Connection"),
            "icon": "hub",
            "entries": [
                {
                    "title": qsTranslate("SettingsBusinessHub", "Agent backend"),
                    "icon": "smart_toy",
                    "source": "AgentPage.qml",
                    "sectionId": "connection",
                    "targetId": "agent.section.connection"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Provider"),
                    "icon": "key",
                    "source": "AgentPage.qml",
                    "sectionId": "provider",
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
                    "source": "AgentPage.qml",
                    "sectionId": "computer",
                    "targetId": "agent.section.computer"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "MCP servers"),
                    "icon": "dns",
                    "source": "AgentPage.qml",
                    "sectionId": "mcp",
                    "targetId": "agent.section.mcp"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Agent skills"),
                    "icon": "auto_awesome",
                    "source": "AgentPage.qml",
                    "sectionId": "skills",
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
                    "source": "AgentPage.qml",
                    "sectionId": "pet",
                    "targetId": "agent.section.pet"
                },
                {
                    "title": qsTranslate("SettingsBusinessHub", "Conversation"),
                    "icon": "chat",
                    "source": "AgentPage.qml",
                    "sectionId": "conversation"
                }
            ]
        }
    ]
}
