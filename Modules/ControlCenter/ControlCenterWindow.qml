import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common
import "../../Common/functions/SettingsIconPalette.js" as IconPalette

FloatingWindow {
    id: root

    property bool _wasShown: false
    property real contentPadding: 10
    property int currentPage: 0
    property bool navExpanded: width >= 880
    property string pendingPageSection: ""
    readonly property var pageOrder: ["account", "general", "wallpaper", "theme", "keystone", "agent",
        "android", "advanced"]
    readonly property var hierarchicalPageSources: ({
                                                        "account": "AccountSettingsPage.qml",
                                                        "wallpaper": "WallpaperSettingsPage.qml",
                                                        "theme": "ThemeSettingsPage.qml",
                                                        "keystone": "KeystoneSettingsPage.qml",
                                                        "agent": "AgentSettingsPage.qml",
                                                        "android": "AndroidSettingsPage.qml",
                                                        "advanced": "AdvancedSettingsPage.qml"
                                                    })
    readonly property var pages: root.pageOrder.map(pageId => SpotlightCatalog.route(pageId)).filter(entry => entry
                                                                                                     !== null).map(
                                     entry => Object.assign({}, entry, {
                                                                title: SpotlightCatalog.title(entry.id)
                                                            }))
    property int searchRequestSerial: -1
    property var searchLeaf: null
    readonly property var searchPageAnchor: pageSearchAnchor
    function toggleMaximize() {
        root.maximized = !root.maximized;
    }

    function minimizeWindow() {
        const window = Niri.searchWindows(root.title).find(entry => entry.title === root.title);
        if (window && Niri.supportsMinimize && Niri.minimizeWindow(window.id))
            return;
        root.minimized = true;
    }

    function prepareSearchTarget(entry, serial) {
        searchRequestSerial = serial;
        root.openPage(entry.path[0]);
        root.advanceSearchTarget(entry, serial);
    }

    function advanceSearchTarget(entry, serial) {
        if (searchRequestSerial !== serial)
            return "cancelled";
        if (pages[currentPage].id !== entry.path[0])
            return "cancelled";
        if (!pageLoader.ready || !pageLoader.item)
            return "loading";
        const page = pageLoader.item;
        const state = typeof page.openSearchPath === "function" ? page.openSearchPath(entry.path.slice(1),
                                                                                      serial) : "ready";
        searchLeaf = page.searchLeaf || page;
        return state;
    }

    SettingsSearchAnchor {
        id: pageSearchAnchor
        registerAnchor: false
        declaration: JSON.stringify({
                                        id: "page"
                                    })
        target: root.searchLeaf
        wholePage: true
    }

    signal popoutClosed

    function showWindow() {
        root._wasShown = true;
        root.visible = true;
        root.minimized = false;
    }

    function hideWindow() {
        if (root.visible) {
            settingsSearch.close();
            root.closeChildWindows();
            root.visible = false;
        }
    }

    function toggleWindow() {
        if (root.visible)
            root.hideWindow();
        else
            root.showWindow();
    }

    function pageSource(index) {
        if (index < 0 || index >= pages.length)
            return Qt.resolvedUrl("AccountPage.qml");

        const page = pages[index];
        return Qt.resolvedUrl(root.hierarchicalPageSources[page.id] || page.source);
    }

    function openPage(pageId) {
        if (pageId === "language-region")
            return root.openPageSection("general", "language-region");

        for (let index = 0; index < pages.length; ++index) {
            if (pages[index].id === pageId) {
                currentPage = index;
                return true;
            }
        }
        return false;
    }

    function openPageSection(pageId, section) {
        root.pendingPageSection = section;
        if (!root.openPage(pageId)) {
            root.pendingPageSection = "";
            return false;
        }
        root.applyPendingPageSection();
        return true;
    }

    function applyPendingPageSection() {
        if (!root.pendingPageSection || !pageLoader.item)
            return;

        if (root.pages[root.currentPage].id !== "general" || typeof pageLoader.item.openSection
                !== "function")

            return;

        const section = root.pendingPageSection;
        root.pendingPageSection = "";
        pageLoader.item.openSection(section);
    }

    function closeChildWindows() {
        const page = pageLoader.item;
        if (page && typeof page.closeChildWindows === "function")
            page.closeChildWindows();
    }

    function openConfig() {
        ApplicationService.openUrl(Paths.fileUrl(PersonalizationConfig.filePath));
    }

    function copyConfigPath() {
        Quickshell.clipboardText = PersonalizationConfig.filePath;
        copiedTimer.restart();
    }

    visible: false
    title: "clavis-control-center"
    implicitWidth: 1100
    implicitHeight: 750
    minimumSize: Qt.size(760, 520)
    color: "transparent"
    Material.theme: PersonalizationConfig.themeMode === "light" ? Material.Light : Material.Dark
    Material.accent: Appearance.colors.colPrimary
    onVisibleChanged: {
        if (!root.visible && root._wasShown) {
            ControlCenterService.cancelSearch();
            root.closeChildWindows();
            root._wasShown = false;
            root.popoutClosed();
        }
    }
    onCurrentPageChanged: {
        if (ControlCenterService.searchTarget && !ControlCenterService.applyingSearch && searchRequestSerial
                === ControlCenterService.searchSerial)
            ControlCenterService.cancelSearch();
        root.closeChildWindows();
        ControlCenterService.retrySearch();
    }

    Timer {
        id: copiedTimer

        interval: 1400
    }

    Item {
        id: focusBoundary
        anchors.fill: parent

        LiquidGlassSurface {
            id: outerGlass

            anchors.fill: parent
            radius: root.maximized ? 0 : Appearance.rounding.extraLarge
            baseColor: Appearance.colors.colLayer0Base
            blurOpacity: 0.68
            fallbackOpacity: 0.96
            topHighlight: 0.18
            bottomReflection: 0.045
            clearMaterial: false
        }

        Shortcut {
            sequence: "Ctrl+F"
            enabled: root.visible && focusBoundary.Window.active
            onActivated: settingsSearch.open()
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.visible && settingsSearch.expanded
            onActivated: settingsSearch.close()
        }

        function releaseInputFocus(position) {
            const input = focusBoundary.Window.activeFocusItem;
            if (!(input instanceof TextInput) && !(input instanceof TextEdit))
                return;
            if (input.contains(input.mapFromItem(focusBoundary, position)))
                return;
            // Clear the field's local focus as well as the window's active focus:
            // otherwise a nested FocusScope can restore the field immediately.
            input.focus = false;
            focusBoundary.forceActiveFocus(Qt.MouseFocusReason);
        }

        MouseArea {
            anchors.fill: parent
            z: 1000
            acceptedButtons: Qt.AllButtons
            // Inspect presses before page controls handle them, then let the
            // original press through for text selection, buttons and dragging.
            onPressed: mouse => {
                           focusBoundary.releaseInputFocus(Qt.point(mouse.x, mouse.y));
                           mouse.accepted = false;
                       }
            onWheel: wheel => wheel.accepted = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: root.contentPadding

            Item {
                id: titlebar

                Layout.fillWidth: true
                Layout.preferredHeight: 30

                SettingsWindowControls {
                    id: windowControls

                    x: PersonalizationConfig.settingsWindowControlsSide === "right" ? parent.width - width : 0
                    anchors.top: parent.top
                    maximized: root.maximized
                    onCloseRequested: root.hideWindow()
                    onMinimizeRequested: root.minimizeWindow()
                    onMaximizeRequested: root.toggleMaximize()
                }

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: {
                        if (active)
                            root.startSystemMove();
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onDoubleTapped: root.toggleMaximize()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.contentPadding

                LiquidGlassSurface {
                    id: navRailWrapper

                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth
                    implicitWidth: root.navExpanded ? 248 : 72
                    radius: Metrics.cornerL
                    baseColor: Appearance.colors.colLayer1Base
                    blurOpacity: 0.72
                    fallbackOpacity: 0.97
                    topHighlight: 0.18
                    clearMaterial: false
                    clipContent: true

                    ColumnLayout {
                        id: navRail

                        anchors.fill: parent
                        anchors.margins: Metrics.spacingS
                        spacing: Metrics.spacingS

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.controlHeightL

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Metrics.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.navExpanded
                                text: qsTranslate("ControlCenterWindow", "Settings")
                                color: Appearance.colors.colOnSurface
                                font.family: Typography.titleLarge.family
                                font.pixelSize: Typography.titleLarge.pixelSize
                                font.weight: Font.DemiBold
                            }

                            NavigationRailExpandButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                expanded: root.navExpanded
                                onClicked: root.navExpanded = !root.navExpanded
                            }
                        }

                        Item {
                            id: searchBarSlot

                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: navigationTabs.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            NavigationRailTabArray {
                                id: navigationTabs

                                width: parent.width
                                currentIndex: root.currentPage
                                expanded: root.navExpanded

                                Repeater {
                                    model: root.pages

                                    NavigationRailButton {
                                        required property int index
                                        required property var modelData

                                        active: root.currentPage === index
                                        expanded: root.navExpanded
                                        buttonIcon: modelData.icon
                                        buttonText: modelData.title
                                        showToggledHighlight: false
                                        Layout.topMargin: ["wallpaper", "agent", "advanced"].indexOf(
                                            modelData.id) >= 0 ? Metrics.spacingS : 0
                                        onPressed: root.currentPage = index
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.dividerWidth
                            Layout.leftMargin: Metrics.spacingS
                            Layout.rightMargin: Metrics.spacingS
                            color: Appearance.colors.colLayer0Border
                        }

                        FloatingActionButton {
                            id: configButton

                            property bool justCopied: copiedTimer.running

                            Layout.fillWidth: true
                            iconText: justCopied ? "check" : "edit"
                            buttonText: justCopied ? qsTr("Path copied") : qsTr("config file")
                            expanded: root.navExpanded
                            baseSize: Metrics.controlHeightL
                            baseColor: "transparent"
                            hoverStateColor: Appearance.colors.colLayer1Hover
                            pressedStateColor: Appearance.colors.colLayer1Active
                            contentColor: Appearance.colors.colOnSurfaceVariant
                            onClicked: root.openConfig()
                            onAltClicked: root.copyConfigPath()
                        }
                    }

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                Rectangle {
                    id: bodyBackground

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Metrics.cornerL
                    color: Appearance.macos.background
                    border.width: 1
                    border.color: Appearance.macos.separator
                    clip: true

                    Item {
                        id: currentPageHeader

                        readonly property var page: root.pages[root.currentPage]

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: visible ? 54 : 0
                        visible: (!pageLoader.item || !("currentSection" in pageLoader.item)
                                  || pageLoader.item.currentSection === "overview") && (!pageLoader.item || !(
                                                                                            "detailOpen" in pageLoader.item)
                                                                                        || !pageLoader.item.detailOpen)
                        z: 2

                        LiquidGlassSurface {
                            anchors.fill: parent
                            radius: 0
                            baseColor: Appearance.macos.surfaceElevated
                            blurOpacity: 0.72
                            fallbackOpacity: 0.97
                            topHighlight: 0.13
                            bottomReflection: 0.025
                            elevated: false
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 8
                            color: currentPageHeader.page ? IconPalette.backgroundFor(
                                                                currentPageHeader.page.icon) : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: currentPageHeader.page ? currentPageHeader.page.icon : "settings"
                                iconSize: 20
                                fill: 1
                                color: "white"
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacingL + 42
                            anchors.right: parent.right
                            anchors.rightMargin: Metrics.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                            text: currentPageHeader.page ? currentPageHeader.page.title : ""
                            color: Appearance.colors.colOnSurface
                            font.family: Typography.titleLarge.family
                            font.pixelSize: Typography.titleLarge.pixelSize
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.36)
                        }
                    }

                    InlineStatusBanner {
                        z: 200
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Metrics.spacingM
                        visible: ControlCenterService.searchError !== ""
                        tone: "error"
                        message: ControlCenterService.searchError
                    }

                    SettingsPageHost {
                        id: pageLoader

                        property var parentModal: root

                        anchors.fill: parent
                        anchors.topMargin: currentPageHeader.height
                        source: root.pageSource(root.currentPage)
                        presentationActive: root.visible
                        asynchronous: false
                        onLoaded: {
                            if (item && "parentModal" in item)
                                item.parentModal = parentModal;

                            const page = item;
                            if (page && "presentationActive" in page)
                                page.presentationActive = Qt.binding(function () {
                                    return root.visible && pageLoader.item === page;
                                });

                            root.applyPendingPageSection();
                            ControlCenterService.retrySearch();
                        }
                    }

                    Connections {
                        function onNavigateRequested(pageId) {
                            if (pageId === "connected-devices" || pageId === "network" || pageId
                                    === "shortcuts") {
                                root.openPageSection("general", pageId);
                                return;
                            }
                            root.openPage(pageId);
                        }

                        target: pageLoader.item
                        ignoreUnknownSignals: true
                    }
                }
            }
        }

        SettingsSearch {
            id: settingsSearch
            anchors.fill: parent
            z: 500
            barSlot: searchBarSlot
            sideMargin: root.navExpanded ? 288 : 112
            onCollapsed: focusBoundary.forceActiveFocus(Qt.OtherFocusReason)
        }

        CompositorBlurRegion {
            targetWindow: root
            backgroundItem: outerGlass
            radius: root.maximized ? 0 : Appearance.rounding.extraLarge
        }
    }
}
