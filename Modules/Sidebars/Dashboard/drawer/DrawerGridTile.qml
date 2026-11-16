import QtQuick
import qs.Common
import qs.Services
import qs.Modules.SystemCards

Item {
    id: root

    required property string tileId
    property bool active: true
    property bool dragging: false
    property bool motionEnabled: true
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool presentationOwned: SystemCardDragSession.presentationActive
                                              && SystemCardDragSession.tileId === root.tileId
    readonly property Item contentItem: cardContent

    signal dragStarted(string tileId, Item sourceItem, real grabLocalX, real grabLocalY, real pointerLocalX,
                       real pointerLocalY)
    signal dragMoved(string tileId, real pointerLocalX, real pointerLocalY)
    signal dragFinished(string tileId)
    signal dragCanceled(string tileId)

    Accessible.role: Accessible.Pane
    transformOrigin: Item.Center
    scale: root.dragging ? 0.985 : root.hovered ? 1.012 : 1

    Behavior on scale {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: Appearance.animation.expressiveFastSpatial.duration
            easing.type: Appearance.animation.expressiveFastSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
        }
    }

    Behavior on x {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on y {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on width {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Behavior on height {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    // The card content owns the adaptive iPadOS widget surface. Shell glass is
    // reserved for navigation and edit controls outside the widget body.
    SystemCardContent {
        id: cardContent

        anchors.fill: parent
        tileId: root.tileId
        // Once extraction starts the presentation-host proxy becomes the
        // only active sidebar-side renderer. Keep this delegate allocated so
        // Grid state remains stable, but do not run a second Card content.
        active: root.active && !root.presentationOwned
        visible: !root.presentationOwned
        useShellManagedSurface: true
        interactionProgress: root.hovered || root.dragging ? 1 : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.veryLarge
        color: root.dragging ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.10) : root.hovered
                               ? Appearance.applyAlpha(Appearance.colors.colPrimary, 0.045) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
            }
        }
    }

    HoverHandler {
        id: hoverHandler

        cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: root.active
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

        property bool started: false

        onActiveChanged: {
            if (active) {
                started = true;
                root.dragStarted(root.tileId, root, centroid.pressPosition.x, centroid.pressPosition.y,
                                 centroid.position.x, centroid.position.y);
            } else if (started) {
                started = false;
                root.dragFinished(root.tileId);
            }
        }

        onCentroidChanged: {
            if (!active)
                return;
            root.dragMoved(root.tileId, centroid.position.x, centroid.position.y);
        }

        onCanceled: {
            started = false;
            root.dragCanceled(root.tileId);
        }
    }
}
