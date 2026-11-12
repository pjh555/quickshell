import QtQuick
import QtQuick.Layouts
import qs.Common

Item {
    id: root

    property int currentIndex: 0
    property bool expanded: false
    default property alias tabData: tabBarColumn.data

    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: Metrics.spacingXS

    ColumnLayout {
        id: tabBarColumn

        anchors.fill: parent
        spacing: 0
    }
}
