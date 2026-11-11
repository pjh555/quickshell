pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Qt rasterizes SVG icons again whenever they become visible, which makes the
// launchpad take about a second to open on slower devices. Icons requested by
// the launcher are rendered into a PNG cache once, so later opens only decode
// a small PNG per tile.
Singleton {
    id: root

    readonly property int pixelSize: 256
    readonly property string cacheDir: Paths.cacheHome + "/launchpad-icons"
    property var sources: ({})
    property var requested: ({})
    property bool ready: false
    property bool building: false
    property bool rebuildPending: false

    function sourceFor(url) {
        const value = String(url || "");
        if (!value.startsWith("file://"))
            return value;
        const cached = root.sources[value];
        if (cached)
            return cached;
        if (!root.requested[value]) {
            const next = Object.assign({}, root.requested);
            next[value] = true;
            root.requested = next;
            throttle.restart();
        }
        return value;
    }

    function pendingPaths() {
        const paths = [];
        for (const url in root.requested) {
            if (root.sources[url])
                continue;
            paths.push(decodeURIComponent(url.substring("file://".length)));
        }
        return paths;
    }

    function build() {
        if (root.building) {
            root.rebuildPending = true;
            return;
        }
        const paths = root.pendingPaths();
        if (paths.length === 0)
            return;
        root.building = true;
        builder.command = ["python3", Paths.scriptPath("launchpad", "icon-cache.py"), "--cache", root.cacheDir,
                           "--size", String(root.pixelSize)].concat(paths);
        builder.running = true;
    }

    Timer {
        id: throttle

        interval: 250
        repeat: false
        onTriggered: root.build()
    }

    Process {
        id: builder

        stdout: SplitParser {
            onRead: data => {
                const line = String(data || "").trim();
                const separator = line.indexOf("\t");
                if (separator <= 0)
                return;
                const next = Object.assign({}, root.sources);
                next["file://" + line.substring(0, separator)] = "file://" + line.substring(separator + 1);
                root.sources = next;
                root.ready = true;
            }
        }
        stderr: SplitParser {
            onRead: data => {
                const line = String(data || "").trim();
                if (line !== "")
                console.warn("[launchpad-icons]", line);
            }
        }
        onExited: exitCode => {
            root.building = false;
            if (exitCode !== 0)
            console.warn("[launchpad-icons] icon cache exited with", exitCode);
            if (root.rebuildPending || root.pendingPaths().length > 0) {
                root.rebuildPending = false;
                throttle.restart();
            }
        }
    }
}
