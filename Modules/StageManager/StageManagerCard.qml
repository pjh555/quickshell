import QtQuick
import Clavis.WindowPreview
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// A centered Stage Manager window card. The card is deliberately opaque
// enough to read as a real window over the blurred desktop; only the preview
// itself stays translucent.
Item {
    id: root

    required property var windowData
    property int groupCount: 1
    property real tiltAngle: -9

    signal activated

    readonly property bool hovered: pointer.containsMouse
    readonly property string title: String(root.windowData.title || root.windowData.appName
                                           || root.windowData.appId || qsTr("窗口"))
    readonly property string icon: String(root.windowData.iconPath || "")
    readonly property var previewFrame: {
        const revision = WindowPreviewService.revision;
        return WindowPreviewService.frameFor(root.windowData.id);
    }

    opacity: root.windowData.isMinimized ? 0.82 : 1
    scale: root.hovered ? 1.012 : 1
    z: root.hovered ? 2 : 0
    transform: Rotation {
        origin.x: root.width
        origin.y: root.height / 2
        axis {
            x: 0
            y: 1
            z: 0
        }
        angle: root.tiltAngle
    }

    Behavior on scale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: 18
        color: Appearance.applyAlpha(Appearance.macos.surfaceElevated, 0.94)
        border.width: 1
        border.color: root.hovered ? Appearance.applyAlpha(Appearance.macos.accent, 0.72) :
                                     Appearance.macos.glassBorder

    }

    StyledRectangularShadow {
        target: surface
        z: -1
        opacity: root.hovered ? 1 : 0.8
    }

    Rectangle {
        id: previewFrame

        anchors.fill: parent
        anchors.margins: 5
        radius: 14
        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.10)
        clip: true

        CaptureImage {
            anchors.fill: parent
            frame: root.previewFrame
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !root.previewFrame || !root.previewFrame.hasFrame
            text: "web_asset"
            iconSize: 38
            color: Appearance.colors.colOnSurfaceVariant
        }

        Rectangle {
            anchors.fill: parent
            radius: previewFrame.radius
            color: "transparent"
            border.width: 1
            border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.10)
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 62
        radius: 18
        opacity: root.hovered ? 1 : 0.72
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.62)
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Item {
        id: iconBadge

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.bottomMargin: 13
        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.52)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.28)
        }

        ThemeIcon {
            anchors.centerIn: parent
            width: 22
            height: 22
            iconSource: ApplicationService.iconSource(root.icon)
            sourceSize: Qt.size(44, 44)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: root.icon !== ""
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.icon === ""
            text: "web_asset"
            iconSize: 18
            color: "#ffffffff"
        }
    }

    Text {
        anchors.left: iconBadge.right
        anchors.leftMargin: 9
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: iconBadge.verticalCenter
        text: root.title
        color: "#ffffffff"
        font.family: Fonts.ui
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
        opacity: root.hovered ? 1 : 0.78
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: Math.max(22, countText.implicitWidth + 10)
        height: 22
        radius: 8
        visible: root.groupCount > 1
        color: Qt.rgba(0, 0, 0, 0.62)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Text {
            id: countText

            anchors.centerIn: parent
            text: String(root.groupCount)
            color: "#ffffffff"
            font.family: Fonts.numeric
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
