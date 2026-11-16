pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

import "Layouts.js" as Layouts

Item {
    id: root

    property var style: null

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: root.style ? root.style.panelRadius : 24
        color: root.style ? BlurService.backgroundColor(root.style.panelBase) : "#F2F2F7"
        border.width: 1
        border.color: root.style ? BlurService.glassBorderColor(false) : "#00000010"
        clip: true

        GlassHighlight {
            anchors.fill: parent
            radius: parent.radius
            topStrength: 0.16
            bottomStrength: 0.035
        }

        Column {
            anchors.fill: parent
            anchors.margins: root.style ? root.style.panelPadding : 10
            spacing: root.style ? root.style.toolbarGap : 6

            KeyboardToolbar {
                width: parent.width
                height: root.style ? root.style.toolbarHeight : 40
                style: root.style
            }

            Loader {
                id: bodyLoader

                width: parent.width
                height: parent.height - (root.style ? root.style.toolbarHeight : 40) - (root.style
                                                                                        ? root.style.toolbarGap :
                                                                                          6)
                sourceComponent: {
                    if (TouchKeyboardService.page === "emoji")
                    return emojiComponent;
                    if (TouchKeyboardService.page === "symbols")
                    return symbolsComponent;
                    if (TouchKeyboardService.page === "numbers")
                    return numbersComponent;
                    if (TouchKeyboardService.page === "keys")
                    return keysComponent;
                    if (TouchKeyboardService.page === "symbolsall")
                    return symbolsAllComponent;
                    if (TouchKeyboardService.layoutMode === "nine")
                    return nineKeyComponent;
                    return qwertyComponent;
                }
            }
        }
    }

    Component {
        id: qwertyComponent

        KeyboardLayoutView {
            style: root.style
            rows: Layouts.qwertyRows
        }
    }

    Component {
        id: symbolsComponent

        KeyboardLayoutView {
            style: root.style
            rows: Layouts.symbolRows
        }
    }

    Component {
        id: numbersComponent

        NumberPad {
            style: root.style
        }
    }

    Component {
        id: keysComponent

        KeyboardLayoutView {
            style: root.style
            rows: Layouts.functionRows
        }
    }

    Component {
        id: symbolsAllComponent

        SymbolPanel {
            style: root.style
        }
    }

    Component {
        id: nineKeyComponent

        NineKeyLayout {
            style: root.style
        }
    }

    Component {
        id: emojiComponent

        EmojiPanel {
            style: root.style
        }
    }
}
