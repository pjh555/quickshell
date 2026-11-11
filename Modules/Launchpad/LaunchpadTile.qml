pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var entry
    required property real cellWidth
    required property real cellHeight
    property bool editing: false
    property bool searchMode: false
    property bool selected: false
    property bool dropTarget: false
    property bool allowDrag: true
    property int jiggleDelay: 0

    readonly property bool folder: root.entry && root.entry.kind === "folder"
    readonly property bool application: root.entry && root.entry.kind === "app"
    readonly property real iconSize: Math.max(44, Math.min(112, Math.min(root.cellWidth * 0.56,
                                                                         root.cellHeight * 0.58)))
    readonly property string label: root.entry ? String(root.entry.title || root.entry.name || "") : ""
    readonly property var folderApplications: root.folder ? (root.entry.applications || []) : []

    readonly property int previewColumns: root.folderApplications.length <= 4 ? 2 : 3
    readonly property real previewSize: (root.iconSize - root.iconSize * 0.22 - (root.previewColumns - 1)
                                         * root.iconSize * 0.05) / root.previewColumns

    signal activated(string id)
    signal editRequested
    signal removeRequested(string id)
    signal contextRequested(string id)
    signal dragStarted(string id, point scenePoint, var entry)
    signal dragMoved(point scenePoint)
    signal dragFinished(point scenePoint)

    property bool suppressTap: false

    width: root.cellWidth
    height: root.cellHeight
    scale: tap.pressed ? 0.9 : hover.hovered && !root.editing ? 1.04 : 1
    opacity: drag.active ? 0.3 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastSpatial.duration
            easing.type: Appearance.animation.expressiveFastSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }
    }

    Item {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (root.height - height) / 2)
        width: root.width
        height: iconFrame.height + labelItem.implicitHeight + 9

        Item {
            id: iconFrame

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.iconSize
            height: root.iconSize

            Rectangle {
                anchors.fill: parent
                radius: parent.width * 0.225
                // Apple Launchpad shows the application's own artwork
                // directly. Keep the frosted treatment for folders and for
                // entries that need a symbolic fallback.
                visible: root.folder || (root.application && (!!root.entry.symbol || appIcon.status
                                                              !== Image.Ready))
                color: root.folder ? Qt.rgba(1, 1, 1, 0.18) : Appearance.m3colors.m3primaryContainer
                border.width: root.folder ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.2)
            }

            ThemeIcon {
                id: appIcon

                anchors.fill: parent
                anchors.margins: 1
                visible: root.application && !root.entry.symbol
                iconSource: visible ? LaunchpadIconCache.sourceFor(ApplicationService.iconSource(
                                                                       root.entry.icon || "")) : ""
                sourceSize.width: Math.max(1, Math.round(root.iconSize))
                sourceSize.height: Math.max(1, Math.round(root.iconSize))
                asynchronous: false
                fillMode: Image.PreserveAspectFit
            }

            Rectangle {
                anchors.fill: parent
                visible: root.application && !!root.entry.symbol
                radius: parent.width * 0.225
                color: Appearance.m3colors.m3primaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.entry.symbol || "apps"
                    iconSize: root.iconSize * 0.56
                    color: Appearance.m3colors.m3onPrimaryContainer
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.application && !root.entry.symbol && appIcon.status !== Image.Ready
                text: "apps"
                iconSize: root.iconSize * 0.52
                color: Appearance.m3colors.m3onPrimaryContainer
            }

            Item {
                id: folderGrid

                anchors.fill: parent
                anchors.margins: root.iconSize * 0.11
                visible: root.folder

                Grid {
                    anchors.centerIn: parent
                    columns: root.previewColumns
                    spacing: root.iconSize * 0.05

                    Repeater {
                        model: Math.min(9, root.folderApplications.length)

                        delegate: Image {
                            required property int index

                            width: root.previewSize
                            height: width
                            source: LaunchpadIconCache.sourceFor(ApplicationService.iconSource(
                                                                     root.folderApplications[index] ? String(
                                                                                                          root.folderApplications[index].icon
                                                                                                          || "") : ""))
                            sourceSize.width: Math.max(1, Math.round(width))
                            sourceSize.height: Math.max(1, Math.round(width))
                            asynchronous: false
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                }
            }

            Rectangle {
                id: selectionRing

                anchors.fill: parent
                anchors.margins: -5
                radius: width * 0.225
                color: "transparent"
                border.width: root.selected ? 3 : root.dropTarget ? 2 : 0
                border.color: root.dropTarget ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.95)
                opacity: root.selected || root.dropTarget ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        Text {
            id: labelItem

            anchors.top: iconFrame.bottom
            anchors.topMargin: 9
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 8, root.iconSize + 42)
            text: root.label
            textFormat: Text.PlainText
            color: "#ffffffff"
            style: Text.Outline
            styleColor: "#66000000"
            font.family: Fonts.ui
            font.pixelSize: Math.max(11, Math.min(15, root.cellHeight * 0.1))
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Rectangle {
            id: removeButton

            visible: root.editing && !root.searchMode && root.application
            width: 40
            height: 40
            radius: 20
            x: iconFrame.x - 18
            y: iconFrame.y - 18
            color: "#f2f2f2"
            border.width: 1
            border.color: "#33000000"

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 20
                color: "#1b1b1b"
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.removeRequested(root.entry.id)
            }
        }
    }

    SequentialAnimation {
        id: jiggle

        running: root.editing && !root.searchMode && !drag.active && root.visible
        loops: Animation.Infinite
        onRunningChanged: {
            if (!running)
            content.rotation = 0;
        }

        PauseAnimation {
            duration: root.jiggleDelay
        }
        NumberAnimation {
            target: content
            property: "rotation"
            to: -1.3
            duration: 120
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: content
            property: "rotation"
            to: 1.3
            duration: 120
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: content
            property: "rotation"
            to: 0
            duration: 120
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 640 + root.jiggleDelay
        }
    }

    HoverHandler {
        id: hover
        enabled: !root.searchMode
    }

    TapHandler {
        id: tap

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.WithinBounds
        longPressThreshold: 0.55
        onTapped: (eventPoint, button) => {
            if (root.suppressTap) {
                root.suppressTap = false;
                return;
            }
            if (button === Qt.RightButton) {
                root.contextRequested(root.entry.id);
                return;
            }
            root.activated(root.entry.id);
        }
        onLongPressed: {
            root.suppressTap = true;
            root.editRequested();
        }
    }

    DragHandler {
        id: drag

        target: null
        enabled: root.allowDrag && !root.searchMode
        dragThreshold: 8
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        xAxis.enabled: true
        yAxis.enabled: true

        property point origin: Qt.point(0, 0)
        property point current: Qt.point(0, 0)

        onActiveChanged: {
            if (active) {
                root.suppressTap = false;
                origin = Qt.point(drag.centroid.scenePosition.x, drag.centroid.scenePosition.y);
                current = origin;
                root.editRequested();
                root.dragStarted(root.entry.id, origin, root.entry);
            } else {
                root.dragFinished(current);
            }
        }
        onActiveTranslationChanged: {
            if (!active)
            return;
            current = Qt.point(origin.x + activeTranslation.x, origin.y + activeTranslation.y);
            root.dragMoved(current);
        }
    }

    Accessible.role: root.folder ? Accessible.Button : Accessible.ListItem
    Accessible.name: root.label
    Accessible.description: root.folder ? qsTr("%1 applications").arg(root.folderApplications.length) : (root.entry
                                                                                                         && root.entry.application
                                                                                                         ? String(root.entry.application.genericName
                                                                                                                  || "") : "")
    Accessible.selected: root.selected
    Accessible.onPressAction: root.activated(root.entry.id)
}
