pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool opened: false

    signal toggleRequested
    signal closeRequested

    function toggle() {
        if (root.opened)
            root.closeRequested();
        else
            root.toggleRequested();
    }

    function close() {
        if (root.opened)
            root.closeRequested();
    }

    function setOpened(value) {
        root.opened = !!value;
    }
}
