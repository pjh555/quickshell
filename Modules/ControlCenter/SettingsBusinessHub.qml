pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// Three-level iPadOS settings navigation: the window sidebar is level one,
// this persistent list is level two, and the loaded page is level three.
Item {
    id: root

    property var groups: []
    property var parentModal: null
    property bool presentationActive: false
    property var currentEntry: null
    property string pendingRevealId: ""
    readonly property bool compactNavigation: width < 720
    readonly property bool detailOpen: currentEntry !== null
    readonly property var searchLeaf: detailPageLoader.item ? (detailPageLoader.item.searchLeaf
                                                               || detailPageLoader.item) : categoryFlickable

    signal navigateRequested(string pageId)
    signal pairingRequested
    signal deviceRequested(string address, string adapterId)
    signal returnRequested

    function allEntries() {
        const entries = [];
        for (const group of root.groups || []) {
            for (const entry of group.entries || []) {
                if (entry.available !== false)
                    entries.push(entry);
            }
        }
        return entries;
    }

    function entryForTarget(targetId) {
        const wanted = String(targetId || "");
        for (const entry of root.allEntries()) {
            if (entry.targetId === wanted || (entry.targetIds || []).indexOf(wanted) >= 0)
                return entry;
            for (const prefix of entry.targetPrefixes || []) {
                if (wanted.startsWith(prefix))
                    return entry;
            }
        }
        return root.allEntries()[0] || null;
    }

    function ensureSelection() {
        if (!root.currentEntry)
            root.currentEntry = root.allEntries()[0] || null;
    }

    function openEntry(entry, revealTarget) {
        if (!entry || entry.available === false)
            return;
        if (entry.pageId) {
            root.navigateRequested(entry.pageId);
            return;
        }
        root.currentEntry = entry;
        root.pendingRevealId = revealTarget ? String(entry.targetId || "") : "";
        root.revealPendingTarget();
    }

    function revealPendingTarget() {
        if (!root.pendingRevealId || detailPageLoader.status !== Loader.Ready)
            return;
        const targetId = root.pendingRevealId;
        root.pendingRevealId = "";
        Qt.callLater(() => ControlCenterService.openSearch(targetId));
    }

    function applyCurrentEntry() {
        const page = detailPageLoader.item;
        if (!page || !root.currentEntry)
            return;
        if ("sectionFilter" in page)
            page.sectionFilter = String(root.currentEntry.sectionId || "");
        const initialProperties = root.currentEntry.initialProperties || ({});
        for (const propertyName of Object.keys(initialProperties)) {
            if (propertyName in page)
                page[propertyName] = initialProperties[propertyName];
        }
    }

    function closeDetail() {
        if (!root.compactNavigation)
            return;
        ControlCenterService.cancelSearch();
        root.pendingRevealId = "";
        root.currentEntry = null;
    }

    function closeChildWindows() {
        const page = detailPageLoader.item;
        if (page && typeof page.closeChildWindows === "function")
            page.closeChildWindows();
    }

    function openSearchPath(path, serial) {
        const target = ControlCenterService.searchTarget;
        if (target)
            root.currentEntry = root.entryForTarget(target.id);
        if (detailPageLoader.status !== Loader.Ready || !detailPageLoader.item)
            return "loading";
        const childPath = root.currentEntry && root.currentEntry.pathSegment && path.length && path[0]
              === root.currentEntry.pathSegment ? path.slice(1) : path;
        return typeof detailPageLoader.item.openSearchPath === "function"
                ? detailPageLoader.item.openSearchPath(childPath, serial) : "ready";
    }

    Component.onCompleted: ensureSelection()
    onGroupsChanged: ensureSelection()
    onCurrentEntryChanged: Qt.callLater(applyCurrentEntry)

    Rectangle {
        anchors.fill: parent
        color: Appearance.macos.background
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        LiquidGlassSurface {
            id: categoryPane

            Layout.fillHeight: true
            Layout.preferredWidth: root.compactNavigation ? root.width : 276
            visible: !root.compactNavigation || !root.detailOpen
            radius: 0
            baseColor: Appearance.macos.surfaceElevated
            blurOpacity: 0.72
            fallbackOpacity: 0.97
            topHighlight: 0.12
            bottomReflection: 0.025
            elevated: false
            clipContent: true

            StyledFlickable {
                id: categoryFlickable

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: categoryColumn.implicitHeight + Metrics.spacingL * 2

                ColumnLayout {
                    id: categoryColumn

                    width: categoryFlickable.width
                    y: Metrics.spacingM
                    spacing: Metrics.spacingL

                    Repeater {
                        model: root.groups

                        delegate: ColumnLayout {
                            id: groupColumn

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.leftMargin: Metrics.spacingS
                            Layout.rightMargin: Metrics.spacingS
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: Metrics.spacingM
                                Layout.rightMargin: Metrics.spacingM
                                text: groupColumn.modelData.title || ""
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Typography.labelMedium.family
                                font.pixelSize: Typography.labelMedium.pixelSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: groupColumn.modelData.entries || []

                                delegate: SettingsActionRow {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    visible: modelData.available !== false
                                    iconName: modelData.icon || "settings"
                                    text: modelData.title || ""
                                    valueText: modelData.value || ""
                                    showDivider: false
                                    highlighted: root.currentEntry === modelData
                                    onClicked: root.openEntry(modelData, false)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            visible: categoryPane.visible
            color: Appearance.macos.separator
        }

        Item {
            id: detailPane

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.compactNavigation || root.detailOpen

            LiquidGlassSurface {
                id: detailHeaderSurface

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 54
                radius: 0
                baseColor: Appearance.macos.surfaceElevated
                blurOpacity: 0.72
                fallbackOpacity: 0.97
                topHighlight: 0.13
                bottomReflection: 0.025
                elevated: false

                GeneralSubpageHeader {
                    anchors.fill: parent
                    title: root.currentEntry ? root.currentEntry.title || "" : ""
                    iconName: root.currentEntry ? root.currentEntry.icon || "settings" : "settings"
                    backAccessibleName: qsTr("Back to settings categories")
                    visible: root.compactNavigation
                    onBackRequested: root.closeDetail()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingL
                    anchors.rightMargin: Metrics.spacingL
                    visible: !root.compactNavigation
                    spacing: Metrics.spacingS

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: Appearance.colors.colSecondaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.currentEntry ? root.currentEntry.icon || "settings" : "settings"
                            iconSize: 20
                            fill: 1
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentEntry ? root.currentEntry.title || "" : ""
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleLarge.family
                        font.pixelSize: Typography.titleLarge.pixelSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }

            Loader {
                id: detailPageLoader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: detailHeaderSurface.bottom
                anchors.bottom: parent.bottom
                active: root.currentEntry !== null && !!root.currentEntry.source
                asynchronous: true
                source: active ? Qt.resolvedUrl(root.currentEntry.source) : ""
                onLoaded: {
                    if (!item)
                    return;
                    if ("parentModal" in item)
                    item.parentModal = root.parentModal;
                    const page = item;
                    root.applyCurrentEntry();
                    if ("presentationActive" in page)
                    page.presentationActive = Qt.binding(() => root.presentationActive
                                                         && detailPageLoader.item === page);
                    root.revealPendingTarget();
                    ControlCenterService.retrySearch();
                }
            }

            InlineBusyIndicator {
                anchors.centerIn: parent
                visible: detailPageLoader.status === Loader.Loading
                busy: visible
            }

            Connections {
                target: detailPageLoader.item
                ignoreUnknownSignals: true

                function onNavigateRequested(pageId) {
                    root.navigateRequested(pageId);
                }

                function onPairingRequested() {
                    root.pairingRequested();
                }

                function onDeviceRequested(address, adapterId) {
                    root.deviceRequested(address, adapterId);
                }

                function onReturnRequested() {
                    root.returnRequested();
                }
            }
        }
    }
}
