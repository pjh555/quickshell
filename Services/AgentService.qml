pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Native shell-side client for the persistent clavis-agentd backend. The
// backend stores the durable configuration and provider credentials; QML only
// renders the top-bar chat surface and the desktop pet.
Singleton {
    id: root

    readonly property string backendUrl: "http://127.0.0.1:8765"
    readonly property string sessionFile: ""
    readonly property var builtinPetCatalog: [
        {
            "id": "whale",
            "name": "鲸鱼",
            "path": "Spouting%20whale/3D/spouting_whale_3d.png"
        },
        {
            "id": "cat",
            "name": "小猫",
            "path": "Cat/3D/cat_3d.png"
        },
        {
            "id": "dog",
            "name": "小狗",
            "path": "Dog%20face/3D/dog_face_3d.png"
        },
        {
            "id": "fox",
            "name": "狐狸",
            "path": "Fox/3D/fox_3d.png"
        },
        {
            "id": "panda",
            "name": "熊猫",
            "path": "Panda/3D/panda_3d.png"
        },
        {
            "id": "penguin",
            "name": "企鹅",
            "path": "Penguin/3D/penguin_3d.png"
        },
        {
            "id": "hamster",
            "name": "仓鼠",
            "path": "Hamster/3D/hamster_3d.png"
        },
        {
            "id": "rabbit",
            "name": "兔子",
            "path": "Rabbit%20face/3D/rabbit_face_3d.png"
        },
        {
            "id": "frog",
            "name": "青蛙",
            "path": "Frog/3D/frog_3d.png"
        },
        {
            "id": "octopus",
            "name": "章鱼",
            "path": "Octopus/3D/octopus_3d.png"
        },
        {
            "id": "chick",
            "name": "小鸡",
            "path": "Baby%20chick/3D/baby_chick_3d.png"
        },
        {
            "id": "duck",
            "name": "鸭子",
            "path": "Duck/3D/duck_3d.png"
        },
        {
            "id": "dolphin",
            "name": "海豚",
            "path": "Dolphin/3D/dolphin_3d.png"
        },
        {
            "id": "otter",
            "name": "水獭",
            "path": "Otter/3D/otter_3d.png"
        },
        {
            "id": "unicorn",
            "name": "独角兽",
            "path": "Unicorn/3D/unicorn_3d.png"
        },
        {
            "id": "dino",
            "name": "恐龙",
            "path": "Sauropod/3D/sauropod_3d.png"
        },
        {
            "id": "robot",
            "name": "机器人",
            "path": "Robot/3D/robot_3d.png"
        },
        {
            "id": "ghost",
            "name": "小幽灵",
            "path": "Ghost/3D/ghost_3d.png"
        }
    ]

    // Built-in emoji entries plus data-driven packs. A pack with the same id
    // replaces the built-in entry, so users can override built-ins from
    // ~/.config/clavis/pets without touching the shell.
    readonly property var petCatalog: {
        const revision = PetPackService.revision;
        const merged = [];
        for (let i = 0; i < root.builtinPetCatalog.length; i++)
            merged.push(root.builtinPetCatalog[i]);
        const extra = PetPackService.packs || [];
        for (let j = 0; j < extra.length; j++) {
            const pack = extra[j];
            const index = merged.findIndex(entry => String(entry.id) === String(pack.id));
            if (index >= 0)
                merged[index] = pack;
            else
                merged.push(pack);
        }
        return merged;
    }

    readonly property var petEntry: {
        const list = root.petCatalog;
        if (!list || list.length === 0)
            return null;
        const selected = String(root.pet.image || "whale");
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].id) === selected)
                return list[i];
        }
        return list[0];
    }

    readonly property bool petIsAnimated: !!(root.petEntry && root.petEntry.renderer === "frames"
                                             && !(root.pet.custom_url
                                                  && String(root.pet.custom_url).startsWith("https://")))

    signal attachmentPickRequested

    property bool panelOpen: false
    property bool online: false
    property bool busy: false
    property bool loadingConfig: false
    property string error: ""
    property string sessionId: ""
    property var config: ({
                              "enabled": true,
                              "name": "Clavis Agent",
                              "provider": "OpenAI",
                              "base_url": "https://api.openai.com/v1",
                              "api_style": "chat",
                              "api_key": "",
                              "model": "gpt-4o-mini",
                              "system_prompt": "你是 Clavis 桌面助手。回答简洁、直接，优先使用中文。",
                              "temperature": 0.3,
                              "max_tokens": 2048,
                              "computer_control": {
                                  "enabled": true,
                                  "allow_windows": true,
                                  "allow_launch": true,
                                  "allow_input": true,
                                  "allow_clipboard": true,
                                  "allow_audio": true,
                                  "allow_android": true,
                                  "adb_serial": "",
                                  "allow_shell": false,
                                  "allow_documents": true,
                                  "allow_web": true,
                                  "allow_config": true,
                                  "working_dir": "",
                                  "timeout": 20
                              },
                              "pet": {
                                  "enabled": true,
                                  "image": "whale",
                                  "custom_url": "",
                                  "size": 112,
                                  "sounds": false,
                                  "volume": 0.7
                              }
                          })
    property var messages: []
    property var lastUsage: ({})
    property var lastTrace: []
    property int messageSerial: 0

    readonly property var computer: root.config && root.config.computer_control
                                    ? root.config.computer_control : ({
                                                                          "enabled": false,
                                                                          "allow_windows": true,
                                                                          "allow_launch": true,
                                                                          "allow_input": true,
                                                                          "allow_clipboard": true,
                                                                          "allow_audio": true,
                                                                          "allow_android": true,
                                                                          "adb_serial": "",
                                                                          "allow_shell": false,
                                                                          "allow_documents": true,
                                                                          "allow_web": true,
                                                                          "allow_config": true,
                                                                          "working_dir": "",
                                                                          "timeout": 20
                                                                      })
    readonly property var voice: root.config && root.config.voice ? root.config.voice : ({
                                                                                             "enabled": true,
                                                                                             "auto_speak":
                                                                                             true,
                                                                                             "continuous":
                                                                                             false,
                                                                                             "tts_engine":
                                                                                             "auto",
                                                                                             "tts_voice":
                                                                                             "zh-cn",
                                                                                             "tts_speed": 150,
                                                                                             "source": "",
                                                                                             "vad_threshold":
                                                                                             500,
                                                                                             "vad_silence_ms":
                                                                                             800,
                                                                                             "max_seconds": 20
                                                                                         })
    property string voiceState: "idle"
    property string voicePartial: ""
    property bool voiceReplyPending: false
    property bool voiceCancelled: false
    property string voiceTtsPath: ""
    property var pendingAttachments: []
    property var mcpServers: []
    property var skills: []
    property string skillsDir: ""
    readonly property int maxAttachments: 8
    readonly property bool petEnabled: !!root.config && !!root.config.pet && root.config.pet.enabled === true
    readonly property var pet: root.config && root.config.pet ? root.config.pet : ({
                                                                                       "enabled": false,
                                                                                       "image": "whale",
                                                                                       "custom_url": "",
                                                                                       "size": 112,
                                                                                       "sounds": false,
                                                                                       "volume": 0.7
                                                                                   })
    readonly property string petImageUrl: {
        if (root.pet.custom_url && String(root.pet.custom_url).startsWith("https://"))
            return String(root.pet.custom_url);
        const entry = root.petEntry;
        if (!entry)
            return "";
        if (entry.renderer === "frames") {
            if (entry.previewUrl)
                return entry.previewUrl;
            return entry.animations && entry.animations.idle && entry.animations.idle.frames.length
                    ? entry.animations.idle.frames[0] : "";
        }
        if (entry.imageUrl)
            return entry.imageUrl;
        const path = entry.path || root.builtinPetCatalog[0].path;
        return "https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/assets/"
        + path;
    }

    function request(method, path, body, callback) {
        const xhr = new XMLHttpRequest();
        xhr.open(method, root.backendUrl + path, true);
        xhr.timeout = 900000;
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let parsed = null;
            try {
                parsed = xhr.responseText ? JSON.parse(xhr.responseText) : null;
            } catch (error) {
                parsed = null;
            }
            if (xhr.status >= 200 && xhr.status < 300) {
                callback("", parsed);
                return;
            }
            const message = parsed && parsed.error ? String(parsed.error) : (xhr.statusText || qsTr(
                                                                                 "后端请求失败"));


            callback(message, parsed);
        };
        xhr.onerror = function () {
            callback(qsTr("无法连接桌面 Agent 服务"), null);
        };
        xhr.ontimeout = function () {
            callback(qsTr("桌面 Agent 请求超时"), null);
        };
        xhr.send(body === null || body === undefined ? null : JSON.stringify(body));
    }

    function checkHealth() {
        request("GET", "/health", null, function (error, data) {
            root.online = !error && !!data && data.ok === true;
            if (root.online && !root.loadingConfig && (!root.config || root.config.model === undefined))
                root.loadConfig();
        });
    }

    function loadConfig() {
        root.loadingConfig = true;
        request("GET", "/v1/config", null, function (error, data) {
            root.loadingConfig = false;
            if (error || !data) {
                root.error = error || qsTr("无法读取 Agent 配置");
                return;
            }
            root.config = data;
            root.online = true;
        });
    }

    function saveConfig(patch) {
        const next = Object.assign({}, root.config || {}, patch || {});
        request("POST", "/v1/config", next, function (error, data) {
            if (error || !data) {
                root.error = error || qsTr("无法保存 Agent 配置");
                return;
            }
            root.config = data;
            root.online = true;
            root.error = "";
        });
    }

    function updateConfig(key, value) {
        const patch = {};
        patch[key] = value;
        saveConfig(patch);
    }

    function listLocalAgents(callback) {
        request("GET", "/v1/local-agents", null, callback);
    }

    function runLocalAgent(agent, task, cwd, callback) {
        request("POST", "/v1/local-agents/run", {
                    "agent": String(agent || ""),
                    "task": String(task || ""),
                    "cwd": String(cwd || "")
                }, callback);
    }

    function updatePet(key, value) {
        const nextPet = Object.assign({}, root.pet || {}, {});
        nextPet[key] = value;
        saveConfig({
                       "pet": nextPet
                   });
    }

    // Safe for callers that may not have loaded the config yet (IPC/scripts):
    // read the persisted config first, then save only the pet image change.
    function setPetImage(id) {
        const target = String(id || "whale");
        request("GET", "/v1/config", null, function (error, data) {
            if (error || !data) {
                root.error = error || qsTr("无法读取 Agent 配置");
                return;
            }
            const nextPet = Object.assign({}, data.pet || {}, {
                                            "image": target
                                        });
            const next = Object.assign({}, data, {
                                           "pet": nextPet
                                       });
            request("POST", "/v1/config", next, function (saveError, saved) {
                if (saveError || !saved) {
                    root.error = saveError || qsTr("无法保存 Agent 配置");
                    return;
                }
                root.config = saved;
                root.online = true;
                root.error = "";
            });
        });
    }

    function updateComputer(key, value) {
        const next = Object.assign({}, root.computer || {}, {});
        next[key] = value;
        saveConfig({
                       "computer_control": next
                   });
    }

    function updateVoice(key, value) {
        const next = Object.assign({}, root.voice || {}, {});
        next[key] = value;
        saveConfig({
                       "voice": next
                   });
    }

    function startVoice() {
        if (!root.online)
            root.ensureBackend();
        if (root.voiceState === "listening") {
            root.stopVoice();
            return;
        }
        if (root.voiceState === "speaking")
            root.stopSpeaking();
        if (root.busy)
            return;
        root.voiceState = "listening";
        root.voicePartial = "";
        root.error = "";
        voicePoll.restart();
        root.request("POST", "/v1/voice/listen", {}, function (error, data) {
            voicePoll.stop();
            if (root.voiceState !== "listening")
                return;
            root.voiceState = "idle";
            const result = data && data.output ? data.output : null;
            if (error || !data || !data.ok) {
                root.error = error || qsTr("Voice recognition failed");
                return;
            }
            const text = String(result && result.text || "").trim();
            if (text === "") {
                root.error = result && result.error ? String(result.error) : qsTr(
                                                          "Didn't catch that. Try again.");
                return;
            }
            root.voiceReplyPending = true;
            root.send(text);
        });
    }

    function stopVoice() {
        if (root.voiceState !== "listening")
            return;
        root.voiceState = "idle";
        root.voiceCancelled = true;
        voicePoll.stop();
        root.request("POST", "/v1/voice/stop", {}, function () {});
    }

    function stopSpeaking() {
        root.voiceCancelled = true;
        if (ttsPlayer.running)
            ttsPlayer.running = false;
        if (root.voiceState === "speaking")
            root.voiceState = "idle";
    }

    function stripForSpeech(text) {
        let value = String(text || "");
        value = value.replace(/```[\s\S]*?```/g, " 代码省略 ");
        value = value.replace(/`([^`]*)`/g, "$1");
        value = value.replace(/\*\*?|__?|#{1,6} /g, " ");
        value = value.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1");
        value = value.replace(/\s+/g, " ").trim();
        return value.slice(0, 600);
    }

    function speakReply(text) {
        const voice = root.voice;
        if (voice.enabled === false || voice.auto_speak === false) {
            root.maybeContinueVoice();
            return;
        }
        const clean = root.stripForSpeech(text);
        if (clean === "") {
            root.maybeContinueVoice();
            return;
        }
        root.voiceState = "speaking";
        root.request("POST", "/v1/voice/tts", {
                         "text": clean
                     }, function (error, data) {
                         if (error || !data || !data.ok || !data.output || !data.output.path) {
                             root.voiceState = "idle";
                             root.maybeContinueVoice();
                             return;
                         }
                         root.voiceTtsPath = String(data.output.path);
                         ttsPlayer.command = ["paplay", root.voiceTtsPath];
                         ttsPlayer.running = true;
                     });
    }

    function maybeContinueVoice() {
        if (root.voice.enabled === false || root.voice.continuous !== true)
            return;
        if (root.voiceCancelled) {
            root.voiceCancelled = false;
            return;
        }
        if (root.voiceState === "idle" && !root.busy)
            Qt.callLater(root.startVoice);
    }

    Timer {
        id: voicePoll

        interval: 180
        repeat: true
        running: false
        onTriggered: {
            root.request("GET", "/v1/voice/state", null, function (error, data) {
                if (error || !data || !data.state)
                    return;
                root.voicePartial = String(data.state.partial || "");
            });
        }
    }

    Process {
        id: ttsPlayer

        command: ["paplay", root.voiceTtsPath]
        onExited: {
            if (root.voiceState === "speaking")
            root.voiceState = "idle";
            root.maybeContinueVoice();
        }
    }

    function setProviderPreset(preset) {
        root.saveConfig(preset);
    }

    function appendMessage(role, text, attachments, artifacts, files) {
        const next = root.messages.slice();
        next.push({
                      "role": role,
                      "text": String(text || ""),
                      "attachments": Array.isArray(attachments) ? attachments.map(item => String(item.name
                                                                                                 || "")) : [],
                      "artifacts": Array.isArray(artifacts) ? artifacts : [],
                      "files": Array.isArray(files) ? files : [],
                      "id": ++root.messageSerial
                  });
        root.messages = next;
    }

    function addAttachmentPath(rawUrl) {
        let value = String(rawUrl || "").trim();
        if (value.startsWith("file://"))
            value = decodeURIComponent(value.substring(7));
        if (value === "" || root.pendingAttachments.length >= root.maxAttachments)
            return false;
        if (root.pendingAttachments.find(item => item.path === value))
            return false;
        const next = root.pendingAttachments.slice();
        next.push({
                      "path": value,
                      "name": value.substring(value.lastIndexOf("/") + 1)
                  });
        root.pendingAttachments = next;
        return true;
    }

    function removeAttachment(index) {
        const next = root.pendingAttachments.slice();
        if (index < 0 || index >= next.length)
            return;
        next.splice(index, 1);
        root.pendingAttachments = next;
    }

    function clearAttachments() {
        root.pendingAttachments = [];
    }

    function send(text, attachments) {
        const value = String(text || "").trim();
        const files = Array.isArray(attachments) && attachments.length > 0 ? attachments :
                                                                             root.pendingAttachments.slice();
        if ((value === "" && files.length === 0) || root.busy)
            return false;
        if (!root.online)
            root.ensureBackend();
        root.appendMessage("user", value, files);
        root.pendingAttachments = [];
        root.busy = true;
        root.error = "";
        root.request("POST", "/v1/chat", {
                         "message": value,
                         "session_id": root.sessionId,
                         "attachments": files
                     }, function (error, data) {
                         root.busy = false;
                         if (error || !data) {
                             root.error = error || qsTr("Agent 没有返回内容");
                             root.appendMessage("error", root.error);
                             root.voiceReplyPending = false;
                             return;
                         }
                         if (data.session_id)
                             root.sessionId = String(data.session_id);
                         root.lastUsage = data.usage || ({});
                         root.lastTrace = data.trace || [];
                         root.appendMessage("assistant", String(data.reply || ""), [], data.artifacts || [],
                                            data.files || []);
                         // MCP / skill 可能在对话中被 Agent 修改，刷新设置页数据
                         root.loadExtensions();
                         root.loadConfig();
                         if (root.voiceReplyPending) {
                             root.voiceReplyPending = false;
                             root.speakReply(String(data.reply || ""));
                         }
                     });
        return true;
    }

    function loadExtensions() {
        request("GET", "/v1/mcp", null, function (error, data) {
            if (!error && data && Array.isArray(data.servers))
                root.mcpServers = data.servers;
        });
        request("GET", "/v1/skills", null, function (error, data) {
            if (!error && data) {
                root.skills = Array.isArray(data.skills) ? data.skills : [];
                root.skillsDir = String(data.dir || "");
            }
        });
    }

    function setMcpServer(name, cfg) {
        const value = String(name || "").trim();
        if (value === "")
            return false;
        request("POST", "/v1/mcp/set", {
                    "name": value,
                    "cfg": cfg
                }, function (error) {
                    if (error)
                        console.warn("agent mcp set failed:", error);
                    loadExtensions();
                });
        return true;
    }

    function setSkillEnabled(name, enabled) {
        const value = String(name || "").trim();
        if (value === "")
            return;
        request("POST", "/v1/skills/set", {
                    "name": value,
                    "enabled": enabled
                }, function (error) {
                    if (error)
                        console.warn("agent skill toggle failed:", error);
                    loadExtensions();
                });
    }

    function createSkill(name, description, content) {
        const value = String(name || "").trim();
        if (!/^[a-z0-9][a-z0-9_-]{1,40}$/.test(value))
            return false;
        request("POST", "/v1/skills/create", {
                    "name": value,
                    "description": description,
                    "content": content
                }, function (error) {
                    if (error)
                        console.warn("agent skill create failed:", error);
                    loadExtensions();
                });
        return true;
    }

    function openSkillsDir() {
        if (root.skillsDir !== "")
            root.openFile(root.skillsDir);
    }

    function requestAttachmentPick() {
        root.closePanel();
        root.attachmentPickRequested();
    }

    function openFile(path) {
        const value = String(path || "").trim();
        if (value === "")
            return;
        root.request("POST", "/v1/open", {
                         "path": value
                     }, function (error, data) {
                         if (error)
                             console.warn("agent open file failed:", error);
                     });
    }

    function newSession() {
        root.sessionId = "";
        root.messages = [];
        root.pendingAttachments = [];
        root.lastUsage = ({});
        root.lastTrace = [];
        root.error = "";
    }

    function openPanel() {
        root.panelOpen = true;
        StatusMenuService.close();
        root.checkHealth();
        root.loadConfig();
    }

    function closePanel() {
        root.stopVoice();
        root.stopSpeaking();
        root.panelOpen = false;
    }

    function toggle() {
        if (root.panelOpen)
            root.closePanel();
        else
            root.openPanel();
    }

    function openSettings() {
        root.closePanel();
        ControlCenterService.open("agent");
    }

    function openPetSettings() {
        root.closePanel();
        ControlCenterService.openSearch("agent.section.pet");
    }

    function ensureBackend() {
        if (root.online)
            return;
        Quickshell.execDetached(["systemctl", "--user", "start", "clavis-agent.service"]);
        Qt.callLater(root.checkHealth);
    }

    function playPetSound(pressed) {
        if (!root.pet.sounds)
            return;
        const file = pressed ? "Ya1.mp3" : "Ya2.mp3";
        Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", Paths.shellDir
                                 + "/assets/agent/sounds/" + file]);
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.checkHealth()
    }

    Component.onCompleted: {
        root.checkHealth();
        root.loadConfig();
    }
}
