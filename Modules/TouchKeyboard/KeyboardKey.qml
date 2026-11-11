pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Components
import qs.Services

Rectangle {
    id: root

    property var keyData: null
    property var style: null
    property var popupHost: null
    property bool active: false

    signal activated(string action, string value)

    readonly property bool isAccent: root.keyData !== null && root.keyData.style === "accent"
    readonly property bool isSpecial: root.keyData !== null && root.keyData.style === "special"
    readonly property bool isRound: root.keyData !== null && root.keyData.round === true
    readonly property string iconName: root.keyData !== null ? String(root.keyData.icon || "") : ""
    readonly property string rawLabel: root.keyData !== null ? String(root.keyData.label || "") : ""
    readonly property string sublabel: root.keyData !== null ? String(root.keyData.sublabel || "") : ""
    readonly property string sublabelPosition: root.keyData !== null ? String(root.keyData.sublabelPosition
                                                                              || "top") : "top"
    readonly property var longPressOptions: root.keyData !== null && root.keyData.longPress !== undefined
                                            ? root.keyData.longPress : []
    readonly property var swipeUpAction: root.keyData !== null && root.keyData.swipeUp !== undefined
                                         ? root.keyData.swipeUp : null
    readonly property bool repeatOnHold: root.keyData !== null && root.keyData.repeat === true
    readonly property string displayLabel: {
        if (root.keyData === null)
        return "";
        if (root.keyData.id === "language")
        return "中/EN";
        if (root.keyData.id === "space")
        return "";
        if (root.keyData.chineseLabel !== undefined && TouchKeyboardService.chinese
            && TouchKeyboardService.page === "letters")
        return String(root.keyData.chineseLabel);
        let label = root.rawLabel;
        if (TouchKeyboardService.effectiveShift && label.length === 1)
        label = label.toUpperCase();
        return label;
    }
    readonly property real singleCharacterSize: Math.max(15, Math.min(19, root.height * 0.28))
    readonly property real labelSize: root.displayLabel.length <= 1 ? root.singleCharacterSize : Math.max(11,
                                                                                                          Math.min(13,
                                                                                                                   root.height
                                                                                                                   * 0.18))
    readonly property real iconSize: Math.max(16, Math.min(20, root.height * 0.28))

    function activate(action, value) {
        root.activated(String(action || ""), String(value || ""));
    }

    function activateTap() {
        if (root.keyData === null)
            return;
        const now = Date.now();
        if (root.keyData.doubleTap !== undefined && now - lastTapTime < 320) {
            lastTapTime = 0;
            root.activate(root.keyData.doubleTap.action, root.keyData.doubleTap.value);
            return;
        }
        lastTapTime = now;
        root.activate(root.keyData.action || "char", root.keyData.value || "");
    }

    function openLongPress() {
        if (root.popupHost !== null && root.longPressOptions.length > 0)
            root.popupHost.showFor(root, root.longPressOptions);
    }

    function beginPress(x, y) {
        mouse.pressPoint = Qt.point(x, y);
        mouse.longPressTriggered = false;
        mouse.swipeTriggered = false;
        mouse.repeatStarted = false;
        mouse.cancelled = false;
        if (root.longPressOptions.length > 0)
            holdTimer.start();
        if (root.repeatOnHold)
            repeatDelay.start();
    }

    function updatePress(x, y) {
        if (!mouse.pressed)
            return;
        const dx = x - mouse.pressPoint.x;
        const dy = y - mouse.pressPoint.y;
        if (Math.abs(dy) > mouse.swipeThreshold && Math.abs(dy) > Math.abs(dx) * 1.15 && dy < 0
                && root.swipeUpAction !== null) {
            holdTimer.stop();
            repeatDelay.stop();
            repeatTimer.stop();
            mouse.swipeTriggered = true;
            mouse.cancelled = false;
            return;
        }
        if (Math.abs(dx) > 14 || Math.abs(dy) > 14) {
            holdTimer.stop();
            repeatDelay.stop();
            repeatTimer.stop();
            mouse.cancelled = true;
        }
    }

    property double lastTapTime: 0
    property bool pressed: mouse.pressed

    // macOS keycaps use one corner radius; Gboard pill keys are flattened
    // so the keyboard keeps the Clavis material language.
    radius: root.style ? root.style.keyRadius : 9
    color: {
        if (root.isAccent)
        return root.style ? root.style.accent : "#4DB6AC";
        if (mouse.pressed)
        return root.style ? root.style.keyPressed : "#D8E0E5";
        if (root.active)
        return root.style ? root.style.accentSoft : "#D6E9FF";
        if (mouse.containsMouse)
        return root.style ? root.style.keyHover : "#F3F6F8";
        return root.isSpecial ? (root.style ? root.style.keySpecial : "#E4E7E9") : (root.style
                                                                                    ? root.style.key :
                                                                                      "#FFFFFF");
    }
    border.width: 1
    border.color: root.isAccent ? (root.style ? root.style.accent : "#4DB6AC") : root.active ? (root.style
                                                                                                ? root.style.accent :
                                                                                                  "#4DB6AC") :
                                                                                               (root.style
                                                                                                ? root.style.keyBorder :
                                                                                                  "#00000008")
    scale: mouse.pressed ? 0.97 : 1
    opacity: root.enabled ? 1 : 0.4

    Behavior on scale {
        NumberAnimation {
            duration: 70
            easing.type: Easing.OutQuad
        }
    }

    Accessible.name: root.displayLabel !== "" ? root.displayLabel : (root.iconName !== "" ? root.iconName :
                                                                                            root.rawLabel)
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.activateTap()

    Text {
        anchors.centerIn: parent
        visible: root.iconName === ""
        text: root.displayLabel
        color: root.isAccent ? (root.style ? root.style.onAccent : "#FFFFFF") : root.active ? (root.style
                                                                                               ? root.style.accent :
                                                                                                 "#4DB6AC") : (
                                                                                                  root.style
                                                                                                  ? root.style.text :
                                                                                                    "#1F1F1F")
        font.family: Fonts.ui
        font.pixelSize: root.labelSize
        font.weight: Font.Medium
        textFormat: Text.PlainText
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 3
        visible: root.sublabel !== "" && root.sublabelPosition === "top" && root.iconName === ""
        text: root.sublabel
        color: root.isAccent ? (root.style ? root.style.onAccent : "#FFFFFF") : (root.style
                                                                                 ? root.style.textMuted :
                                                                                   "#80868B")
        opacity: 0.72
        font.family: Fonts.ui
        font.pixelSize: Math.max(8, Math.min(10, root.height * 0.14))
        font.weight: Font.Medium
        textFormat: Text.PlainText
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 6
        anchors.bottomMargin: 3
        visible: root.sublabel !== "" && root.sublabelPosition === "bottom" && root.iconName === ""
        text: root.sublabel
        color: root.isAccent ? (root.style ? root.style.onAccent : "#FFFFFF") : (root.style
                                                                                 ? root.style.textMuted :
                                                                                   "#80868B")
        opacity: 0.8
        font.family: Fonts.ui
        font.pixelSize: Math.max(9, Math.min(11, root.height * 0.16))
        font.weight: Font.Medium
        textFormat: Text.PlainText
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.iconName !== ""
        text: root.iconName
        iconSize: root.iconSize
        fill: root.active ? 1 : 0
        color: root.isAccent ? (root.style ? root.style.onAccent : "#FFFFFF") : root.active ? (root.style
                                                                                               ? root.style.accent :
                                                                                                 "#4DB6AC") : (
                                                                                                  root.style
                                                                                                  ? root.style.text :
                                                                                                    "#1F1F1F")
    }

    MouseArea {
        id: mouse

        property point pressPoint
        property bool longPressTriggered: false
        property bool swipeTriggered: false
        property bool repeatStarted: false
        property bool cancelled: false
        readonly property real swipeThreshold: Math.max(14, root.height * 0.18)

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => root.beginPress(event.x, event.y)
        onPositionChanged: event => root.updatePress(event.x, event.y)

        onReleased: event => {
            holdTimer.stop();
            repeatDelay.stop();
            repeatTimer.stop();
            if (mouse.swipeTriggered && root.swipeUpAction !== null) {
                root.activate(root.swipeUpAction.action || "commit", root.swipeUpAction.value || "");
            } else if (!mouse.longPressTriggered && !mouse.cancelled && !mouse.repeatStarted) {
                root.activateTap();
            }
            mouse.pressPoint = Qt.point(0, 0);
        }

        onCanceled: {
            holdTimer.stop();
            repeatDelay.stop();
            repeatTimer.stop();
            mouse.cancelled = true;
        }
    }

    Timer {
        id: holdTimer

        interval: 360
        repeat: false
        onTriggered: {
            if (root.longPressOptions.length === 0)
            return;
            mouse.longPressTriggered = true;
            root.openLongPress();
        }
    }

    Timer {
        id: repeatDelay

        interval: 420
        repeat: false
        onTriggered: {
            if (!mouse.pressed)
            return;
            mouse.repeatStarted = true;
            root.activateTap();
            repeatTimer.start();
        }
    }

    Timer {
        id: repeatTimer

        interval: 65
        repeat: true
        onTriggered: {
            if (mouse.pressed)
            root.activateTap();
            else
            repeatTimer.stop();
        }
    }
}
