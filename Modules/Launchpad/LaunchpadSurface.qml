pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Modules.Launchpad
import qs.Services
import qs.Widgets.common
import "../../Common/functions/LaunchpadLayout.js" as LaunchpadLayout
import "../../Common/functions/SwipeTracker.js" as Swipe

FocusScope {
    id: surface

    required property var targetScreen

    readonly property string screenName: surface.targetScreen ? String(surface.targetScreen.name) : ""
    readonly property string wallpaperPath: {
        const configured = surface.screenName === "" ? "" : WallpaperService.wallpaperForScreen(
                                                           surface.screenName);
        return configured !== "" ? configured : PlatformService.desktopWallpaper;
    }
    readonly property bool wallpaperIsImage: WallpaperService.isImagePath(surface.wallpaperPath)
    readonly property bool wallpaperIsColor: WallpaperService.isColorSource(surface.wallpaperPath)
    readonly property bool searchMode: LaunchpadService.canSearch
    readonly property bool folderOpen: LaunchpadService.openFolder !== null
    // Only the surface whose screen owns the current Launchpad session may
    // drive global paging/grid state. Every screen gets a surface instance,
    // so without this guard the last monitor constructed would win.
    readonly property bool activeSurface: LaunchpadService.visible && surface.screenName !== ""
                                          && surface.screenName === LaunchpadService.targetScreenName
    readonly property var searchResults: surface.searchMode ? LaunchpadService.searchResults(
                                                                  LaunchpadService.query).slice(0, 120) : []
    readonly property var folderEntries: {
        const folder = LaunchpadService.openFolder;
        if (!folder)
        return [];
        return (folder.items || []).map(child => surface.entryForApplication(child.id)).filter(entry => entry
                                                                                               !== null);
    }

    readonly property bool touchLayout: PlatformService.touchOptimized || Math.min(surface.width,
                                                                                   surface.height) <= 900
                                        || surface.height / Math.max(1, surface.width) >= 1.45
    readonly property real touchTarget: surface.touchLayout ? 56 : 48
    readonly property real sideMargin: Math.max(surface.touchTarget * 0.5, Math.min(88, surface.width
                                                                                    * 0.045))

    readonly property real headerHeight: Math.max(48, Math.min(58, surface.height * 0.055))
    readonly property real headerTop: Math.max(18, Math.min(44, surface.height * 0.035))
    readonly property real dotsHeight: 42
    readonly property real pagerTop: surface.headerTop + surface.headerHeight + Math.max(12, surface.height
                                                                                         * 0.02)
    readonly property real pagerBottom: surface.height - surface.dotsHeight - Math.max(8, surface.height
                                                                                       * 0.012)
    readonly property real pagerWidth: Math.max(1, surface.width - surface.sideMargin * 2)
    readonly property real pagerHeight: Math.max(120, surface.pagerBottom - surface.pagerTop)
    readonly property int columns: Math.max(3, Math.min(8, Math.floor(surface.pagerWidth / (
                                                                          surface.touchLayout ? 168 : 154))))
    readonly property int rows: Math.max(2, Math.min(5, Math.floor(surface.pagerHeight / (surface.touchLayout
                                                                                          ? 176 : 162))))
    readonly property real cellWidth: surface.pagerWidth / surface.columns
    readonly property real cellHeight: surface.pagerHeight / surface.rows
    readonly property real searchWidth: Math.min(620, Math.max(240, surface.width - surface.sideMargin * 2))

    property real openProgress: 0
    property bool closing: false
    property bool pageDragging: false
    property real pagePosition: LaunchpadService.page
    property real dragStartPage: 0
    property real dragLastX: 0
    property real dragLastTime: 0
    property real dragVelocity: 0
    property int pageSnapDuration: 400
    property bool tileDragging: false
    property var dragEntry: null
    property string dragSourceId: ""
    property point dragPoint: Qt.point(0, 0)
    property int dropPage: -1
    property int dropCell: -1
    property int dropIndex: -1
    property string dropTargetId: ""
    property int dropEdge: 0
    property string selectedId: ""
    property int searchSelected: 0
    property string contextId: ""
    property real wheelAccumulator: 0
    property string pendingRemovalId: ""
    property var pendingRemovalApplication: null
    property string removalError: ""
    property bool removalInProgress: false
    readonly property bool pendingRemovalCanUninstall: surface.pendingRemovalApplication !== null
                                                       && ApplicationService.canUninstall(
                                                           surface.pendingRemovalApplication)

    anchors.fill: parent
    focus: true

    function entryForApplication(id) {
        const application = LaunchpadService.applicationFor(id);
        if (!application)
            return null;
        return {
            kind: "app",
            id: String(application.id),
            title: String(application.name || application.id),
            icon: String(application.icon || ""),
            symbol: String(application.symbol || ""),
            application: application
        };
    }

    function entryForItem(item) {
        if (!item)
            return null;
        if (item.type === "folder") {
            const applications = [];
            for (const child of item.items || []) {
                const application = LaunchpadService.applicationFor(child.id);
                if (application)
                    applications.push(application);
            }
            return {
                kind: "folder",
                id: String(item.id),
                title: String(item.name || qsTr("Folder")),
                applications: applications
            };
        }
        return surface.entryForApplication(item.id);
    }

    function pageEntries(index) {
        return (LaunchpadService.pages[index] || []).map(item => surface.entryForItem(item)).filter(entry
                                                                                                    => entry
                                                                                                    !== null);
    }

    function currentEntries() {
        return surface.searchMode ? surface.searchResults : surface.pageEntries(LaunchpadService.page);
    }

    function resetSelection() {
        const entries = surface.currentEntries();
        surface.selectedId = entries.length > 0 ? String(entries[0].id) : "";
    }

    function selectPageStart() {
        const entries = surface.pageEntries(LaunchpadService.page);
        surface.selectedId = entries.length > 0 ? String(entries[0].id) : "";
    }

    function moveSelection(dx, dy) {
        if (surface.searchMode || surface.folderOpen)
            return;
        const items = LaunchpadService.items;
        if (items.length === 0)
            return;
        let index = LaunchpadLayout.findIndex(items, surface.selectedId);
        if (index < 0)
            index = 0;
        const page = Math.floor(index / LaunchpadService.capacity);
        const cell = index % LaunchpadService.capacity;
        const column = cell % surface.columns;
        let next = index;

        if (dx !== 0) {
            if (column + dx < 0) {
                if (page > 0)
                    next = (page - 1) * LaunchpadService.capacity + LaunchpadService.capacity - 1;
            } else if (column + dx >= surface.columns) {
                if (page < LaunchpadService.pageCount - 1)
                    next = (page + 1) * LaunchpadService.capacity;
            } else {
                next = index + dx;
            }
        } else if (dy !== 0) {
            if (index + dy * surface.columns >= 0)
                next = index + dy * surface.columns;
        }

        next = Math.max(0, Math.min(next, items.length - 1));
        surface.selectedId = String(items[next].id);
        LaunchpadService.goToPage(Math.floor(next / LaunchpadService.capacity));
        surface.pagePosition = LaunchpadService.page;
    }

    function activateId(id) {
        const item = LaunchpadService.items.find(candidate => candidate.id === id);
        if (item && item.type === "folder")
            LaunchpadService.openFolderById(item.id);
        else
            LaunchpadService.launch(id);
    }

    function activateSelected() {
        if (surface.folderOpen)
            return;
        if (surface.searchMode) {
            surface.activateSearch();
            return;
        }
        if (surface.selectedId !== "")
            surface.activateId(surface.selectedId);
    }

    function activateSearch() {
        if (surface.searchResults.length === 0)
            return;
        const index = Math.max(0, Math.min(surface.searchSelected, surface.searchResults.length - 1));
        LaunchpadService.launch(surface.searchResults[index].id);
    }

    function searchMove(delta) {
        if (surface.searchResults.length === 0)
            return;
        surface.searchSelected = Math.max(0, Math.min(surface.searchResults.length - 1, surface.searchSelected
                                                      + delta));
    }

    function handleEscape() {
        if (removalDialog.visible) {
            removalDialog.close();
            return;
        }
        if (surface.folderOpen) {
            LaunchpadService.closeFolder();
            Qt.callLater(() => searchInput.forceActiveFocus());
            return;
        }
        if (LaunchpadService.editing) {
            LaunchpadService.endEditing();
            return;
        }
        if (LaunchpadService.query !== "") {
            LaunchpadService.setQuery("");
            searchInput.forceActiveFocus();
            return;
        }
        surface.requestClose();
    }

    function requestClose() {
        if (surface.closing || !LaunchpadService.visible)
            return;
        surface.closing = true;
        closeAnimation.restart();
    }

    function removeRequested(id) {
        if (surface.folderOpen) {
            const folder = LaunchpadService.openFolder;
            if (folder)
                LaunchpadService.removeFromFolder(folder.id, id);
            return;
        }
        surface.requestApplicationRemoval(id);
    }

    function requestApplicationRemoval(id) {
        const application = LaunchpadService.applicationFor(id);
        if (!application || application.dragOnly)
            return;
        surface.pendingRemovalId = String(id);
        surface.pendingRemovalApplication = application;
        surface.removalError = "";
        surface.removalInProgress = false;
        removalDialog.open();
    }

    function hidePendingApplication() {
        if (surface.pendingRemovalId !== "")
            LaunchpadService.hideApplication(surface.pendingRemovalId);
        surface.resetSelection();
        removalDialog.close();
    }

    function confirmApplicationRemoval() {
        if (surface.pendingRemovalId === "" || surface.removalInProgress)
            return;
        if (!surface.pendingRemovalCanUninstall) {
            surface.hidePendingApplication();
            return;
        }
        surface.removalError = "";
        surface.removalInProgress = ApplicationService.uninstallApplication(
                    surface.pendingRemovalApplication);
        if (!surface.removalInProgress)
            surface.removalError = ApplicationService.uninstallError || qsTr(
                        "The application could not be uninstalled.");
    }

    function openContext(id) {
        surface.contextId = String(id || "");
        tileMenu.popup();
    }

    function openBackgroundContext() {
        backgroundMenu.popup();
    }

    function updateDrop(scenePoint) {
        surface.dragPoint = scenePoint;
        if (surface.folderOpen) {
            surface.dropPage = -1;
            surface.dropEdge = 0;
            if (!folderLoader.item || !folderLoader.item.containsScenePoint(scenePoint)) {
                surface.dropTargetId = "";
                surface.dropIndex = -1;
                return;
            }
            const folderIndex = folderLoader.item.indexAtScenePoint(scenePoint);
            surface.dropIndex = folderIndex >= 0 ? folderIndex : surface.folderEntries.length;
            surface.dropTargetId = folderIndex >= 0 && folderIndex < surface.folderEntries.length ? String(
                                                                                                        surface.folderEntries[folderIndex].id) :
                                                                                                    "";
            return;
        }

        const local = pagerArea.mapFromItem(null, scenePoint.x, scenePoint.y);
        const contentX = local.x + surface.pagePosition * pagerArea.width;
        const page = Math.max(0, Math.min(surface.pageCountForDrop(contentX), LaunchpadService.pageCount
                                          - 1));
        const pageX = contentX - page * pagerArea.width;
        const column = Math.max(0, Math.min(surface.columns - 1, Math.floor(pageX / surface.cellWidth)));
        const row = Math.max(0, Math.min(surface.rows - 1, Math.floor(local.y / surface.cellHeight)));
        const cell = row * surface.columns + column;
        const entries = LaunchpadService.pages[page] || [];
        const target = entries[cell] || null;
        surface.dropPage = page;
        surface.dropCell = cell;
        surface.dropIndex = page * LaunchpadService.capacity + Math.min(cell, entries.length);
        surface.dropTargetId = target ? String(target.id) : "";
        surface.dropEdge = local.y > 0 && local.y < pagerArea.height && local.x < 64 && page > 0 ? -1 : (
                                                                                                       local.y > 0
                                                                                                       && local.y
                                                                                                       < pagerArea.height
                                                                                                       && local.x
                                                                                                       > pagerArea.width
                                                                                                       - 64 && page
                                                                                                       < LaunchpadService.pageCount
                                                                                                       - 1 ? 1 : 0);
    }

    function beginTileDrag(id, scenePoint, entry) {
        surface.tileDragging = true;
        surface.dragSourceId = String(id);
        surface.dragEntry = entry;
        surface.dragPoint = scenePoint;
        surface.dropPage = -1;
        surface.dropCell = -1;
        surface.dropIndex = -1;
        surface.dropTargetId = "";
        surface.dropEdge = 0;
        surface.pagePosition = LaunchpadService.page;
        surface.updateDrop(scenePoint);
    }

    function moveTileDrag(scenePoint) {
        if (!surface.tileDragging)
            return;
        surface.updateDrop(scenePoint);
    }

    function finishTileDrag(scenePoint) {
        if (!surface.tileDragging)
            return;
        surface.updateDrop(scenePoint);
        const sourceId = surface.dragSourceId;
        if (surface.folderOpen) {
            const folder = LaunchpadService.openFolder;
            if (folder) {
                if (folderLoader.item && folderLoader.item.containsScenePoint(scenePoint)) {
                    const targetIndex = surface.dropIndex >= 0 ? surface.dropIndex :
                                                                 surface.folderEntries.length;


                    LaunchpadService.reorderInFolder(folder.id, sourceId, targetIndex);
                } else {
                    LaunchpadService.removeFromFolder(folder.id, sourceId);
                }
            }
        } else if (surface.dropTargetId !== "" && surface.dropTargetId !== sourceId) {
            LaunchpadService.moveApp(sourceId, surface.dropTargetId, surface.dropIndex);
        } else if (surface.dropIndex >= 0) {
            LaunchpadService.moveToIndex(sourceId, surface.dropIndex);
        }
        surface.tileDragging = false;
        surface.dragEntry = null;
        surface.dragSourceId = "";
        surface.dropPage = -1;
        surface.dropCell = -1;
        surface.dropIndex = -1;
        surface.dropTargetId = "";
        surface.dropEdge = 0;
        surface.pagePosition = LaunchpadService.page;
        surface.resetSelection();
    }

    function finishPageDrag() {
        if (!surface.pageDragging)
            return;
        const relative = surface.pagePosition - surface.dragStartPage;
        const progressVelocity = -surface.dragVelocity / Math.max(1, pageArea.width);
        let target = Swipe.target(surface.dragStartPage, relative, progressVelocity);
        target = Math.max(0, Math.min(LaunchpadService.pageCount - 1, target));
        surface.pageSnapDuration = Swipe.snapDuration(relative, target - surface.dragStartPage,
                                                      progressVelocity);
        surface.pageDragging = false;
        surface.pagePosition = target;
        LaunchpadService.goToPage(target);
        surface.selectPageStart();
    }

    function pageCountForDrop(contentX) {
        return Math.floor(contentX / pagerArea.width);
    }

    function goToPage(index) {
        LaunchpadService.goToPage(index);
        surface.pagePosition = LaunchpadService.page;
        surface.selectPageStart();
    }

    function onOpened() {
        if (!surface.activeSurface)
            return;
        removalDialog.close();
        closeAnimation.stop();
        surface.closing = false;
        surface.openProgress = 0;
        LaunchpadService.setGrid(surface.columns, surface.rows);
        surface.pagePosition = LaunchpadService.page;
        surface.resetSelection();
        surface.searchSelected = 0;
        openAnimation.restart();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    Component.onCompleted: {
        if (surface.activeSurface)
        surface.onOpened();
    }

    onColumnsChanged: if (surface.activeSurface)
    LaunchpadService.setGrid(surface.columns, surface.rows)
    onRowsChanged: if (surface.activeSurface)
    LaunchpadService.setGrid(surface.columns, surface.rows)
    onSearchResultsChanged: {
        if (surface.searchResults.length === 0)
        surface.searchSelected = 0;
        else
        surface.searchSelected = Math.max(0, Math.min(surface.searchSelected, surface.searchResults.length
                                                      - 1));

    }

    Connections {
        target: LaunchpadService
        function onTargetScreenNameChanged() {
            if (surface.activeSurface)
                surface.onOpened();
        }
        function onRemovalRequested(applicationId) {
            surface.requestApplicationRemoval(applicationId);
        }
        function onSessionSerialChanged() {
            if (surface.activeSurface) {
                removalDialog.close();
                tileMenu.close();
                backgroundMenu.close();
            }
        }
        function onVisibleChanged() {
            if (surface.activeSurface)
                surface.onOpened();
            else if (!LaunchpadService.visible) {
                surface.closing = false;
                surface.openProgress = 0;
                surface.tileDragging = false;
                surface.dragEntry = null;
                tileMenu.close();
                backgroundMenu.close();
                removalDialog.close();
            }
        }
        function onPageChanged() {
            if (surface.activeSurface && !surface.pageDragging && !surface.tileDragging)
                surface.pagePosition = LaunchpadService.page;
            if (surface.activeSurface)
                surface.selectPageStart();
        }
        function onQueryChanged() {
            surface.searchSelected = 0;
            if (LaunchpadService.query === "")
                surface.resetSelection();
        }
        function onOpenFolderIdChanged() {
            if (LaunchpadService.openFolder === null) {
                surface.tileDragging = false;
                surface.dragEntry = null;
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                Qt.callLater(() => {
                                 if (folderLoader.item)
                                 folderLoader.item.forceActiveFocus();
                             });
            }
        }
    }

    Connections {
        target: SpotlightAppUsage
        function onRecordsChanged() {
            if (surface.searchMode)
                surface.searchSelected = 0;
        }
    }

    Connections {
        target: ApplicationService

        function onUninstallFinished(applicationId, succeeded, message) {
            if (String(applicationId) !== surface.pendingRemovalId)
                return;
            surface.removalInProgress = false;
            if (succeeded) {
                LaunchpadService.removeApplication(surface.pendingRemovalId);
                surface.resetSelection();
                removalDialog.close();
            } else {
                surface.removalError = message || qsTr("The application could not be uninstalled.");
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors.m3background
    }

    Rectangle {
        anchors.fill: parent
        visible: surface.wallpaperIsColor
        color: surface.wallpaperIsColor ? surface.wallpaperPath : Appearance.m3colors.m3background
    }

    Image {
        id: wallpaperImage

        anchors.fill: parent
        source: surface.wallpaperIsImage ? Paths.fileUrl(surface.wallpaperPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
        sourceSize.width: 640
        sourceSize.height: Math.max(1, Math.round(640 * surface.height / Math.max(1, surface.width)))
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaperImage
        visible: wallpaperImage.status === Image.Ready
        blurEnabled: true
        blur: 0.85
        blurMax: 64
        saturation: 0.9
        opacity: 0.9
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.12)
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(0, 0, 0, 0.22)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.42)
            }
        }
    }

    Item {
        id: interactionLayer

        anchors.fill: parent
        opacity: surface.openProgress
        scale: 0.985 + 0.015 * surface.openProgress
        transformOrigin: Item.Center

        Item {
            id: pageArea

            x: surface.sideMargin
            y: surface.pagerTop
            width: surface.pagerWidth
            height: surface.pagerHeight
            visible: !surface.searchMode
            clip: true

            Item {
                id: pagesTrack

                x: -surface.pagePosition * pageArea.width
                width: pageArea.width * Math.max(1, LaunchpadService.pageCount)
                height: pageArea.height

                Repeater {
                    model: LaunchpadService.pageCount

                    delegate: LaunchpadPage {
                        required property int index

                        x: index * pageArea.width
                        width: pageArea.width
                        height: pageArea.height
                        columns: surface.columns
                        rows: surface.rows
                        cellWidth: surface.cellWidth
                        cellHeight: surface.cellHeight
                        entries: surface.pageEntries(index)
                        editing: LaunchpadService.editing
                        selectedId: surface.selectedId
                        dropTargetId: surface.dropTargetId

                        onActivated: id => surface.activateId(id)
                        onEditRequested: LaunchpadService.beginEditing()
                        onRemoveRequested: id => surface.removeRequested(id)
                        onContextRequested: id => surface.openContext(id)
                        onDragStarted: (id, point, entry) => surface.beginTileDrag(id, point, entry)
                        onDragMoved: point => surface.moveTileDrag(point)
                        onDragFinished: point => surface.finishTileDrag(point)
                    }
                }
            }

            Rectangle {
                id: dropIndicator

                visible: surface.tileDragging && surface.dropPage >= 0
                x: surface.dropPage * pageArea.width + (surface.dropCell % surface.columns)
                   * surface.cellWidth - surface.pagePosition * pageArea.width + 6
                y: Math.floor(surface.dropCell / surface.columns) * surface.cellHeight + 6
                width: surface.cellWidth - 12
                height: surface.cellHeight - 12
                radius: 24
                color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.4)
                z: 20
            }
        }

        LaunchpadSearchGrid {
            id: searchGrid

            visible: surface.searchMode
            x: surface.sideMargin
            y: surface.pagerTop
            width: surface.pagerWidth
            height: surface.pagerHeight
            tileWidth: surface.cellWidth
            tileHeight: surface.cellHeight
            results: surface.searchResults
            selectedIndex: surface.searchSelected
            editing: LaunchpadService.editing

            onActivationRequested: index => {
                if (index >= 0 && index < surface.searchResults.length)
                LaunchpadService.launch(surface.searchResults[index].id);
            }
            onSelectionRequested: index => surface.searchSelected = index
            onContextRequested: index => {
                if (index >= 0 && index < surface.searchResults.length)
                surface.openContext(surface.searchResults[index].id);
            }
        }

        Text {
            anchors.centerIn: searchGrid
            visible: surface.searchMode && surface.searchResults.length === 0
            text: qsTr("No applications found")
            color: Qt.rgba(1, 1, 1, 0.66)
            font.family: Fonts.ui
            font.pixelSize: 18
        }

        Item {
            id: searchBar

            x: Math.round((surface.width - surface.searchWidth) / 2)
            y: surface.headerTop
            width: surface.searchWidth
            height: surface.headerHeight

            Rectangle {
                anchors.fill: parent
                radius: parent.height * 0.34
                color: Qt.rgba(0, 0, 0, 0.3)
                border.width: 1
                border.color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.18)
            }

            MaterialSymbol {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                iconSize: 22
                color: Qt.rgba(1, 1, 1, 0.72)
            }

            TextField {
                id: searchInput

                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: clearButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                text: LaunchpadService.query
                placeholderText: qsTr("Search applications")
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.52)
                color: "#ffffffff"
                selectionColor: Appearance.m3colors.m3primary
                selectedTextColor: Appearance.m3colors.m3onPrimary
                font.family: Fonts.ui
                font.pixelSize: Math.max(15, Math.min(19, parent.height * 0.34))
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                background: Item {}
                onTextChanged: {
                    if (text !== LaunchpadService.query)
                    LaunchpadService.setQuery(text);
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        surface.handleEscape();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        if (LaunchpadService.query === "")
                        surface.moveSelection(0, 1);
                        else
                        surface.searchMove(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        if (LaunchpadService.query === "")
                        surface.moveSelection(0, -1);
                        else
                        surface.searchMove(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (LaunchpadService.query === "")
                        surface.activateSelected();
                        else
                        surface.activateSearch();
                        event.accepted = true;
                    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Left
                                                                          || event.key === Qt.Key_Right)) {
                        surface.goToPage(LaunchpadService.page + (event.key === Qt.Key_Left ? -1 : 1));
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                               && LaunchpadService.query === "") {
                        surface.moveSelection(event.key === Qt.Key_Left ? -1 : 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown && LaunchpadService.query === "") {
                        surface.goToPage(LaunchpadService.page + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp && LaunchpadService.query === "") {
                        surface.goToPage(LaunchpadService.page - 1);
                        event.accepted = true;
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                        searchInput.selectAll();
                        event.accepted = true;
                    }
                }
            }

            Item {
                id: clearButton

                width: 44
                height: parent.height
                anchors.right: parent.right
                visible: LaunchpadService.query !== ""

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 18
                    color: Qt.rgba(1, 1, 1, 0.7)
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        LaunchpadService.setQuery("");
                        searchInput.forceActiveFocus();
                    }
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: searchInput.forceActiveFocus()
            }
        }

        Row {
            id: pageDots

            visible: !surface.searchMode
            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.pagerBottom + 4
            height: surface.dotsHeight
            spacing: 0

            Repeater {
                model: LaunchpadService.pageCount

                delegate: Item {
                    required property int index

                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: index === LaunchpadService.page ? 22 : 8
                        height: 8
                        radius: 4
                        color: index === LaunchpadService.page ? "#ffffffff" : Qt.rgba(1, 1, 1, 0.42)

                        Behavior on width {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: surface.goToPage(index)
                    }
                }
            }
        }

        Rectangle {
            id: backgroundHit

            anchors.fill: parent
            color: "transparent"
            z: -1

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (eventPoint, button) => {
                    if (button === Qt.RightButton) {
                        surface.openBackgroundContext();
                        return;
                    }
                    if (surface.folderOpen) {
                        LaunchpadService.closeFolder();
                        return;
                    }
                    if (LaunchpadService.editing) {
                        LaunchpadService.endEditing();
                        return;
                    }
                    if (surface.searchMode) {
                        LaunchpadService.setQuery("");
                        searchInput.forceActiveFocus();
                        return;
                    }
                    surface.requestClose();
                }
            }
        }
    }

    Loader {
        id: folderLoader

        active: LaunchpadService.openFolder !== null
        anchors.fill: parent
        onLoaded: if (item)
        item.forceActiveFocus()

        sourceComponent: LaunchpadFolderOverlay {
            folder: LaunchpadService.openFolder
            entries: surface.folderEntries
            editing: LaunchpadService.editing
            dragActive: surface.tileDragging
            dropTargetId: surface.dropTargetId

            onActivated: id => surface.activateId(id)
            onEditRequested: LaunchpadService.beginEditing()
            onRemoveRequested: id => surface.removeRequested(id)
            onRenameRequested: name => LaunchpadService.renameFolder(LaunchpadService.openFolder
                                                                     ? LaunchpadService.openFolder.id : "",
                                                                     name)
            onDragStarted: (id, point, entry) => surface.beginTileDrag(id, point, entry)
            onDragMoved: point => surface.moveTileDrag(point)
            onDragFinished: point => surface.finishTileDrag(point)
            onCloseRequested: {
                LaunchpadService.closeFolder();
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }
    }

    // GNOME-style top edge swipe: dragging down from the top edge dismisses
    // the overlay, matching the touchscreen "exit fullscreen" gesture.
    Item {
        id: topEdgeGesture

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        z: 200

        DragHandler {
            id: topEdgeDrag

            target: null
            enabled: surface.touchLayout
            yAxis.enabled: true
            xAxis.enabled: false
            dragThreshold: 8
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            property real lastTranslationY: 0

            onActiveChanged: {
                if (active)
                lastTranslationY = 0;
                else if (lastTranslationY > 72)
                surface.requestClose();
            }
            onActiveTranslationChanged: {
                if (active)
                lastTranslationY = activeTranslation.y;
            }
        }
    }

    // A fullscreen touch shell should also be dismissible from the bottom
    // edge. This mirrors GNOME's edge-first interaction model and is useful
    // on tablets where Escape and a physical keyboard are unavailable.
    Item {
        id: bottomEdgeGesture

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(36, surface.touchTarget)
        z: 200

        DragHandler {
            id: bottomEdgeDrag

            target: null
            enabled: surface.touchLayout
            yAxis.enabled: true
            xAxis.enabled: false
            dragThreshold: 8
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            property real lastTranslationY: 0

            onActiveChanged: {
                if (active)
                lastTranslationY = 0;
                else if (lastTranslationY < -72)
                surface.requestClose();
            }
            onActiveTranslationChanged: {
                if (active)
                lastTranslationY = activeTranslation.y;
            }
        }
    }

    Item {
        id: dragGhost

        visible: surface.tileDragging && surface.dragEntry !== null
        z: 100
        width: Math.max(72, Math.min(112, surface.cellWidth * 0.68))
        height: width + 30
        x: surface.mapFromItem(null, surface.dragPoint.x, surface.dragPoint.y).x - width / 2
        y: surface.mapFromItem(null, surface.dragPoint.x, surface.dragPoint.y).y - height / 2
        enabled: false
        opacity: 0.92
        scale: 1.04

        Rectangle {
            id: ghostIcon

            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: width
            radius: width * 0.225
            color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)

            ThemeIcon {
                anchors.fill: parent
                anchors.margins: 2
                visible: surface.dragEntry !== null && surface.dragEntry.kind !== "folder" &&
                         !surface.dragEntry.symbol
                iconSource: visible ? LaunchpadIconCache.sourceFor(ApplicationService.iconSource(
                                                                       surface.dragEntry.icon || "")) : ""
                sourceSize.width: Math.round(width)
                sourceSize.height: Math.round(width)
                asynchronous: false
                fillMode: Image.PreserveAspectFit
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: surface.dragEntry === null || surface.dragEntry.kind === "folder" || !
                         !surface.dragEntry.symbol
                text: surface.dragEntry && surface.dragEntry.kind === "folder" ? "folder" : surface.dragEntry ? (
                                                                                                                    surface.dragEntry.symbol
                                                                                                                    || "apps") :
                                                                                                                "apps"
                iconSize: width * 0.52
                color: "#ffffffff"
            }
        }

        Text {
            anchors.top: ghostIcon.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: surface.dragEntry ? String(surface.dragEntry.title || "") : ""
            color: "#ffffffff"
            style: Text.Outline
            styleColor: "#66000000"
            font.family: Fonts.ui
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    StyledMenu {
        id: tileMenu

        property bool tileIsFolder: {
            const item = LaunchpadService.items.find(candidate => candidate.id === surface.contextId);
            return !!item && item.type === "folder";
        }
        property bool tileIsApp: {
            const item = LaunchpadService.items.find(candidate => candidate.id === surface.contextId);
            if (item)
            return item.type === "app";
            return surface.folderEntries.some(entry => entry.id === surface.contextId);
        }
        onClosed: Qt.callLater(() => searchInput.forceActiveFocus())

        StyledMenuItem {
            iconName: "open_in_new"
            text: qsTr("Open")
            onTriggered: surface.activateId(surface.contextId)
        }
        StyledMenuItem {
            iconName: "dock_to_bottom"
            text: qsTr("Add to Dock")
            visible: tileMenu.tileIsApp && !surface.folderOpen
            onTriggered: DockService.pin(surface.contextId)
        }
        StyledMenuItem {
            iconName: "remove_circle"
            text: ApplicationService.canUninstall(LaunchpadService.applicationFor(surface.contextId)) ? qsTr(
                                                                                                            "Delete application") :
                                                                                                        qsTr("Remove from Launchpad")
            visible: tileMenu.tileIsApp && !surface.folderOpen
            onTriggered: surface.removeRequested(surface.contextId)
        }
        StyledMenuItem {
            iconName: "folder_off"
            text: qsTr("Remove from folder")
            visible: surface.folderOpen
            onTriggered: surface.removeRequested(surface.contextId)
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 90
        visible: removalDialog.visible
        color: Qt.rgba(0, 0, 0, 0.4)

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: removalDialog.close()
        }
    }

    MaterialDialog {
        id: removalDialog

        anchors.centerIn: Overlay.overlay
        width: Math.min(460, surface.width - 32)
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            radius: Appearance.rounding.extraLarge
            color: Appearance.m3colors.m3surfaceContainerHigh
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
        }
        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.4)
        }
        dialogTitle: surface.pendingRemovalCanUninstall ? qsTr("Delete “%1”?").arg(
                                                              surface.pendingRemovalApplication ? String(
                                                                                                      surface.pendingRemovalApplication.name
                                                                                                      || surface.pendingRemovalId) :
                                                                                                  "") : qsTr(
                                                              "Remove from Launchpad?")
        messageText: surface.removalError !== "" ? surface.removalError : surface.pendingRemovalCanUninstall
                                                   ? qsTr("This removes the application from your system. Its personal data is not deleted automatically.") :
                                                     qsTr("This application has no safe uninstall integration. It will be hidden from Launchpad but remain installed.")

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    id: cancelButton

                    text: qsTr("Cancel")
                    enabled: !surface.removalInProgress
                    onClicked: removalDialog.close()
                }

                ActionButton {
                    text: surface.pendingRemovalCanUninstall ? qsTr("Delete") : qsTr("Remove")
                    enabled: !surface.removalInProgress
                    onClicked: surface.confirmApplicationRemoval()
                }
            }
        }

        onClosed: {
            surface.pendingRemovalId = "";
            surface.pendingRemovalApplication = null;
            surface.removalError = "";
            surface.removalInProgress = false;
        }
    }

    StyledMenu {
        id: backgroundMenu

        onClosed: Qt.callLater(() => searchInput.forceActiveFocus())

        StyledMenuItem {
            iconName: LaunchpadService.editing ? "check" : "edit"
            text: LaunchpadService.editing ? qsTr("Done") : qsTr("Edit Launchpad")
            onTriggered: LaunchpadService.toggleEditing()
        }
        StyledMenuItem {
            iconName: "visibility"
            text: qsTr("Restore hidden apps")
            visible: LaunchpadService.hidden.length > 0
            onTriggered: LaunchpadService.restoreHidden()
        }
        StyledMenuItem {
            iconName: "restart_alt"
            text: qsTr("Reset Launchpad")
            onTriggered: LaunchpadService.reset()
        }
        StyledMenuItem {
            iconName: "close"
            text: qsTr("Close")
            onTriggered: surface.requestClose()
        }
    }

    DragHandler {
        id: pagerDrag

        target: null
        enabled: !surface.searchMode && !surface.folderOpen && !surface.tileDragging
        dragThreshold: 6
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                surface.pageDragging = true;
                surface.dragStartPage = surface.pagePosition;
                surface.dragLastX = centroid.scenePosition.x;
                surface.dragLastTime = Date.now();
                surface.dragVelocity = 0;
            } else {
                surface.finishPageDrag();
            }
        }
        onActiveTranslationChanged: {
            if (!active)
            return;
            const now = Date.now();
            const x = centroid.scenePosition.x;
            if (now > surface.dragLastTime)
            surface.dragVelocity = (x - surface.dragLastX) / (now - surface.dragLastTime);
            surface.dragLastX = x;
            surface.dragLastTime = now;

            let raw = surface.dragStartPage - activeTranslation.x / pageArea.width;
            if (raw < 0)
            raw *= 0.28;
            else if (raw > LaunchpadService.pageCount - 1)
            raw = LaunchpadService.pageCount - 1 + (raw - (LaunchpadService.pageCount - 1)) * 0.28;
            surface.pagePosition = raw;
        }
    }

    WheelHandler {
        id: wheel

        target: null
        enabled: !surface.searchMode && !surface.folderOpen
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property string lastDirection: ""
        onWheel: event => {
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 120 * 70;
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 70;
            const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;
            if (delta === 0)
            return;
            const direction = delta > 0 ? "back" : "forward";
            if (wheel.lastDirection !== "" && wheel.lastDirection !== direction) {
                surface.wheelAccumulator = 0;
                wheel.lastDirection = "";
                return;
            }
            wheel.lastDirection = direction;
            surface.wheelAccumulator += delta;
            if (Math.abs(surface.wheelAccumulator) >= 90) {
                surface.wheelAccumulator = 0;
                wheel.lastDirection = "";
                if (delta > 0)
                surface.goToPage(LaunchpadService.page - 1);
                else
                surface.goToPage(LaunchpadService.page + 1);
            }
        }
    }

    Timer {
        id: dropEdgeTimer

        interval: 650
        repeat: true
        running: surface.tileDragging && surface.dropEdge !== 0 && !surface.folderOpen
        onTriggered: {
            surface.goToPage(LaunchpadService.page + surface.dropEdge);
            surface.updateDrop(surface.dragPoint);
        }
    }

    NumberAnimation {
        id: openAnimation

        target: surface
        property: "openProgress"
        from: 0
        to: 1
        duration: Appearance.animation.expressiveDefaultSpatial.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
    }

    NumberAnimation {
        id: closeAnimation

        target: surface
        property: "openProgress"
        to: 0
        duration: Appearance.animation.expressiveFastEffects.duration
        easing.type: Easing.OutCubic
        onStopped: LaunchpadService.close()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            surface.handleEscape();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            surface.activateSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            surface.goToPage(LaunchpadService.page - 1);
            else
            surface.moveSelection(-1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            surface.goToPage(LaunchpadService.page + 1);
            else
            surface.moveSelection(1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            surface.moveSelection(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            surface.moveSelection(0, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            surface.goToPage(LaunchpadService.page - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            surface.goToPage(LaunchpadService.page + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            LaunchpadService.toggleEditing();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            if (LaunchpadService.editing && surface.selectedId !== "")
            surface.removeRequested(surface.selectedId);
            event.accepted = true;
        }
    }

    Behavior on pagePosition {
        enabled: !surface.pageDragging

        NumberAnimation {
            duration: surface.pageSnapDuration
            easing.type: Easing.OutCubic
        }
    }
}
