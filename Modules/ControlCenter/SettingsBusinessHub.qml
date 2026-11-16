pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

// Two-pane settings layout: the window sidebar selects a business, then this
// page presents its grouped settings and a focused detail page.
Item {
    id: root

    property var groups: []
    property var parentModal: null
    property bool presentationActive: false
    property var currentEntry: null
    property bool detailOpen: false
    property string pendingRevealId: ""
    readonly property var searchLeaf: detailOpen && detailPageLoader.item ? (detailPageLoader.item.searchLeaf
                                                                             || detailPageLoader.item) :
                                                                            overviewFlickable

    signal navigateRequested(string pageId)
    signal pairingRequested
    signal deviceRequested(string address, string adapterId)
    signal returnRequested

    function allEntries() {
        const entries = [];
        for (const group of root.groups || []) {
            for (const entry of group.entries || [])
                entries.push(entry);
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

    function openEntry(entry, revealTarget) {
        if (!entry || entry.available === false)
            return;
        if (entry.pageId) {
            root.navigateRequested(entry.pageId);
            return;
        }
        root.currentEntry = entry;
        root.pendingRevealId = revealTarget ? String(entry.targetId || "") : "";
        root.detailOpen = true;
        root.applyCurrentEntry();
        root.revealPendingTarget();
    }

    function revealPendingTarget() {
        if (!root.pendingRevealId || detailPageLoader.status !== Loader.Ready)
            return;
        const targetId = root.pendingRevealId;
        root.pendingRevealId = "";
        Qt.callLater(() => ControlCenterService.openSearch(targetId));
    }

    function closeDetail() {
        ControlCenterService.cancelSearch();
        root.pendingRevealId = "";
        root.detailOpen = false;
        root.currentEntry = null;
    }

    function closeChildWindows() {
        const page = detailPageLoader.item;
        if (page && typeof page.closeChildWindows === "function")
            page.closeChildWindows();
    }

    function openSearchPath(path, serial) {
        const target = ControlCenterService.searchTarget;
        if (target) {
            const entry = root.entryForTarget(target.id);
            if (entry) {
                root.currentEntry = entry;
                root.pendingRevealId = "";
                root.detailOpen = true;
            }
        }
        if (!root.detailOpen || detailPageLoader.status !== Loader.Ready || !detailPageLoader.item)
            return "loading";
        const childPath = root.currentEntry && root.currentEntry.pathSegment && path.length && path[0]
              === root.currentEntry.pathSegment ? path.slice(1) : path;
        return typeof detailPageLoader.item.openSearchPath === "function"
                ? detailPageLoader.item.openSearchPath(childPath, serial) : "ready";
    }

    onCurrentEntryChanged: Qt.callLater(applyCurrentEntry)

    Rectangle {
        anchors.fill: parent
        color: Appearance.macos.background
    }

    Item {
        id: overviewLayer

        anchors.fill: parent
        enabled: !root.detailOpen
        opacity: root.detailOpen ? 0 : 1
        x: root.detailOpen ? -Metrics.spacingL : 0

        StyledFlickable {
            id: overviewFlickable

            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: overviewColumn.implicitHeight + Metrics.settingsPageMargin * 2

            ColumnLayout {
                id: overviewColumn

                width: Math.min(760, Math.max(0, overviewFlickable.width - Metrics.settingsPageMargin * 2))
                x: Math.max(Metrics.settingsPageMargin, (overviewFlickable.width - width) / 2)
                y: Metrics.settingsPageMargin
                spacing: Metrics.settingsGroupSpacing

                Repeater {
                    model: root.groups

                    delegate: SettingsSection {
                        id: groupSection

                        required property var modelData

                        Layout.fillWidth: true
                        title: modelData.title || ""
                        iconName: modelData.icon || ""
                        compact: true

                        Repeater {
                            model: groupSection.modelData.entries || []

                            delegate: SettingsActionRow {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                visible: modelData.available !== false
                                iconName: modelData.icon || "settings"
                                text: modelData.title || ""
                                valueText: modelData.value || ""
                                description: modelData.description || ""
                                showDivider: index < (groupSection.modelData.entries || []).length - 1
                                onClicked: root.openEntry(modelData, false)
                            }
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
    }

    Item {
        id: detailLayer

        anchors.fill: parent
        enabled: root.detailOpen
        visible: root.detailOpen || opacity > 0
        opacity: root.detailOpen ? 1 : 0
        x: root.detailOpen ? 0 : Metrics.spacingL

        LiquidGlassSurface {
            id: detailHeaderSurface

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 52
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
                onBackRequested: root.closeDetail()
            }
        }

        Loader {
            id: detailPageLoader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: detailHeaderSurface.bottom
            anchors.bottom: parent.bottom
            active: root.detailOpen && root.currentEntry && !!root.currentEntry.source
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
                page.presentationActive = Qt.binding(() => root.presentationActive && root.detailOpen
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

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
    }
}
