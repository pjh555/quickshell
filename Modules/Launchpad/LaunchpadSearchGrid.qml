pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Launchpad
import qs.Widgets.common

GridView {
    id: root

    required property var results
    required property real tileWidth
    required property real tileHeight
    required property int selectedIndex
    property bool editing: false

    signal activationRequested(int index)
    signal selectionRequested(int index)
    signal contextRequested(int index)

    model: root.results || []
    cellWidth: root.tileWidth
    cellHeight: root.tileHeight
    currentIndex: root.selectedIndex
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    interactive: true
    highlight: Item {}
    highlightMoveDuration: 120

    ScrollBar.vertical: StyledScrollBar {}

    delegate: LaunchpadTile {
        required property int index
        required property var modelData

        width: root.tileWidth
        height: root.tileHeight
        cellWidth: root.tileWidth
        cellHeight: root.tileHeight
        entry: ({
                    kind: "app",
                    id: String(modelData.id || ""),
                    title: String(modelData.title || ""),
                    icon: String(modelData.icon || ""),
                    symbol: String(modelData.symbol || ""),
                    application: modelData.appObject || null
                })
        editing: root.editing
        searchMode: true
        allowDrag: false
        selected: index === root.selectedIndex

        onActivated: root.activationRequested(index)
        onContextRequested: root.contextRequested(index)
    }
}
