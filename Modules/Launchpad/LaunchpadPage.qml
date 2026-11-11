pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.Launchpad

Item {
    id: root

    required property var entries
    required property int columns
    required property int rows
    required property real cellWidth
    required property real cellHeight
    property bool editing: false
    property bool searchMode: false
    property string selectedId: ""
    property string dropTargetId: ""

    signal activated(string id)
    signal editRequested
    signal removeRequested(string id)
    signal contextRequested(string id)
    signal dragStarted(string id, point scenePoint, var entry)
    signal dragMoved(point scenePoint)
    signal dragFinished(point scenePoint)

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
            searchMode: root.searchMode
            allowDrag: root.editing
            selected: root.selectedId !== "" && modelData && modelData.id === root.selectedId
            dropTarget: root.dropTargetId !== "" && modelData && modelData.id === root.dropTargetId
            jiggleDelay: (index % 3) * 70
            x: (index % root.columns) * root.cellWidth
            y: Math.floor(index / root.columns) * root.cellHeight

            onActivated: id => root.activated(id)
            onEditRequested: root.editRequested()
            onRemoveRequested: id => root.removeRequested(id)
            onContextRequested: id => root.contextRequested(id)
            onDragStarted: (id, point, entry) => root.dragStarted(id, point, entry)
            onDragMoved: point => root.dragMoved(point)
            onDragFinished: point => root.dragFinished(point)
        }
    }
}
