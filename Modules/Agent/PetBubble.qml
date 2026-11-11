import QtQuick
import qs.Common

// Non-interactive speech bubble rendered in the pet's full-screen layer
// surface. It is intentionally outside the pet input mask, so it never steals
// clicks from the application underneath.
Item {
    id: root

    property Item anchorItem: null
    property string text: ""
    property bool shown: false
    property int duration: 4200
    property real maxWidth: 320

    readonly property real textWidth: maxWidth - 28
    readonly property real bubbleWidth: Math.min(maxWidth, Math.max(120, textItem.contentWidth + 28))
    readonly property real bubbleHeight: textItem.implicitHeight + 18

    visible: shown
    opacity: shown ? 1 : 0
    z: 40

    function show(message, ms) {
        if (!message)
            return;
        root.text = String(message);
        root.duration = Math.max(1200, Number(ms) || 4200);
        root.shown = true;
        hideTimer.restart();
    }

    function hide() {
        root.shown = false;
        hideTimer.stop();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: bubble

        x: root.anchorItem
           ? Math.max(8, Math.min(root.parent.width - width - 8,
                                  root.anchorItem.x + root.anchorItem.width / 2 - width / 2))
           : 8
        y: {
            if (!root.anchorItem)
                return 8;
            const above = root.anchorItem.y - root.bubbleHeight - 10;
            return above >= 8 ? above : Math.min(root.parent.height - root.bubbleHeight - 8,
                                                 root.anchorItem.y + root.anchorItem.height + 10);
        }
        width: root.bubbleWidth
        height: root.bubbleHeight
        radius: 15
        color: Appearance.colors.colSurfaceContainerHigh
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Rectangle {
            width: 12
            height: 12
            rotation: 45
            color: bubble.color
            border.width: 1
            border.color: bubble.border.color
            x: bubble.width / 2 - 6
            y: bubble.height - 7
        }

        Text {
            id: textItem

            anchors.centerIn: parent
            width: root.textWidth
            text: root.text
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    Timer {
        id: hideTimer

        interval: root.duration
        onTriggered: root.shown = false
    }
}
