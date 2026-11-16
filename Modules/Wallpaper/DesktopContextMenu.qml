import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// Desktop background context menu.  The wallpaper surface owns the pointer
// input region, so this separate Top-layer window can place the menu at the
// exact click position and paint above tiled windows.
PanelWindow {
    id: root

    required property var targetScreen

    property bool opened: false
    property real requestedX: 0
    property real requestedY: 0
    readonly property int menuWidth: 244
    readonly property int menuHeight: menuContent.implicitHeight + 16
    property real menuX: Math.max(8, Math.min(root.requestedX, root.width - root.menuWidth - 8))
    property real menuY: Math.max(8, Math.min(root.requestedY, root.height - root.menuHeight - 8))

    screen: root.targetScreen
    visible: root.opened
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clavis-desktop-context-menu"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function openAt(x, y) {
        root.requestedX = Number(x) || 0;
        root.requestedY = Number(y) || 0;
        root.opened = true;
    }

    function close() {
        root.opened = false;
    }

    onOpenedChanged: {
        if (root.opened)
            Qt.callLater(() => keyScope.forceActiveFocus());
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.opened

        Keys.onEscapePressed: event => {
                                  root.close();
                                  event.accepted = true;
                              }

        StyledRectangularShadow {
            target: menuPanel
            opacity: menuPanel.opacity
        }

        Rectangle {
            id: menuPanel

            x: root.menuX
            y: root.menuY
            width: root.menuWidth
            height: root.menuHeight
            radius: 14
            color: BlurService.backgroundColor(Appearance.colors.colLayer0)
            border.width: 1
            border.color: BlurService.glassBorderColor(false)
            clip: true
            opacity: root.opened ? 1 : 0
            scale: root.opened ? 1 : 0.98
            transformOrigin: Item.TopLeft

            GlassHighlight {
                anchors.fill: parent
                radius: parent.radius
                topStrength: 0.18
                bottomStrength: 0.04
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 110
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                id: menuContent

                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 2

                MenuRow {
                    width: parent.width
                    glyph: "wallpaper"
                    label: qsTr("Change Wallpaper…")
                    onActivated: ControlCenterService.open("wallpaper")
                }

                MenuRow {
                    width: parent.width
                    glyph: "skip_next"
                    label: qsTr("Next Wallpaper")
                    onActivated: WallpaperService.cycleNext()
                }

                MenuRow {
                    width: parent.width
                    glyph: "shuffle"
                    label: qsTr("Random Wallpaper")
                    onActivated: WallpaperService.cycleRandom()
                }

                MenuSeparator {
                    width: parent.width
                }

                MenuRow {
                    width: parent.width
                    glyph: "dashboard_customize"
                    label: qsTr("Desktop Card Layout…")
                    onActivated: ControlCenterService.open("general.sidebar")
                }

                MenuRow {
                    width: parent.width
                    glyph: "monitor"
                    label: qsTr("Display Settings…")
                    onActivated: ControlCenterService.open("general.displays")
                }

                MenuSeparator {
                    width: parent.width
                }

                MenuRow {
                    width: parent.width
                    glyph: "terminal"
                    label: qsTr("Open Terminal")
                    onActivated: ApplicationService.launchCommand(["xdg-terminal-exec"])
                }

                MenuRow {
                    width: parent.width
                    glyph: "folder"
                    label: qsTr("Open Home Folder")
                    onActivated: ApplicationService.openUrl(Paths.fileUrl(Paths.homeDir))
                }
            }
        }
    }

    component MenuRow: RippleButton {
        id: row

        property string glyph: ""
        property string label: ""

        text: row.label
        implicitHeight: 36
        buttonRadius: 9
        contentItem: RowLayout {
            spacing: 10
            MaterialSymbol {
                text: row.glyph
                iconSize: 18
                color: Appearance.colors.colOnSurface
            }
            Text {
                Layout.fillWidth: true
                text: row.label
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        releaseAction: () => {
                           root.close();
                           row.activated();
                       }
        signal activated
    }

    component MenuSeparator: Rectangle {
        implicitHeight: 9
        color: "transparent"

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12)
        }
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: menuPanel
        radius: menuPanel.radius
    }
}
