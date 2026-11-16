import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// A small mac-like window menu opened by right-clicking or long-pressing the
// active-window pill in the top bar.
PopupWindow {
    id: root

    required property Item anchorItem
    property var windowData: null

    readonly property bool hasWindow: !!root.windowData && !!root.windowData.id
    readonly property string title: root.hasWindow ? String(root.windowData.title || root.windowData.appName
                                                            || root.windowData.appId || qsTr("Window")) : ""
    readonly property string appName: root.hasWindow ? String(root.windowData.appName || root.windowData.appId
                                                              || "") : ""
    readonly property string icon: root.hasWindow ? String(root.windowData.iconPath || "") : ""

    visible: false
    color: "transparent"
    grabFocus: ThemeService.isNiriSession
    implicitWidth: 248
    implicitHeight: menuBackground.implicitHeight + 20

    anchor {
        item: root.anchorItem
        rect.x: 0
        rect.y: 0
        rect.width: Math.max(1, root.anchorItem ? root.anchorItem.width : 1)
        rect.height: Math.max(1, root.anchorItem ? root.anchorItem.height : 1)
        edges: Edges.Bottom
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.SlideX
    }

    function closeMenu() {
        root.visible = false;
    }

    PanelWindow {
        visible: root.visible && ThemeService.isNiriSession
        screen: root.anchorItem && root.anchorItem.QsWindow && root.anchorItem.QsWindow.window
                ? root.anchorItem.QsWindow.window.screen : null
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-active-window-menu-backdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.closeMenu()
        }
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.visible

        Keys.onEscapePressed: event => {
                                  root.closeMenu();
                                  event.accepted = true;
                              }

        StyledRectangularShadow {
            target: menuBackground
            opacity: menuBackground.opacity
        }

        Rectangle {
            id: menuBackground

            x: 10
            y: 10
            implicitWidth: menuColumn.implicitWidth + 12
            implicitHeight: menuColumn.implicitHeight + 12
            radius: 16
            color: BlurService.backgroundColor(Appearance.colors.colLayer0)
            border.width: 1
            border.color: BlurService.glassBorderColor(false)
            clip: true

            GlassHighlight {
                anchors.fill: parent
                radius: parent.radius
                topStrength: 0.18
                bottomStrength: 0.04
            }

            Column {
                id: menuColumn

                anchors.centerIn: parent
                spacing: 2
                width: Math.max(208, Math.min(240, root.width - 44))

                Item {
                    width: parent.width
                    height: 48

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 9

                        ThemeIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            iconSource: ApplicationService.iconSource(root.icon)
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            visible: root.icon !== ""
                        }

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "web_asset"
                            iconSize: 22
                            color: Appearance.colors.colOnSurfaceVariant
                            visible: root.icon === ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            spacing: 1

                            Text {
                                width: parent.width
                                text: root.title
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.appName
                                visible: root.appName !== "" && root.appName !== root.title
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.ui
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.14)
                }

                MenuRow {
                    width: parent.width
                    glyph: root.windowData && root.windowData.fullscreen ? "fullscreen_exit" : "fullscreen"
                    label: root.windowData && root.windowData.fullscreen ? qsTr("退出全屏") : qsTr("全屏")
                    onActivated: Niri.toggleFullscreenWindow(root.windowData.id)
                }
                MenuRow {
                    width: parent.width
                    glyph: "open_in_full"
                    label: qsTr("最大化")
                    onActivated: Niri.toggleMaximizeWindow(root.windowData.id)
                }
                MenuRow {
                    width: parent.width
                    glyph: "remove"
                    label: qsTr("最小化")
                    enabled: root.hasWindow && Niri.supportsMinimize
                    onActivated: Niri.minimizeWindow(root.windowData.id)
                }
                MenuRow {
                    width: parent.width
                    glyph: "close"
                    label: qsTr("关闭窗口")
                    destructive: true
                    onActivated: Niri.closeWindow(root.windowData.id)
                }
            }
        }
    }

    component MenuRow: RippleButton {
        id: row

        property string glyph: ""
        property string label: ""
        property bool destructive: false

        implicitHeight: 38
        buttonRadius: 10
        enabled: root.hasWindow
        contentItem: RowLayout {
            spacing: 10
            MaterialSymbol {
                text: row.glyph
                iconSize: 18
                color: row.destructive ? Appearance.m3colors.m3error : Appearance.colors.colOnSurface
            }
            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.destructive ? Appearance.m3colors.m3error : Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        releaseAction: () => {
                           root.closeMenu();
                           row.activated();
                       }
        signal activated
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: menuBackground
        radius: 16
    }
}
