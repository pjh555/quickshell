import QtQuick
import Quickshell
import Clavis.WindowPreview
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var windowData
    required property int windowIndex
    required property var overview
    required property real cellX
    required property real cellY
    required property real cellWidth
    required property real cellHeight

    property bool dragging: false
    property point dragOffset: Qt.point(0, 0)
    property point pressScene: Qt.point(0, 0)
    property bool hovered: false

    readonly property bool isDragged: root.overview.dragging && root.overview.dragIndex === root.windowIndex
    readonly property var niriFrame: {
        const revision = WindowPreviewService.revision;
        return WindowManagerService.niriBackend ? WindowManagerService.previewFrame(root.windowData.id) :
                                                  null;
    }
    readonly property bool hasNiriFrame: !!root.niriFrame && root.niriFrame.hasFrame

    x: root.cellX + (root.dragging ? root.dragOffset.x : 0)
    y: root.cellY + (root.dragging ? root.dragOffset.y : 0)
    width: root.cellWidth
    height: root.cellHeight
    scale: root.isDragged ? 1.025 : 1
    transformOrigin: Item.Center
    z: root.isDragged ? 100 : 1

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: BlurService.backgroundColor(Appearance.macos.surfaceSecondary)
        border.width: root.hovered || root.isDragged ? 2 : 1
        border.color: root.isDragged ? Appearance.macos.accent : root.hovered ? Appearance.applyAlpha(
                                                                                    Appearance.macos.accent,
                                                                                    0.55) : Appearance.macos.glassBorder
        clip: true

        Image {
            id: thumbnail

            anchors.fill: parent
            anchors.margins: 2
            source: WindowManagerService.niriBackend ? "" : (WindowManagerService.visible
                                                             ? WindowManagerService.thumbnailFor(
                                                                   root.windowData.id) : "")
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: !WindowManagerService.niriBackend && status === Image.Ready
        }

        CaptureImage {
            anchors.fill: parent
            frame: root.niriFrame
            visible: WindowManagerService.niriBackend && root.hasNiriFrame
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 300)
            height: 54
            radius: 14
            visible: WindowManagerService.niriBackend ? !root.hasNiriFrame : thumbnail.status === Image.Error
                                                        || thumbnail.status === Image.Null
            color: Appearance.macos.macFill

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                text: root.windowData.title
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 17
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 46
            color: Qt.rgba(0, 0, 0, 0.58)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.windowData.title
                    width: Math.min(implicitWidth, root.width - 70)
                    color: "#ffffffff"
                    font.family: Fonts.ui
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.windowData.workspace
                    visible: root.windowData.workspace !== ""
                    color: Qt.rgba(1, 1, 1, 0.46)
                    font.family: Fonts.ui
                    font.pixelSize: 11
                }
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: mouse => {
                       root.pressScene = pointer.mapToItem(null, mouse.x, mouse.y);
                       root.dragging = false;
                       root.dragOffset = Qt.point(0, 0);
                   }
        onPositionChanged: mouse => {
                               if (!pressed)
                               return;
                               const scene = pointer.mapToItem(null, mouse.x, mouse.y);
                               const delta = Qt.point(scene.x - root.pressScene.x, scene.y
                                                      - root.pressScene.y);
                               if (!root.dragging && Math.hypot(delta.x, delta.y) > 8) {
                                   root.dragging = true;
                                   root.overview.beginDrag(root.windowIndex);
                               }
                               if (!root.dragging)
                               return;
                               root.dragOffset = delta;
                               const point = root.overview.pointForScene(scene.x, scene.y);
                               root.overview.updateDrag(root.windowIndex, point);
                           }
        onReleased: mouse => {
                        if (root.dragging) {
                            const scene = pointer.mapToItem(null, mouse.x, mouse.y);
                            const point = root.overview.pointForScene(scene.x, scene.y);
                            root.overview.finishDrag(root.windowIndex, point);
                            root.dragging = false;
                            root.dragOffset = Qt.point(0, 0);
                        } else {
                            root.overview.activate(root.windowIndex);
                        }
                    }
        onDoubleClicked: root.overview.fullscreenAt(root.windowIndex)
    }

    Row {
        id: windowButtons

        x: 12
        y: 12
        spacing: 6
        z: 30

        WindowControlDot {
            glyph: "close"
            dotColor: "#ff5f57"
            onClicked: WindowManagerService.closeWindow(root.windowData.id)
        }
        WindowControlDot {
            glyph: "remove"
            dotColor: "#ffbd2e"
            onClicked: WindowManagerService.minimizeWindow(root.windowData.id)
        }
        WindowControlDot {
            glyph: "open_in_full"
            dotColor: "#28c840"
            onClicked: WindowManagerService.toggleMaximize(root.windowData.id)
        }
    }

    component WindowControlDot: Rectangle {
        id: control

        property string glyph: "close"
        property color dotColor: "#ff5f57"
        signal clicked

        width: 20
        height: 20
        radius: 10
        color: control.dotColor
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.18)

        MaterialSymbol {
            anchors.centerIn: parent
            text: control.glyph
            iconSize: 12
            color: Qt.rgba(0, 0, 0, 0.62)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    Rectangle {
        id: fullscreenButton

        x: root.width - 46
        y: 12
        width: 34
        height: 30
        radius: 10
        z: 20
        color: fullscreenMouse.pressed ? Appearance.macos.macFillHover : Appearance.macos.macFill
        border.width: 1
        border.color: Appearance.macos.glassBorder

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.windowData.fullscreen ? "fullscreen_exit" : "fullscreen"
            iconSize: 18
            color: Appearance.colors.colOnSurface
        }
        MouseArea {
            id: fullscreenMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.overview.fullscreenAt(root.windowIndex)
        }
    }
}
