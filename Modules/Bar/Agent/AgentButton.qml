import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property var screen: null
    property var barVisualItem: null

    implicitWidth: button.implicitWidth + 2 * root.pillPadding
    implicitHeight: root.pillThickness

    BarLabelButton {
        id: button

        anchors.centerIn: parent
        iconName: "smart_toy"
        tooltipText: AgentService.online ? qsTr("Clavis Agent") : qsTr("Clavis Agent · 未连接")
        selected: AgentService.panelOpen
        onClicked: AgentService.toggle()
    }

    // 顶栏按钮是常驻的 layer-shell 表面，可作为文件拖放目标：
    // 拖文件到 Agent 图标上会自动附加并打开对话面板。
    DropArea {
        id: fileDrop

        anchors.fill: parent

        onEntered: drag => {
                       if (drag.hasUrls)
                       drag.accept(Qt.CopyAction);
                   }
        onDropped: drop => {
                       if (!drop.hasUrls)
                       return;
                       let added = 0;
                       drop.urls.forEach(url => {
                                             if (AgentService.addAttachmentPath(url))
                                             added += 1;
                                         });
                       drop.accept(Qt.CopyAction);
                       if (added > 0)
                       AgentService.openPanel();
                   }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.pillThickness / 2
        visible: fileDrop.containsDrag
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.2)
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.pillPadding + 2
        anchors.topMargin: root.pillPadding + 1
        width: 6
        height: 6
        radius: 3
        visible: AgentService.online
        color: AgentService.busy ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
    }
}
