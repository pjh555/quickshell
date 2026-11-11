pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Discovers data-driven desktop-pet character packs.
//
// A pack is a directory containing pet.json (plus its images). Built-in packs
// live in <shell>/assets/agent/pets; user packs live in
// ~/.config/clavis/pets. Later directories override earlier ones by id, and
// pack ids override the built-in Fluent Emoji catalog in AgentService.
//
// The scanner is intentionally external (scripts/agent/list-pet-packs.py) so
// that adding a pack never requires editing QML.
Singleton {
    id: root

    property var packs: []
    property bool loaded: false
    property int revision: 0
    property string error: ""

    function byId(id) {
        const key = String(id || "");
        for (let i = 0; i < root.packs.length; i++) {
            if (String(root.packs[i].id) === key)
                return root.packs[i];
        }
        return null;
    }

    function reload() {
        if (!scan.running)
            scan.running = true;
    }

    Process {
        id: scan

        command: ["/usr/bin/python3", Paths.scriptPath("agent", "list-pet-packs.py"),
                  Paths.assetsDir + "/agent/pets", Paths.configHome + "/pets"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(String(this.text || "[]"));
                    root.packs = Array.isArray(parsed) ? parsed : [];
                    root.revision++;
                    root.error = "";
                    console.log("PetPackService loaded", root.packs.length, root.packs.map(function (pack) {
                        return pack.id + ":" + (pack.aliases || []).join("/");
                    }).join(","));
                } catch (e) {
                    root.packs = [];
                    root.error = String(e);
                    console.warn("PetPackService: invalid pack index:", e);
                }
                root.loaded = true;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = String(this.text || "").trim();
                if (text !== "")
                    console.warn("PetPackService:", text);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && !root.loaded)
                root.loaded = true;
        }
    }

    Component.onCompleted: scan.running = true
}
