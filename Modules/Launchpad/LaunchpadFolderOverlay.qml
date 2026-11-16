pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Modules.Launchpad
import qs.Services
import qs.Widgets.common

FocusScope {
    id: root

    focus: true

    Component.onCompleted: Qt.callLater(() => root.forceActiveFocus())

    Timer {
        interval: 80
        running: true
        onTriggered: root.forceActiveFocus()
    }

    required property var folder
    required property var entries
    property bool editing: false
    property bool dragActive: false
    property string dropTargetId: ""
    property string selectedId: ""
    property int selectedIndex: -1

    signal activated(string id)
    signal editRequested
    signal removeRequested(string id)
    signal renameRequested(string name)
    signal dragStarted(string id, point scenePoint, var entry)
    signal dragMoved(point scenePoint)
    signal dragFinished(point scenePoint)
    signal closeRequested

    readonly property int columns: Math.max(3, Math.min(6, Math.floor(panel.width / 158)))
    onEntriesChanged: root.resetSelection()
    readonly property real cellWidth: panel.width / root.columns
    readonly property real cellHeight: Math.min(180, panel.height / 3)
    readonly property real touchTarget: Math.max(48, Math.min(64, Math.min(root.width, root.height) * 0.06))
    readonly property real panelInset: Math.max(16, root.touchTarget * 0.5)

    function containsScenePoint(scenePoint) {
        const point = panel.mapFromItem(null, scenePoint.x, scenePoint.y);
        return point.x >= -24 && point.y >= -24 && point.x <= panel.width + 24 && point.y <= panel.height
                + 24;
    }

    function indexAtScenePoint(scenePoint) {
        if (!gridFlick)
            return -1;
        const point = gridFlick.mapFromItem(null, scenePoint.x, scenePoint.y);
        if (point.x < 0 || point.y < 0 || point.x > gridFlick.width || point.y > gridFlick.height)
            return -1;
        const contentY = point.y + gridFlick.contentY;
        const column = Math.max(0, Math.min(root.columns - 1, Math.floor(point.x / root.cellWidth)));
        const row = Math.max(0, Math.floor(contentY / root.cellHeight));
        const index = row * root.columns + column;
        return index < root.entries.length ? index : root.entries.length;
    }

    function focusName() {
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    function resetSelection() {
        if (!root.entries || root.entries.length === 0) {
            root.selectedIndex = -1;
            root.selectedId = "";
            return;
        }
        root.selectAt(0);
    }

    function selectAt(index) {
        const count = root.entries ? root.entries.length : 0;
        if (count === 0) {
            root.selectedIndex = -1;
            root.selectedId = "";
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(Number(index) || 0, count - 1));
        root.selectedId = String(root.entries[root.selectedIndex].id);
    }

    function moveSelection(dx, dy) {
        const count = root.entries ? root.entries.length : 0;
        if (count === 0)
            return;
        const current = root.selectedIndex < 0 ? 0 : root.selectedIndex;
        const column = current % root.columns;
        let next = current;
        if (dx !== 0 && column + dx >= 0 && column + dx < root.columns)
            next = current + dx;
        else if (dy !== 0)
            next = current + dy * root.columns;
        root.selectAt(Math.max(0, Math.min(next, count - 1)));
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: root.closeRequested()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.max(280, Math.min(parent.width - root.panelInset * 2, 920, Math.max(320, parent.width
                                                                                        * 0.72)))
        height: Math.max(280, Math.min(parent.height - root.panelInset * 2, 620, Math.max(320, parent.height
                                                                                          * 0.68)))
        radius: 32
        color: BlurService.backgroundColor(Appearance.colors.colLayer1)
        border.width: 1
        border.color: BlurService.glassBorderColor(false)
        opacity: 0
        scale: 0.92

        GlassHighlight {
            anchors.fill: parent
            radius: parent.radius
            topStrength: 0.20
            bottomStrength: 0.045
        }

        TapHandler {
            onTapped: {}
        }

        SequentialAnimation {
            running: true
            NumberAnimation {
                target: panel
                property: "opacity"
                to: 1
                duration: Appearance.animation.expressiveFastEffects.duration
            }
            ParallelAnimation {
                NumberAnimation {
                    target: panel
                    property: "scale"
                    to: 1
                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                }
                NumberAnimation {
                    target: panel
                    property: "opacity"
                    to: 1
                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.topMargin: 22
            anchors.bottomMargin: 16
            spacing: 6

            Item {
                width: parent.width
                height: 54

                TextField {
                    id: nameField

                    anchors.centerIn: parent
                    width: Math.min(parent.width - 140, Math.max(180, contentWidth + 48))
                    text: root.folder ? String(root.folder.name || "") : ""
                    placeholderText: qsTr("Folder")
                    horizontalAlignment: Text.AlignHCenter
                    color: "#ffffffff"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)
                    selectionColor: Appearance.m3colors.m3primary
                    selectedTextColor: Appearance.m3colors.m3onPrimary
                    font.family: Fonts.ui
                    font.pixelSize: Math.max(19, Math.min(30, root.width * 0.018))
                    font.weight: Font.DemiBold
                    selectByMouse: true
                    background: Rectangle {
                        radius: 10
                        color: nameField.activeFocus ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        border.width: nameField.activeFocus ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.28)
                    }
                    onEditingFinished: {
                        if (text.trim() !== "" && text !== root.folder.name)
                        root.renameRequested(text.trim());
                        root.forceActiveFocus();
                    }
                    onAccepted: focus = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            text = root.folder ? String(root.folder.name || "") : "";
                            focus = false;
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 68
                    height: 44
                    radius: 22
                    color: doneMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Done")
                        color: "#ffffffff"
                        font.family: Fonts.ui
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: doneMouse
                        anchors.fill: parent
                        onClicked: root.closeRequested()
                    }
                }
            }

            Flickable {
                id: gridFlick

                width: parent.width
                height: parent.height - 60
                contentWidth: width
                contentHeight: folderGrid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: !root.dragActive

                Grid {
                    id: folderGrid

                    width: gridFlick.width
                    columns: root.columns
                    spacing: 0

                    Repeater {
                        model: root.entries || []

                        delegate: LaunchpadTile {
                            required property int index
                            required property var modelData

                            width: root.cellWidth
                            height: root.cellHeight
                            cellWidth: root.cellWidth
                            cellHeight: root.cellHeight
                            entry: modelData
                            editing: root.editing
                            allowDrag: root.editing
                            selected: root.selectedId !== "" && modelData && modelData.id === root.selectedId
                            dropTarget: root.dropTargetId !== "" && modelData && modelData.id
                                        === root.dropTargetId

                            jiggleDelay: (index % 3) * 70

                            onActivated: id => root.activated(id)
                            onEditRequested: root.editRequested()
                            onRemoveRequested: id => root.removeRequested(id)
                            onContextRequested: id => root.removeRequested(id)
                            onDragStarted: (id, point, entry) => root.dragStarted(id, point, entry)
                            onDragMoved: point => root.dragMoved(point)
                            onDragFinished: point => root.dragFinished(point)
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedId !== "")
            root.activated(root.selectedId);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.moveSelection(-1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.moveSelection(1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(0, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            root.editRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            if (root.selectedId !== "")
            root.removeRequested(root.selectedId);
            event.accepted = true;
        }
    }
}
