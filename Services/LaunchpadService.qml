pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../Common/functions/LaunchpadLayout.js" as Layout
import "../Common/functions/SpotlightLocalSearch.js" as LocalSearch

Singleton {
    id: root

    readonly property string filePath: Paths.configHome + "/launchpad.json"
    readonly property int capacity: Math.max(1, root.columns * root.rows)
    readonly property int pageCount: Layout.pageCount(root.items.length, root.capacity)
    readonly property var pages: {
        const count = root.pageCount;
        const result = [];
        for (let index = 0; index < count; index += 1)
        result.push(Layout.pageSlice(root.items, index, root.capacity));
        return result;
    }

    property bool visible: false
    property string targetScreenName: ""
    property string query: ""
    property int page: 0
    property int columns: 7
    property int rows: 5
    property bool editing: false
    property string openFolderId: ""
    property var layout: ({
                              items: [],
                              hidden: []
                          })
    readonly property var items: root.layout.items || []
    readonly property var hidden: root.layout.hidden || []
    property var applications: []
    readonly property var appIds: root.applications.map(application => String(application.id))
    readonly property var appById: {
        const result = Object.create(null);
        for (const application of root.applications)
        result[String(application.id)] = application;
        return result;
    }
    readonly property var openFolder: root.openFolderId === "" ? null : root.items.find(item => item.id
                                                                                        === root.openFolderId
                                                                                        && item.type
                                                                                        === "folder") || null
    readonly property bool canSearch: root.query.trim() !== ""

    property bool ready: false
    property bool writable: false
    property bool storeReady: false
    property bool loadedFromDisk: false
    signal removalRequested(string applicationId)

    property int sessionSerial: 0
    property bool pendingLayoutReady: false
    property var pendingLayout: null

    onPageCountChanged: root.clampPage()
    onCapacityChanged: root.clampPage()

    function clampPage() {
        root.page = Math.max(0, Math.min(root.page, root.pageCount - 1));
    }

    function setQuery(value) {
        root.query = String(value || "");
    }

    function setGrid(columns, rows) {
        const nextColumns = Math.max(3, Math.min(10, Math.floor(Number(columns) || root.columns)));
        const nextRows = Math.max(2, Math.min(8, Math.floor(Number(rows) || root.rows)));
        if (root.columns === nextColumns && root.rows === nextRows)
            return;
        root.columns = nextColumns;
        root.rows = nextRows;
        root.clampPage();
    }

    function open(screenName) {
        const screens = Array.from(Quickshell.screens || []);
        const requested = String(screenName || "");
        const screen = screens.find(candidate => String(candidate.name) === requested) || screens[0] || null;
        root.targetScreenName = screen ? String(screen.name) : "";
        root.visible = true;
        root.query = "";
        root.page = 0;
        root.editing = false;
        root.openFolderId = "";
        root.sessionSerial += 1;
    }

    function close() {
        root.query = "";
        root.editing = false;
        root.openFolderId = "";
        root.visible = false;
    }

    function toggle(screenName) {
        if (root.visible)
            root.close();
        else
            root.open(screenName);
        return root.visible;
    }

    function goToPage(index) {
        root.page = Math.max(0, Math.min(Number(index) || 0, root.pageCount - 1));
    }

    function nextPage() {
        root.goToPage(root.page + 1);
    }

    function previousPage() {
        root.goToPage(root.page - 1);
    }

    function beginEditing() {
        if (!root.visible)
            return;
        root.editing = true;
    }

    function endEditing() {
        root.editing = false;
    }

    function toggleEditing() {
        root.editing = !root.editing;
    }

    function openFolderById(folderId) {
        if (!root.items.find(item => item.id === folderId && item.type === "folder"))
            return false;
        root.editing = false;
        root.openFolderId = String(folderId);
        return true;
    }

    function closeFolder() {
        root.openFolderId = "";
    }

    function folderForApp(appId) {
        for (const item of root.items) {
            if (item.type !== "folder")
                continue;
            if (item.items.some(child => child.id === appId))
                return item;
        }
        return null;
    }

    function applicationFor(id) {
        return root.appById[String(id)] || null;
    }

    function searchResults(value) {
        const needle = String(value === undefined ? root.query : value).trim();
        if (needle === "")
            return [];
        return LocalSearch.appResults(root.applications, needle, "smart", SpotlightAppUsage.records, Date.now(
                                          ));
    }

    function launch(id) {
        const identifier = String(id || "");
        if (identifier === "" || !SpotlightAppUsage.launch(identifier))
            return false;
        // Launching from a touch tap closes (unmaps) this fullscreen surface.
        // Defer the close until Qt has finished delivering the tap event.
        Qt.callLater(() => root.close());
        return true;
    }

    function applyLayout(next, save) {
        const previous = root.layout;
        root.layout = next;
        if (save)
            root.save();
        if (root.openFolderId !== "" && !next.items.some(item => item.type === "folder" && item.id
                                                         === root.openFolderId))
            root.openFolderId = "";
        return previous !== next;
    }

    function moveApp(sourceId, targetId, targetIndex) {
        const next = Layout.moveApp(root.layout, String(sourceId || ""), String(targetId || ""), Number(
                                        targetIndex) || 0, qsTr("Folder"));
        return root.applyLayout(next, true);
    }

    function reorder(sourceId, targetIndex) {
        return root.applyLayout(Layout.reorder(root.layout, String(sourceId || ""), Number(targetIndex) || 0),
                                true);
    }

    function moveToIndex(sourceId, targetIndex) {
        const sourceIndex = Layout.findIndex(root.items, String(sourceId || ""));
        const destination = sourceIndex >= 0 && sourceIndex < targetIndex ? targetIndex - 1 : targetIndex;
        return root.reorder(sourceId, destination);
    }

    function renameFolder(folderId, name) {
        const next = Layout.renameFolder(root.layout, String(folderId || ""), String(name || ""));
        return root.applyLayout(next, true);
    }

    function removeFromFolder(folderId, appId) {
        const next = Layout.releaseFromFolder(root.layout, String(folderId || ""), String(appId || ""));
        return root.applyLayout(next, true);
    }

    function reorderInFolder(folderId, appId, targetIndex) {
        return root.applyLayout(Layout.reorderFolder(root.layout, String(folderId || ""), String(appId || ""),
                                                     Number(targetIndex) || 0), true);
    }

    function hideApplication(appId) {
        const next = Layout.hideApplication(root.layout, String(appId || ""));
        return root.applyLayout(next, true);
    }

    function removeApplication(appId) {
        const next = Layout.removeApplication(root.layout, String(appId || ""));
        return root.applyLayout(next, true);
    }

    function requestRemoval(appId) {
        if (!root.applicationFor(appId))
            return false;
        if (!root.visible)
            root.open(root.targetScreenName);
        Qt.callLater(() => root.removalRequested(String(appId)));
        return true;
    }

    function restoreApplication(appId) {
        const next = Layout.restoreApplication({
                                                   items: Layout.cloneItems(root.layout.items),
                                                   hidden: Array.from(root.layout.hidden || [])
                                               }, String(appId || ""));
        return root.applyLayout(next, true);
    }

    function restoreHidden() {
        if (root.appIds.length === 0)
            return false;
        let next = {
            items: Layout.cloneItems(root.layout.items),
            hidden: Array.from(root.layout.hidden || [])
        };
        for (const id of Array.from(root.layout.hidden || [])) {
            if (root.appIds.indexOf(id) >= 0)
                next = Layout.restoreApplication(next, id);
        }
        next.hidden = [];
        return root.applyLayout(next, true);
    }

    function reset() {
        const next = Layout.reconcile({
                                          items: [],
                                          hidden: []
                                      }, root.appIds, []);
        root.editing = false;
        root.openFolderId = "";
        return root.applyLayout(next, true);
    }

    function save() {
        if (!root.ready || !root.writable || !root.storeReady)
            return;
        configFile.setText(Layout.encode(root.layout));
    }

    function applyLoadedLayout(layout) {
        const next = Layout.reconcile(layout || {
                                          items: [],
                                          hidden: []
                                      }, root.appIds, layout ? layout.hidden : []);
        root.layout = next;
        if (!layout)
            root.save();
    }

    function loaded(layout, canWrite, error) {
        root.writable = canWrite;
        root.ready = true;
        root.loadedFromDisk = layout !== null;
        // ApplicationService populates asynchronously. Reconcile only after it
        // is ready, otherwise an empty app list would erase the saved order.
        if (root.applications.length === 0) {
            root.pendingLayout = layout || {
                items: [],
                hidden: []
            };
            root.pendingLayoutReady = true;
            return;
        }
        root.applyLoadedLayout(layout);
    }

    function refreshApplications() {
        root.applications = ApplicationService.launcherApplications.filter(application => {
                                                                               return application &&
                                                                               !application.dragOnly && String(
                                                                                   application.id || "")
                                                                               !== "";
                                                                           });
        if (root.pendingLayoutReady) {
            const pending = root.pendingLayout;
            root.pendingLayoutReady = false;
            root.pendingLayout = null;
            root.applyLoadedLayout(pending);
            return;
        }
        if (!root.ready)
            return;
        // A transient empty DesktopEntries read must not erase the saved order.
        if (root.appIds.length === 0 && root.layout.items.length > 0)
            return;
        const next = Layout.reconcile(root.layout, root.appIds, root.layout.hidden || []);
        if (JSON.stringify(next.items) !== JSON.stringify(root.layout.items) || JSON.stringify(next.hidden)
                !== JSON.stringify(root.layout.hidden))
            root.applyLayout(next, true);
    }

    Connections {
        target: ApplicationService
        function onLauncherApplicationsChanged() {
            root.refreshApplications();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.refreshApplications();
        }
    }

    Component.onCompleted: root.refreshApplications()

    Process {
        command: ["mkdir", "-p", Paths.configHome]
        running: true
        onExited: exitCode => {
            if (exitCode === 0) {
                root.storeReady = true;
            } else {
                console.warn("LaunchpadService: configuration directory unavailable; using session layout");
                root.loaded(null, false, "");
            }
        }
    }

    FileView {
        id: configFile

        path: root.storeReady ? root.filePath : ""
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.writable = false;
            configFile.reload();
        }
        onLoaded: {
            const layout = Layout.decode(configFile.text());
            if (layout === null) {
                console.warn("LaunchpadService: invalid layout; preserving file and using default layout");
                root.loaded(null, false, "");
                return;
            }
            root.loaded(layout, true, "");
        }
        onLoadFailed: error => {
            if (!root.storeReady)
            return;
            const missing = error === FileViewError.FileNotFound;
            root.loaded(null, missing, missing ? "" : qsTr("Launchpad layout could not be read."));
            if (!missing)
            console.warn("LaunchpadService: cannot read layout:", error);
        }
        onSaveFailed: error => {
            root.writable = false;
            console.warn("LaunchpadService: cannot save layout:", error);
        }
    }
}
