import QtQuick

// Generic renderer for frame-based pet packs. It knows nothing about a
// specific character: the pack manifest supplies named animations, frame
// lists, fps and loop behaviour.
Item {
    id: root

    property var pack: null
    property real petSize: 112
    property string current: ""
    property bool mirror: false
    property int frameIndex: 0
    property int pingDir: 1
    property bool ready: false

    readonly property var anim: {
        if (!root.pack || !root.pack.animations)
            return null;
        return root.pack.animations[root.current] || root.pack.animations.idle || null;
    }

    function play(name) {
        if (!root.pack || !root.pack.animations)
            return;
        const next = root.pack.animations[name] ? name : (root.pack.animations.idle ? "idle" : "");
        if (!next || root.current === next)
            return;
        root.current = next;
        root.frameIndex = 0;
        root.pingDir = 1;
        const value = root.pack.animations[next];
        frameTimer.interval = Math.max(16, 1000 / Math.max(0.1, Number(value.fps) || 8));
        frameTimer.restart();
    }

    Repeater {
        model: root.anim && root.anim.frames ? root.anim.frames : []

        delegate: Image {
            anchors.fill: parent
            source: modelData
            sourceSize: Qt.size(Math.max(1, Math.ceil(root.petSize * 2)),
                                Math.max(1, Math.ceil(root.petSize * 2)))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            mirror: root.mirror
            opacity: index === root.frameIndex ? 1 : 0

            onStatusChanged: {
                if (index === 0 && status === Image.Ready)
                    root.ready = true;
            }
        }
    }

    Timer {
        id: frameTimer

        repeat: true
        onTriggered: {
            if (!root.anim || !root.anim.frames || root.anim.frames.length <= 1)
                return;
            const count = root.anim.frames.length;
            if (root.anim.pingpong === true) {
                if (root.frameIndex + 1 >= count)
                    root.pingDir = -1;
                else if (root.frameIndex <= 0)
                    root.pingDir = 1;
                root.frameIndex = Math.max(0, Math.min(count - 1, root.frameIndex + root.pingDir));
                return;
            }
            if (root.frameIndex + 1 < count) {
                root.frameIndex++;
                return;
            }
            if (root.anim.loop === true) {
                root.frameIndex = 0;
                return;
            }
            if (root.pack.animations.idle) {
                root.play("idle");
            } else {
                frameTimer.stop();
            }
        }
    }

    Component.onCompleted: play("idle")

    onPackChanged: {
        root.ready = false;
        root.current = "";
        root.frameIndex = 0;
        Qt.callLater(function () {
            root.play("idle");
        });
    }
}
