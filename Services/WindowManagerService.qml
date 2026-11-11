pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Common
import qs.Services

// The compositor-neutral snapshot behind the Clavis window overview. Sway is
// read through swaymsg/grim; Niri is read through the native Niri model and
// WindowPreviewService so windows remain draggable on touch screens.
Singleton {
    id: root

    readonly property bool niriBackend: PlatformService.isNiri && Niri.connected
    readonly property bool swayBackend: PlatformService.isSway
    readonly property bool available: (root.niriBackend || root.swayBackend)
                                      && PlatformService.layerShellAvailable
    readonly property string thumbnailRoot: Paths.cacheHome + "/window-overview"
    property string targetScreenName: ""
    property bool visible: false
    property bool loading: false
    property string error: ""
    property var windows: []
    property double captureSerial: 0
    readonly property string thumbnailDir: root.thumbnailRoot + "/" + root.captureSerial
    readonly property int count: root.windows.length
    property bool _pendingOpen: false
    property bool _closeAfterAction: false
    property int _querySerial: 0
    property string _previewConsumer: ""

    function thumbnailFor(id) {
        return "file://" + root.thumbnailDir + "/" + String(id) + ".png";
    }

    function open(screenName) {
        if (!root.available)
            return false;
        if (root.visible)
            return true;
        const requested = String(screenName || "");
        const screens = Array.from(Quickshell.screens || []);
        const screen = screens.find(candidate => String(candidate.name) === requested) || screens[0];
        root.targetScreenName = screen ? String(screen.name) : "";
        root.error = "";
        LaunchpadService.close();
        if (Niri.inOverview)
            Niri.toggleOverview();
        if (root.niriBackend) {
            root.loading = false;
            root.windows = root.niriWindows();
            root.visible = true;
            root.updatePreviewTargets();
            return true;
        }
        root.loading = true;
        root._pendingOpen = true;
        root.captureSerial = Date.now();
        root.refresh();
        return true;
    }

    function close() {
        root.visible = false;
        root.loading = false;
        root._pendingOpen = false;
        root.error = "";
        root.releasePreviewTargets();
    }

    function toggle(screenName) {
        if (root.visible) {
            root.close();
            return false;
        }
        root.open(screenName);
        return root.visible || root.loading;
    }

    function refresh() {
        if (!root.available)
            return false;
        if (root.niriBackend) {
            root.windows = root.niriWindows();
            root.updatePreviewTargets();
            return true;
        }
        root._querySerial += 1;
        treeProcess.running = true;
        return true;
    }

    function niriWindows() {
        const result = [];
        for (const window of Niri.searchWindows("")) {
            const workspace = Niri.workspaceById(window.workspaceId) || {};
            const workspaceLabel = workspace.name ? String(workspace.name) : workspace.index !== undefined ? String(
                                                                                                                 workspace.index) :
                                                                                                             "";
            result.push({
                            "id": Number(window.id || 0),
                            "appId": String(window.appId || ""),
                            "appName": String(window.appName || ""),
                            "title": String(window.title || window.appName || window.appId || ""),
                            "workspace": workspaceLabel,
                            "fullscreen": !!window.fullscreen,
                            "focused": !!window.isFocused,
                            "output": String(workspace.output || "")
                        });
        }
        return result;
    }

    function updatePreviewTargets() {
        if (!root.niriBackend)
            return;
        if (!root.visible) {
            root.releasePreviewTargets();
            return;
        }
        if (!WindowPreviewService.supported)
            return;
        if (root._previewConsumer === "")
            root._previewConsumer = WindowPreviewService.createConsumer();
        WindowPreviewService.setTargets(root._previewConsumer, root.windows.map(window => String(window.id)));
    }

    function releasePreviewTargets() {
        if (root._previewConsumer !== "") {
            WindowPreviewService.release(root._previewConsumer);
            root._previewConsumer = "";
        }
    }

    function previewFrame(id) {
        return root.niriBackend ? WindowPreviewService.frameFor(id) : null;
    }

    function windowById(id) {
        if (root.niriBackend)
            return Niri.windowById(id);
        const key = Number(id);
        return root.windows.find(window => Number(window.id) === key) || null;
    }

    function focusWindow(id) {
        if (!root.windowById(id))
            return false;
        if (root.niriBackend) {
            const window = Niri.windowById(id);
            const ok = window.isMinimized ? Niri.restoreWindow(id, Niri.currentOutput || "") :
                                            Niri.focusWindow(id);
            if (ok)
                root.close();
            return ok;
        }
        root._closeAfterAction = true;
        return root.runAction("[con_id=" + Number(id) + "] focus");
    }

    function swapWindows(sourceId, targetId) {
        if (!root.windowById(sourceId) || !root.windowById(targetId))
            return false;
        if (root.niriBackend)
            return false;
        root._closeAfterAction = false;
        return root.runAction("[con_id=" + Number(sourceId) + "] swap container with con_id " + Number(
                                  targetId));
    }

    function toggleFullscreen(id) {
        const window = root.windowById(id);
        if (!window)
            return false;
        if (root.niriBackend) {
            const ok = Niri.toggleFullscreenWindow(id);
            if (ok)
                root.close();
            return ok;
        }
        root._closeAfterAction = true;
        return root.runAction("[con_id=" + Number(id) + "] fullscreen " + (window.fullscreen ? "disable" :
                                                                                               "enable"));
    }

    function toggleMaximize(id) {
        if (!root.windowById(id))
            return false;
        if (root.niriBackend) {
            const ok = Niri.toggleMaximizeWindow(id);
            if (ok)
                root.close();
            return ok;
        }
        const window = root.windowById(id);
        return root.runAction("[con_id=" + Number(id) + "] fullscreen " + (window.fullscreen ? "disable" :
                                                                                               "enable"));
    }

    function minimizeWindow(id) {
        if (!root.windowById(id))
            return false;
        if (root.niriBackend) {
            const ok = Niri.minimizeWindow(id);
            if (ok)
                root.close();
            return ok;
        }
        return false;
    }

    function closeWindow(id) {
        if (!root.windowById(id))
            return false;
        if (root.niriBackend) {
            const ok = Niri.closeWindow(id);
            if (ok)
                root.close();
            return ok;
        }
        return root.runAction("[con_id=" + Number(id) + "] kill");
    }

    function setFullscreen(id, enabled) {
        const window = root.windowById(id);
        if (!window)
            return false;
        if (root.niriBackend)
            return false;
        root._closeAfterAction = true;
        return root.runAction("[con_id=" + Number(id) + "] fullscreen " + (enabled ? "enable" : "disable"));
    }

    function runAction(command) {
        if (!root.available || actionProcess.running)
            return false;
        actionProcess.command = ["swaymsg", command];
        actionProcess.running = true;
        return true;
    }

    function parseTree(text) {
        let data = null;
        try {
            data = JSON.parse(String(text || ""));
        } catch (error) {
            root.error = qsTr("无法读取 Sway 窗口列表");
            root.windows = [];
            return;
        }
        const result = [];
        function walk(node, outputName, workspaceName) {
            if (!node)
                return;
            let output = outputName;
            let workspace = workspaceName;
            if (node.type === "output")
                output = String(node.name || "");
            else if (node.type === "workspace")
                workspace = String(node.name || "");
            if (node.type === "con" && node.rect && Number(node.rect.width) > 0 && Number(node.rect.height) > 0
                    && workspace !== "__i3_scratch") {
                const id = Number(node.id || 0);
                const appId = String(node.app_id || (node.window_properties ? node.window_properties.class
                                                                              || node.window_properties.instance :
                                                                              "") || "");
                if (id > 0 && appId !== "" && appId !== "org.quickshell-layer") {
                    result.push({
                                    id: id,
                                    appId: appId,
                                    title: String(node.name || appId),
                                    x: Number(node.rect.x || 0),
                                    y: Number(node.rect.y || 0),
                                    width: Number(node.rect.width || 0),
                                    height: Number(node.rect.height || 0),
                                    fullscreen: Number(node.fullscreen_mode || 0) !== 0,
                                    focused: !!node.focused,
                                    output: output,
                                    workspace: workspace
                                });
                }
            }
            const children = (node.nodes || []).concat(node.floating_nodes || []);
            for (const child of children)
                walk(child, output, workspace);
        }
        walk(data, "", "");
        root.windows = result;
    }

    function captureAll() {
        if (root.windows.length === 0) {
            root.startVisible();
            return;
        }
        const serial = root.captureSerial;
        const dir = root.thumbnailRoot + "/" + serial;
        let script = "mkdir -p '" + dir + "'";
        for (const window of root.windows) {
            const geometry = String(Math.round(window.x)) + "," + String(Math.round(window.y)) + " " + String(
                      Math.round(window.width)) + "x" + String(Math.round(window.height));
            const path = dir + "/" + String(window.id) + ".png";
            script += " && grim -g '" + geometry + "' '" + path + "' >/dev/null 2>&1 || true";
        }
        captureProcess.command = ["sh", "-c", script];
        captureProcess.running = true;
    }

    function startVisible() {
        if (!root._pendingOpen)
            return;
        root._pendingOpen = false;
        root.loading = false;
        root.visible = true;
    }

    Process {
        id: treeProcess

        command: ["swaymsg", "-t", "get_tree", "-r"]
        stdout: StdioCollector {
            id: treeOutput
        }
        onExited: exitCode => {
            const generation = root._querySerial;
            if (exitCode === 0)
            root.parseTree(treeOutput.text);
            else {
                root.error = qsTr("无法读取 Sway 窗口列表");
                root.windows = [];
            }
            if (root._pendingOpen && generation === root._querySerial)
            root.captureAll();
        }
    }

    Process {
        id: captureProcess

        command: []
        onExited: exitCode => {
            if (exitCode !== 0)
            root.error = qsTr("窗口缩略图捕获失败");
            root.startVisible();
        }
    }

    Process {
        id: actionProcess

        command: []
        onExited: exitCode => {
            if (exitCode !== 0)
            root.error = qsTr("窗口操作失败");
            if (root._closeAfterAction) {
                root._closeAfterAction = false;
                root.close();
            } else {
                refreshTimer.restart();
            }
        }
    }

    Timer {
        id: showTimer

        interval: 180
        onTriggered: root.startVisible()
    }

    Timer {
        id: refreshTimer

        interval: 140
        onTriggered: root.refresh()
    }

    Connections {
        target: Niri
        function onWindowsChanged() {
            if (root.niriBackend && root.visible)
                Qt.callLater(root.refresh);
        }
    }

    Connections {
        target: WindowPreviewService
        function onConnectedChanged() {
            if (root.niriBackend && root.visible)
                Qt.callLater(root.updatePreviewTargets);
        }
    }
}
