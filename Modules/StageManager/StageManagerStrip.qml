import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// Persistent macOS-style Stage Manager shelf. The recent-window cards live in
// a narrow rail attached to the left edge, vertically centred. Only the rail is
// interactive; the rest of the desktop stays clickable, so enabling Stage
// Manager does not turn the desktop into a modal one-shot overview.
PanelWindow {
    id: root

    readonly property var recentGroups: {
        const windows = StageManagerService.windows || [];
        const groups = [];
        const byApp = {};

        for (let index = 0; index < windows.length; ++index) {
            const window = windows[index];
            const key = String(window.appId || window.appName || window.id);
            if (byApp[key] === undefined) {
                const group = {
                    "key": key,
                    "window": window,
                    "count": 1
                };
                byApp[key] = group;
                groups.push(group);
            } else {
                byApp[key].count += 1;
            }
        }

        return groups;
    }
    readonly property int count: root.recentGroups.length
    readonly property real gap: 12
    readonly property real railWidth: Math.min(260, Math.max(206, root.width * 0.19))
    readonly property real cardWidth: root.railWidth
    readonly property real cardHeight: Math.min(176, Math.max(128, root.cardWidth * 0.62))
    readonly property real railHeight: Math.min(root.height - 210, Math.max(1, root.count * (root.cardHeight
                                                                                             + root.gap)
                                                                            - root.gap))

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: StageManagerService.visible
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-stage-manager"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Do not mask the full desktop. Clicks to the right of the shelf must reach
    // the active application, exactly as they do in macOS Stage Manager.
    mask: Region {
        item: railSurface
    }

    Item {
        id: railSurface

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.railWidth + 38

        // A soft edge shade keeps the cards readable without turning the whole
        // left edge into an opaque application sidebar. The cards themselves
        // carry the glass surfaces.
        Rectangle {
            id: railBackground

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: root.railWidth + 24
            color: "transparent"
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Appearance.applyAlpha(Appearance.macos.background, 0.28)
                }
                GradientStop {
                    position: 0.72
                    color: Appearance.applyAlpha(Appearance.macos.background, 0.10)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 34
            anchors.leftMargin: 24
            spacing: 9

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "view_sidebar"
                iconSize: 20
                color: Appearance.colors.colPrimary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("台前调度")
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.count > 0
                text: qsTr("%1 个应用").arg(root.count)
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 10
            }
        }

        IconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 26
            anchors.rightMargin: 16
            controlSize: 30
            iconSize: 17
            iconName: "close"
            tooltipText: qsTr("关闭台前调度")
            onClicked: StageManagerService.close()
        }

        // The shelf is vertically centred. Cards are side-arranged along the
        // left edge; they are not a full-width grid and never cover the current
        // application unless the user moves a window underneath the shelf.
        ListView {
            id: rail

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 14
            width: root.cardWidth
            height: root.railHeight
            spacing: root.gap
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.recentGroups

            delegate: StageManagerCard {
                required property var modelData

                width: root.cardWidth
                height: root.cardHeight
                windowData: modelData.window
                groupCount: modelData.count
                tiltAngle: -9
                onActivated: {
                    StageManagerService.focusWindow(modelData.window.id);
                    // Deliberately keep Stage Manager enabled. macOS Stage
                    // Manager remains active after switching applications.
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 14
            visible: root.count === 0
            spacing: 10

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "web_asset_off"
                iconSize: 36
                color: Appearance.colors.colOnSurfaceVariant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("当前没有其他窗口")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 12
            }
        }
    }
}
