pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Per-character desktop settings. The schema deliberately follows the useful
// subset of DSH/dsh-pet's pet settings so existing settings can be imported by
// data, not by copying dsh-pet code into the shell.
Singleton {
    id: root

    readonly property string filePath: Paths.configHome + "/pet-settings.json"

    property var data: ({ "version": 1, "pets": {} })
    property bool ready: false
    property int revision: 0
    property bool importing: false
    property string importStatus: ""
    property string importError: ""

    function forPack(pack) {
        const rev = root.revision; // binding dependency for live settings updates
        if (!pack)
            return defaultSettings();
        // Imported DSH aliases are the base; a Clavis-specific entry for the
        // pack id overrides them.
        const aliases = Array.isArray(pack.aliases) ? pack.aliases : [];
        const ids = [];
        for (let i = 0; i < aliases.length; i++)
            ids.push(String(aliases[i]));
        ids.push(String(pack.id || ""));
        let merged = {};
        const all = root.data && root.data.pets ? root.data.pets : {};
        for (let i = 0; i < ids.length; i++) {
            if (all[ids[i]] && typeof all[ids[i]] === "object")
                merged = Object.assign(merged, all[ids[i]]);
        }
        const base = defaultSettings();
        if (merged.size === undefined && pack.appearance && Number(pack.appearance.defaultSize) > 0)
            merged.size = Number(pack.appearance.defaultSize);
        if (merged.fixed === undefined && pack.behavior && pack.behavior.wander === false)
            merged.fixed = true;
        return Object.assign(base, merged);
    }

    function defaultSettings() {
        return {
            "display": "desktop",
            "fixed": false,
            "workStatusEnabled": true,
            "sounds": AgentService.pet && AgentService.pet.sounds === true
        };
    }

    function updateForPack(pack, patch) {
        if (!pack || !patch)
            return;
        const id = String(pack.id || "");
        if (!id)
            return;
        const nextPets = Object.assign({}, root.data.pets || {});
        nextPets[id] = Object.assign({}, nextPets[id] || {}, patch);
        root.data = Object.assign({}, root.data, { "pets": nextPets });
        root.revision++;
        root.save();
    }

    function sizeFor(pack, fallback) {
        const value = Number(root.forPack(pack).size);
        return Math.max(64, Math.min(240, value > 0 ? value : (Number(fallback) || 112)));
    }

    function isDesktopVisible(pack) {
        return root.forPack(pack).display !== "none";
    }

    function fixed(pack) {
        return root.forPack(pack).fixed === true;
    }

    function workStatusEnabled(pack) {
        return root.forPack(pack).workStatusEnabled !== false;
    }

    function soundsEnabled(pack) {
        const value = root.forPack(pack).sounds;
        return value === undefined ? (AgentService.pet && AgentService.pet.sounds === true) : value === true;
    }

    function languageFor(pack) {
        const value = root.forPack(pack).language;
        return value === undefined || value === null ? "" : String(value);
    }

    function setLanguage(pack, language) {
        if (!pack)
            return;
        root.updateForPack(pack, { "language": String(language || "") });
    }

    function positionForPack(pack, screenWidth, screenHeight, size) {
        const s = root.forPack(pack);
        if (Number.isFinite(Number(s.x)) && Number.isFinite(Number(s.y)))
            return { "x": Number(s.x), "y": Number(s.y) };
        const pos = s.position && typeof s.position === "object" ? s.position : {};
        const mx = Number(pos.marginX);
        const my = Number(pos.marginY);
        const marginX = Number.isFinite(mx) ? mx : 36;
        const marginY = Number.isFinite(my) ? my : 92;
        const corner = String(pos.corner || "bottom-right");
        if (corner === "top-left")
            return { "x": marginX, "y": marginY };
        if (corner === "top-right")
            return { "x": screenWidth - size - marginX, "y": marginY };
        if (corner === "bottom-left")
            return { "x": marginX, "y": screenHeight - size - marginY };
        return { "x": screenWidth - size - marginX, "y": screenHeight - size - marginY };
    }

    function setPosition(pack, x, y) {
        root.updateForPack(pack, { "x": Math.round(x), "y": Math.round(y) });
    }

    function resetPack(pack) {
        if (!pack)
            return;
        const id = String(pack.id || "");
        if (!id)
            return;
        const nextPets = Object.assign({}, root.data.pets || {});
        delete nextPets[id];
        const aliases = Array.isArray(pack.aliases) ? pack.aliases : [];
        for (let i = 0; i < aliases.length; i++)
            delete nextPets[String(aliases[i])];
        root.data = Object.assign({}, root.data, { "pets": nextPets });
        root.revision++;
        root.save();
    }

    function importDsh() {
        if (root.importing)
            return;
        root.importing = true;
        root.importError = "";
        root.importStatus = qsTr("正在扫描 DSH 桌宠配置…");
        dshImport.running = true;
    }

    function save() {
        if (!root.ready)
            return;
        settingsFile.setText(JSON.stringify(root.data, null, 2));
    }

    FileView {
        id: settingsFile

        path: root.filePath
        watchChanges: true
        blockLoading: true
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                const parsed = JSON.parse(String(text() || "{}"));
                root.data = parsed && typeof parsed === "object" ? parsed : ({ "version": 1, "pets": {} });
                if (!root.data.pets || typeof root.data.pets !== "object")
                    root.data.pets = {};
            } catch (e) {
                console.warn("PetSettingsService: invalid settings:", e);
                root.data = ({ "version": 1, "pets": {} });
            }
            root.ready = true;
            root.revision++;
        }

        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("PetSettingsService: load failed:", error);
            root.ready = true;
            root.save();
        }
    }

    Process {
        id: dshImport

        command: ["/usr/bin/python3", Paths.scriptPath("agent", "dsh-pet-settings.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(String(this.text || "{}"));
                    if (!parsed || parsed.ok !== true) {
                        root.importStatus = parsed && parsed.error ? String(parsed.error) : qsTr("未找到 DSH 桌宠配置");
                        root.importError = root.importStatus;
                        return;
                    }
                    const incoming = parsed.pets && typeof parsed.pets === "object" ? parsed.pets : {};
                    const nextPets = Object.assign({}, root.data.pets || {});
                    let count = 0;
                    for (const id in incoming) {
                        if (!incoming[id] || typeof incoming[id] !== "object")
                            continue;
                        nextPets[id] = Object.assign({}, nextPets[id] || {}, incoming[id]);
                        count++;
                    }
                    root.data = Object.assign({}, root.data, {
                                                 "pets": nextPets,
                                                 "dsh": {
                                                     "source": String(parsed.source || ""),
                                                     "importedAt": Date.now()
                                                 }
                                             });
                    root.revision++;
                    root.save();
                    root.importStatus = qsTr("已导入 %1 个 DSH 角色设置").arg(count);
                    root.importError = "";
                } catch (e) {
                    root.importStatus = qsTr("DSH 设置解析失败");
                    root.importError = String(e);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = String(this.text || "").trim();
                if (text !== "")
                    console.warn("PetSettingsService/DSH:", text);
            }
        }

        onExited: exitCode => {
            root.importing = false;
            if (exitCode !== 0 && root.importError === "")
                root.importError = qsTr("DSH 设置扫描失败（退出码 %1）").arg(exitCode);
        }
    }
}
