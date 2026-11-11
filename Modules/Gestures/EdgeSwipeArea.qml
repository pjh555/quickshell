import QtQuick

Item {
    id: root

    property bool horizontal: true
    property int direction: 1
    property string screenName: ""
    property string shortAction: ""
    property string longAction: ""
    property real shortDistance: 40
    property real longDistance: 170
    property real velocityThreshold: 0.35

    readonly property bool active: drag.active
    readonly property bool longReached: root.distance >= root.longDistance || root.distance
                                        >= root.longDistance * 0.55 && root.velocity > 0.9
    property real progress: 0
    property real distance: 0
    property real velocity: 0

    signal triggered(string action, string screenName)

    function reset() {
        root.progress = 0;
        root.distance = 0;
        root.velocity = 0;
    }

    DragHandler {
        id: drag

        target: null
        acceptedDevices: PointerDevice.TouchScreen
        dragThreshold: 6
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        xAxis.enabled: root.horizontal
        yAxis.enabled: !root.horizontal

        property real lastValue: 0
        property real lastTime: 0

        onActiveChanged: {
            if (active) {
                root.reset();
                drag.lastValue = root.horizontal ? drag.centroid.scenePosition.x :
                                                   drag.centroid.scenePosition.y;
                drag.lastTime = Date.now();
            } else {
                if (root.distance >= 12 && (root.distance >= root.shortDistance || root.velocity
                                            >= root.velocityThreshold)) {
                    const action = root.longReached ? root.longAction : root.shortAction;
                    if (action !== "")
                        root.triggered(action, root.screenName);
                }
                root.reset();
            }
        }
        onActiveTranslationChanged: {
            if (!active)
                return;
            const now = Date.now();
            const value = root.horizontal ? drag.centroid.scenePosition.x : drag.centroid.scenePosition.y;
            const raw = root.direction * (root.horizontal ? drag.activeTranslation.x :
                                                            drag.activeTranslation.y);
            if (now > drag.lastTime)
                root.velocity = root.direction * (value - drag.lastValue) / (now - drag.lastTime);
            drag.lastValue = value;
            drag.lastTime = now;
            root.distance = Math.max(0, raw);
            root.progress = Math.min(1.5, root.distance / Math.max(1, root.longDistance));
        }
    }
}
