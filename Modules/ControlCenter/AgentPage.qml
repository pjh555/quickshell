import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property string sectionFilter: ""
    readonly property var currentPetSettings: PetSettingsService.forPack(AgentService.petEntry)

    function showsSection(section) {
        return root.sectionFilter === "" || root.sectionFilter === section;
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.settingsPageMargin * 2

    Component.onCompleted: {
        AgentService.checkHealth();
        AgentService.loadConfig();
        AgentService.loadExtensions();
    }

    onVisibleChanged: {
        if (visible) {
            AgentService.loadConfig();
            AgentService.loadExtensions();
        }
    }

    readonly property var providerPresets: [
        {
            "label": "OpenAI",
            "value": "openai",
            "base_url": "https://api.openai.com/v1",
            "api_style": "chat",
            "model": "gpt-4o-mini"
        },
        {
            "label": "DeepSeek",
            "value": "deepseek",
            "base_url": "https://api.deepseek.com/v1",
            "api_style": "chat",
            "model": "deepseek-chat"
        },
        {
            "label": "Codex++ Gateway",
            "value": "codexplus",
            "base_url": "http://127.0.0.1:57321/gw/codex/v1",
            "api_style": "responses",
            "model": "gpt-5.6-luna"
        },
        {
            "label": "Local / Ollama",
            "value": "local",
            "base_url": "http://127.0.0.1:11434/v1",
            "api_style": "chat",
            "model": "qwen2.5:7b"
        }
    ]

    function applyPreset(value) {
        for (let i = 0; i < root.providerPresets.length; ++i) {
            const preset = root.providerPresets[i];
            if (preset.value === value) {
                AgentService.saveConfig({
                                            "provider": preset.label,
                                            "base_url": preset.base_url,
                                            "api_style": preset.api_style,
                                            "model": preset.model
                                        });
                return;
            }
        }
    }

    function petLanguageCodes() {
        const entry = AgentService.petEntry || {};
        const bundles = entry.locales && typeof entry.locales === "object" ? entry.locales : (entry.i18n
                                                                                              && typeof entry.i18n
                                                                                              === "object"
                                                                                              ? entry.i18n :
                                                                                                {});
        const codes = [];
        if (entry.language && codes.indexOf(String(entry.language)) < 0)
            codes.push(String(entry.language));
        for (const key in bundles) {
            if (codes.indexOf(String(key)) < 0)
                codes.push(String(key));
        }
        return codes;
    }

    function petLanguageValue() {
        const override = PetSettingsService.languageFor(AgentService.petEntry);
        if (override)
            return override;
        return AgentService.petEntry && AgentService.petEntry.language ? String(
                                                                             AgentService.petEntry.language) :
                                                                         "";
    }

    property string presetHint: ""

    // 与上游 CodexPlusPlus mcp-presets.ts（源自 cc-switch, MIT）同源的常用
    // 服务器预设；另加两个免本地运行时的远程 HTTP 商用服务。
    readonly property var mcpPresets: [
        {
            "id": "time",
            "label": "time",
            "command": "uvx mcp-server-time",
            "url": "",
            "description": qsTr("Current time and timezone conversion (requires uvx)")
        },
        {
            "id": "memory",
            "label": "memory",
            "command": "npx -y @modelcontextprotocol/server-memory",
            "url": "",
            "description": qsTr("Knowledge-graph long-term memory across sessions (npx)")
        },
        {
            "id": "sequential-thinking",
            "label": "sequential-thinking",
            "command": "npx -y @modelcontextprotocol/server-sequential-thinking",
            "url": "",
            "description": qsTr("Break complex problems into traceable thinking steps (npx)")
        },
        {
            "id": "context7",
            "label": "context7",
            "command": "npx -y @upstash/context7-mcp",
            "url": "",
            "description": qsTr("Up-to-date library and framework docs (npx, Upstash)")
        },
        {
            "id": "fetch",
            "label": "fetch",
            "command": "uvx mcp-server-fetch",
            "url": "",
            "description": qsTr("Fetch web pages as model-friendly text (requires uvx)")
        },
        {
            "id": "context7-remote",
            "label": "context7 (HTTP)",
            "command": "",
            "url": "https://mcp.context7.com/mcp",
            "description": qsTr("Context7 hosted docs service over HTTP, no local runtime")
        },
        {
            "id": "deepwiki",
            "label": "deepwiki (HTTP)",
            "command": "",
            "url": "https://mcp.deepwiki.com/mcp",
            "description": qsTr("DeepWiki hosted docs for GitHub repositories over HTTP")
        }
    ]

    ColumnLayout {
        id: contentColumn

        width: Math.min(720, Math.max(0, root.width - Metrics.settingsPageMargin * 2))
        x: Math.max(Metrics.settingsPageMargin, (root.width - width) / 2)
        y: Metrics.settingsPageMargin
        spacing: Metrics.spacingM

        SettingsSection {
            id: connectionSection
            visible: root.showsSection("connection")
            Layout.fillWidth: true
            flat: true
            title: searchAnchor0.title
            iconName: "smart_toy"

            SettingsSearchAnchor {
                id: searchAnchor0
                target: connectionSection
                declaration:
                    '{"id":"agent.section.connection","route":"agent","title":"Agent backend","context":"AgentPage","icon":"smart_toy","aliases":["assistant","ai","model","api"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Agent 状态")
                supportingText: AgentService.online ? qsTr("本地服务正在运行") : qsTr("启动服务后即可使用")

                trailing: RowLayout {
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: AgentService.online ? Appearance.colors.colPrimary : Appearance.colors.colError
                    }

                    Text {
                        text: AgentService.online ? qsTr("在线") : qsTr("离线")
                        color: AgentService.online ? Appearance.colors.colPrimary : Appearance.colors.colError
                        font.family: Fonts.ui
                        font.pixelSize: 12
                    }

                    StyledSwitch {
                        checked: AgentService.config.enabled !== false
                        Accessible.name: qsTr("启用 Agent")
                        onToggled: AgentService.updateConfig("enabled", checked)
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Agent 名称")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 260
                    text: AgentService.config.name || "Clavis Agent"
                    placeholderText: "Clavis Agent"
                    onEditingFinished: AgentService.updateConfig("name", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("服务地址")
                supportingText: qsTr("本机只监听 127.0.0.1:8765；由 systemd 用户服务托管")

                trailing: RowLayout {
                    spacing: 8

                    Text {
                        text: AgentService.online ? "127.0.0.1:8765" : qsTr("未启动")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.mono
                        font.pixelSize: 11
                    }

                    IconButton {
                        controlSize: 28
                        iconSize: 15
                        iconName: "restart_alt"
                        tooltipText: qsTr("重启 Agent 后端")
                        onClicked: {
                            Quickshell.execDetached(["systemctl", "--user", "restart",
                                                     "clavis-agent.service"]);
                            Qt.callLater(AgentService.checkHealth);
                        }
                    }
                }
            }
        }

        SettingsSection {
            visible: root.showsSection("provider")
            Layout.fillWidth: true
            flat: true
            title: searchAnchor1.title
            iconName: "key"

            SettingsSearchAnchor {
                id: searchAnchor1
                target: parent
                declaration:
                    '{"id":"agent.section.provider","route":"agent","title":"Provider","context":"AgentPage","icon":"key","aliases":["api key","model","base url"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("供应商预设")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 260
                    options: root.providerPresets
                    value: ""
                    closeOnAccept: true
                    Accessible.name: qsTr("Agent provider preset")
                    onAccepted: value => root.applyPreset(value)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Base URL")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 300
                    text: AgentService.config.base_url || ""
                    placeholderText: "https://api.openai.com/v1"
                    onEditingFinished: AgentService.updateConfig("base_url", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("API 协议")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 180
                    options: [
                        {
                            "label": "Chat Completions",
                            "value": "chat"
                        },
                        {
                            "label": "Responses",
                            "value": "responses"
                        }
                    ]
                    value: AgentService.config.api_style || "chat"
                    closeOnAccept: true
                    onAccepted: value => AgentService.updateConfig("api_style", value)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("模型")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 260
                    text: AgentService.config.model || ""
                    placeholderText: "gpt-4o-mini"
                    onEditingFinished: AgentService.updateConfig("model", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("API Key")
                supportingText: qsTr("只保存在本机 0600 配置文件中")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 300
                    text: AgentService.config.api_key || ""
                    placeholderText: qsTr("sk-…")
                    echoMode: TextInput.Password
                    onEditingFinished: AgentService.updateConfig("api_key", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("系统提示词")

                trailing: TextArea {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 92
                    text: AgentService.config.system_prompt || ""
                    wrapMode: TextEdit.Wrap
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    selectByMouse: true
                    onEditingFinished: AgentService.updateConfig("system_prompt", text)
                    background: Rectangle {
                        radius: 9
                        color: Appearance.macos.macFill
                        border.width: 1
                        border.color: Appearance.macos.hairline
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("温度")

                trailing: GeneralSliderSetting {
                    Layout.preferredWidth: 280
                    from: 0
                    to: 100
                    stepSize: 1
                    value: Math.round((Number(AgentService.config.temperature) || 0.3) * 100)
                    onMoved: value => AgentService.updateConfig("temperature", value / 100)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("最大输出 tokens")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 180
                    text: String(AgentService.config.max_tokens || 2048)
                    inputMethodHints: Qt.ImhDigitsOnly
                    onEditingFinished: AgentService.updateConfig("max_tokens", Math.max(64, Math.min(32768,
                                                                                                     Number(text)
                                                                                                     || 2048)))
                }
            }
        }

        SettingsSection {
            id: computerSection
            visible: root.showsSection("computer")
            Layout.fillWidth: true
            flat: true
            title: searchAnchor3.title
            iconName: "computer"

            SettingsSearchAnchor {
                id: searchAnchor3
                target: computerSection
                declaration:
                    '{"id":"agent.section.computer","route":"agent","title":"Computer control","context":"AgentPage","icon":"computer","aliases":["desktop","窗口","键盘","shell","操作电脑"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("允许 Agent 操作电脑")
                supportingText: qsTr("启用后 Agent 可以调用本机桌面工具；关闭后只进行对话")

                trailing: StyledSwitch {
                    checked: AgentService.computer.enabled !== false
                    Accessible.name: qsTr("Computer control")
                    onToggled: AgentService.updateComputer("enabled", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("窗口管理")
                supportingText: qsTr("列出、聚焦、关闭窗口以及切换全屏")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_windows !== false
                    Accessible.name: qsTr("Window control")
                    onToggled: AgentService.updateComputer("allow_windows", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("启动应用 / 打开链接")
                supportingText: qsTr("通过 Niri 启动应用，或用默认浏览器打开 URL")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_launch !== false
                    Accessible.name: qsTr("Launch control")
                    onToggled: AgentService.updateComputer("allow_launch", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("键盘输入")
                supportingText: qsTr("向当前焦点应用输入文字或按键")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_input !== false
                    Accessible.name: qsTr("Keyboard control")
                    onToggled: AgentService.updateComputer("allow_input", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("剪贴板")
                supportingText: qsTr("读取或写入 Wayland 剪贴板")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_clipboard !== false
                    Accessible.name: qsTr("Clipboard control")
                    onToggled: AgentService.updateComputer("allow_clipboard", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("音频设备")
                supportingText: qsTr("列出、切换默认输出设备并调整音量")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_audio !== false
                    Accessible.name: qsTr("Audio device control")
                    onToggled: AgentService.updateComputer("allow_audio", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Voice chat")
                supportingText: qsTr("Local speech recognition and synthesis; audio never leaves the device")

                trailing: StyledSwitch {
                    checked: AgentService.voice.enabled !== false
                    Accessible.name: qsTr("Voice chat")
                    onToggled: AgentService.updateVoice("enabled", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Speak replies aloud")
                supportingText: qsTr("Read Agent replies with local speech synthesis")

                trailing: StyledSwitch {
                    checked: AgentService.voice.auto_speak !== false
                    Accessible.name: qsTr("Auto speak replies")
                    onToggled: AgentService.updateVoice("auto_speak", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Continuous conversation")
                supportingText: qsTr("Keep listening after each reply for hands-free chat")

                trailing: StyledSwitch {
                    checked: AgentService.voice.continuous === true
                    Accessible.name: qsTr("Continuous conversation")
                    onToggled: AgentService.updateVoice("continuous", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Speech rate")

                trailing: GeneralSliderSetting {
                    Layout.preferredWidth: 280
                    from: 100
                    to: 220
                    stepSize: 5
                    value: Number(AgentService.voice.tts_speed) || 150
                    onMoved: value => AgentService.updateVoice("tts_speed", value)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Android / ADB")
                supportingText: qsTr("Tap, swipe, press keys and read Android app UIs over ADB")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_android !== false
                    Accessible.name: qsTr("Android ADB control")
                    onToggled: AgentService.updateComputer("allow_android", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("ADB serial")
                supportingText: qsTr("Leave empty to pick the first online device")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 260
                    text: AgentService.computer.adb_serial || ""
                    placeholderText: qsTr("Auto")
                    onEditingFinished: AgentService.updateComputer("adb_serial", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Shell 命令")
                supportingText: qsTr("高风险：允许 Agent 执行任意命令。只在你信任模型时开启")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_shell === true
                    Accessible.name: qsTr("Shell control")
                    onToggled: AgentService.updateComputer("allow_shell", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("允许 Clavis 调度本机 Agent")
                supportingText: qsTr("调用 Codex / Claude Code / OpenCode / DSH 等本机 CLI 执行任务")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_local_agents !== false
                    Accessible.name: qsTr("Local agent delegation")
                    onToggled: AgentService.updateComputer("allow_local_agents", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Document generation")
                supportingText: qsTr("Allow the Agent to create Word, PPT and PDF files")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_documents === true
                    Accessible.name: qsTr("Document generation")
                    onToggled: AgentService.updateComputer("allow_documents", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Web search")
                supportingText: qsTr("Let the Agent search the web and read pages for current information")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_web === true
                    Accessible.name: qsTr("Web search")
                    onToggled: AgentService.updateComputer("allow_web", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Configure MCP and skills from chat")
                supportingText: qsTr(
                                    "The Agent can add, edit, enable or remove MCP servers and skills when you ask it to; changes appear in this page")

                trailing: StyledSwitch {
                    checked: AgentService.computer.allow_config !== false
                    Accessible.name: qsTr("Configure MCP and skills from chat")
                    onToggled: AgentService.updateComputer("allow_config", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("工作目录")
                supportingText: qsTr("运行命令时的目录；留空使用用户主目录")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 300
                    text: AgentService.computer.working_dir || ""
                    placeholderText: "~"
                    onEditingFinished: AgentService.updateComputer("working_dir", text)
                }
            }
        }

        SettingsSection {
            id: mcpSection
            visible: root.showsSection("mcp")
            Layout.fillWidth: true
            flat: true
            title: searchAnchorMcp.title
            iconName: "extension"

            SettingsSearchAnchor {
                id: searchAnchorMcp
                target: parent
                declaration:
                    '{"id":"agent.section.mcp","route":"agent","title":"MCP servers","context":"AgentPage","icon":"extension","aliases":["mcp","extension","plugin","tools"]}'
            }

            Repeater {
                model: AgentService.mcpServers

                delegate: SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    title: modelData.name
                    supportingText: {
                        const where = modelData.url ? modelData.url : modelData.command;
                        if (modelData.state === "disabled")
                            return where + " · " + qsTr("Disabled");
                        if (modelData.state === "ready")
                            return where + " · " + qsTr("%1 tools").arg(modelData.tool_count);
                        return where + " · " + qsTr("Error: %1").arg(modelData.error || "");
                    }

                    trailing: RowLayout {
                        spacing: 6

                        StyledSwitch {
                            checked: modelData.enabled
                            Accessible.name: qsTr("Enable MCP server")
                            onToggled: AgentService.setMcpServer(modelData.name, {
                                                                     "enabled": checked
                                                                 })
                        }

                        IconButton {
                            controlSize: 30
                            iconSize: 16
                            iconName: "delete"
                            tooltipText: qsTr("Remove server")
                            onClicked: AgentService.removeMcpServer(modelData.name)
                        }
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Quick add")
                supportingText: root.presetHint !== "" ? root.presetHint : qsTr(
                                                             "Click a preset to fill the form below, then press Add server")

                trailing: Flow {
                    Layout.preferredWidth: 300
                    spacing: 6

                    Repeater {
                        model: root.mcpPresets

                        delegate: ActionButton {
                            required property var modelData

                            text: modelData.label
                            Accessible.name: modelData.label
                            onClicked: {
                                root.presetHint = modelData.description;
                                newMcpName.text = modelData.id;
                                newMcpCommand.text = modelData.command;
                                newMcpUrl.text = modelData.url;
                            }
                        }
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Name")

                trailing: OutlinedTextField {
                    id: newMcpName

                    Layout.preferredWidth: 260
                    placeholderText: "filesystem"
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Command")
                supportingText: qsTr(
                                    "Local stdio server launch command, e.g. npx -y @modelcontextprotocol/server-filesystem /tmp")

                trailing: OutlinedTextField {
                    id: newMcpCommand

                    Layout.preferredWidth: 300
                    placeholderText: "npx -y …"
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("URL")
                supportingText: qsTr("For remote servers; overrides command when set")

                trailing: OutlinedTextField {
                    id: newMcpUrl

                    Layout.preferredWidth: 300
                    placeholderText: "https://…"
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "add"
                trailingIconName: ""
                text: qsTr("Add server")
                onClicked: {
                    if (!AgentService.setMcpServer(newMcpName.text.trim(), {
                                                       "command": newMcpCommand.text.trim(),
                                                       "url": newMcpUrl.text.trim(),
                                                       "enabled": true
                                                   }))
                        return;
                    newMcpName.text = "";
                    newMcpCommand.text = "";
                    newMcpUrl.text = "";
                    root.presetHint = "";
                }
            }
        }

        SettingsSection {
            id: skillsSection
            visible: root.showsSection("skills")
            Layout.fillWidth: true
            flat: true
            title: searchAnchorSkills.title
            iconName: "auto_awesome"

            SettingsSearchAnchor {
                id: searchAnchorSkills
                target: parent
                declaration:
                    '{"id":"agent.section.skills","route":"agent","title":"Agent skills","context":"AgentPage","icon":"auto_awesome","aliases":["skills","skill","能力"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: AgentService.skills.length === 0
                title: qsTr("No skills yet")
                supportingText: qsTr("Create one below or drop a folder with SKILL.md into the skills folder")
            }

            Repeater {
                model: AgentService.skills

                delegate: SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    title: modelData.name
                    supportingText: modelData.description || qsTr("No description")

                    trailing: StyledSwitch {
                        checked: modelData.enabled
                        Accessible.name: qsTr("Enable skill")
                        onToggled: AgentService.setSkillEnabled(modelData.name, checked)
                    }
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "folder_open"
                trailingIconName: ""
                text: qsTr("Open skills folder")
                description: AgentService.skillsDir
                onClicked: AgentService.openSkillsDir()
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Name")

                trailing: OutlinedTextField {
                    id: newSkillName

                    Layout.preferredWidth: 260
                    placeholderText: "meeting-notes"
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Description")

                trailing: OutlinedTextField {
                    id: newSkillDesc

                    Layout.preferredWidth: 300
                    placeholderText: qsTr("What the skill does")
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Content (markdown)")

                trailing: TextArea {
                    id: newSkillContent

                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 110
                    wrapMode: TextEdit.Wrap
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    selectByMouse: true
                    background: Rectangle {
                        radius: 9
                        color: Appearance.macos.macFill
                        border.width: 1
                        border.color: Appearance.macos.hairline
                    }
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "add"
                trailingIconName: ""
                text: qsTr("Create skill")
                onClicked: {
                    if (!AgentService.createSkill(newSkillName.text.trim(), newSkillDesc.text.trim(),
                                                  newSkillContent.text))
                        return;
                    newSkillName.text = "";
                    newSkillDesc.text = "";
                    newSkillContent.text = "";
                }
            }
        }

        SettingsSection {
            visible: root.showsSection("pet")
            Layout.fillWidth: true
            flat: true
            title: searchAnchor2.title
            iconName: "pets"

            SettingsSearchAnchor {
                id: searchAnchor2
                target: parent
                declaration:
                    '{"id":"agent.section.pet","route":"agent","title":"Desktop pet","context":"AgentPage","icon":"pets","aliases":["桌宠","pet","image"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("桌面 Agent 桌宠")

                trailing: StyledSwitch {
                    checked: AgentService.pet.enabled === true
                    Accessible.name: qsTr("Desktop pet")
                    onToggled: AgentService.updatePet("enabled", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("桌宠形象")
                supportingText: qsTr("内置形象 + 角色包；角色包目录 ~/.config/clavis/pets")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 220
                    options: AgentService.petCatalog.map(entry => ({
                                                                       "label": entry.name,
                                                                       "value": entry.id
                                                                   }))
                    value: AgentService.pet.image || "whale"
                    closeOnAccept: true
                    onAccepted: value => AgentService.updatePet("image", value)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.petLanguageCodes().length > 0
                title: qsTr("角色语言")
                supportingText: qsTr("语言属于角色包；有 locales 时可切换，未选择时使用角色默认语言")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 220
                    options: root.petLanguageCodes().map(code => ({
                                                                      "label": code,
                                                                      "value": code
                                                                  }))
                    value: root.petLanguageValue()
                    closeOnAccept: true
                    onAccepted: value => PetSettingsService.setLanguage(AgentService.petEntry, value)
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "refresh"
                trailingIconName: ""
                text: qsTr("重新扫描角色包")
                description: qsTr("已发现 %1 个角色包").arg(PetPackService.packs.length)
                onClicked: PetPackService.reload()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "radar"
                trailingIconName: ""
                text: qsTr("打开 Agent 监控中心")
                description: qsTr("%1 个 Agent · %2 工作中 · %3 等待").arg(AgentFleetService.activeCount).arg(
                                 AgentFleetService.workingCount).arg(AgentFleetService.waitingCount)
                onClicked: AgentFleetService.openPanel()
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("自定义图片 URL")
                supportingText: qsTr("仅支持 https；留空时使用上面选择的桌宠形象")

                trailing: OutlinedTextField {
                    Layout.preferredWidth: 300
                    text: AgentService.pet.custom_url || ""
                    placeholderText: "https://…"
                    onEditingFinished: AgentService.updatePet("custom_url", text)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("当前角色大小")
                supportingText: qsTr("按角色分别记忆；旧版全局大小作为回退")

                trailing: GeneralSliderSetting {
                    Layout.preferredWidth: 280
                    from: 64
                    to: 240
                    stepSize: 4
                    value: Number(root.currentPetSettings.size) || Number(AgentService.pet.size) || 112
                    onMoved: value => PetSettingsService.updateForPack(AgentService.petEntry, {
                                                                           "size": Math.round(value)
                                                                       })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("桌宠音效")

                trailing: StyledSwitch {
                    checked: PetSettingsService.soundsEnabled(AgentService.petEntry)
                    Accessible.name: qsTr("Desktop pet sounds")
                    onToggled: PetSettingsService.updateForPack(AgentService.petEntry, {
                                                                    "sounds": checked
                                                                })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("音效音量")

                trailing: GeneralSliderSetting {
                    Layout.preferredWidth: 280
                    from: 0
                    to: 100
                    stepSize: 1
                    value: Math.round((Number(AgentService.pet.volume) || 0.7) * 100)
                    onMoved: value => AgentService.updatePet("volume", value / 100)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("在桌面显示")
                supportingText: qsTr("关闭后只保留 Agent 对话，不再显示桌宠")

                trailing: StyledSwitch {
                    checked: PetSettingsService.isDesktopVisible(AgentService.petEntry)
                    onToggled: PetSettingsService.updateForPack(AgentService.petEntry, {
                                                                    "display": checked ? "desktop" : "none"
                                                                })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("允许桌宠散步")
                supportingText: qsTr("固定角色只做待机/状态动作")

                trailing: StyledSwitch {
                    checked: !PetSettingsService.fixed(AgentService.petEntry)
                    onToggled: PetSettingsService.updateForPack(AgentService.petEntry, {
                                                                    "fixed": !checked
                                                                })
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("响应本机 Agent 状态")
                supportingText: qsTr("监控中心在聊天面板的雷达按钮里；桌宠只做状态动画与气泡")

                trailing: StyledSwitch {
                    checked: PetSettingsService.workStatusEnabled(AgentService.petEntry)
                    onToggled: PetSettingsService.updateForPack(AgentService.petEntry, {
                                                                    "workStatusEnabled": checked
                                                                })
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "restart_alt"
                trailingIconName: ""
                text: qsTr("重置当前角色设置")
                description: AgentService.petEntry ? String(AgentService.petEntry.name) : ""
                onClicked: PetSettingsService.resetPack(AgentService.petEntry)
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "download"
                trailingIconName: ""
                text: qsTr("导入 DSH 桌宠设置")
                description: PetSettingsService.importStatus || qsTr(
                                 "读取 ~/.dsh/dsh-pet 的 main-config.jsonc / pet/*")
                onClicked: PetSettingsService.importDsh()
            }
        }

        SettingsSection {
            visible: root.showsSection("conversation")
            Layout.fillWidth: true
            flat: true
            title: qsTr("Conversation")

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("当前会话")
                supportingText: AgentService.sessionId === "" ? qsTr("新会话") : AgentService.sessionId

                trailing: RowLayout {
                    spacing: 8

                    IconButton {
                        controlSize: 30
                        iconSize: 16
                        iconName: "chat"
                        tooltipText: qsTr("打开 Agent")
                        onClicked: AgentService.openPanel()
                    }

                    IconButton {
                        controlSize: 30
                        iconSize: 16
                        iconName: "add_comment"
                        tooltipText: qsTr("新对话")
                        onClicked: AgentService.newSession()
                    }
                }
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AgentService.error !== ""
            tone: "error"
            message: AgentService.error
        }
    }
}
