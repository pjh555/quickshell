import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root
    property string iconName: ""
    property url iconSource: ""
    property bool iconTinted: false
    property string label: ""
    property string tooltipText: ""
    property bool showLabel: false
    property bool vertical: false
    property bool selected: false
    readonly property bool hasLabel: showLabel && label !== ""
    signal clicked
    implicitWidth: pointer.implicitWidth
    implicitHeight: pointer.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    Accessible.onPressAction: root.clicked()
    opacity: enabled ? 1 : 0.4
    BarActionButton {
        id: pointer
        anchors.fill: parent
        vertical: root.vertical
        expandedContent: root.hasLabel
        Accessible.name: root.tooltipText
        onClicked: root.clicked()
        contentItem: Item {
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight
            GridLayout {
                id: content
                anchors.centerIn: parent
                columns: root.vertical ? 1 : 2
                rowSpacing: Sizes.barLabelSpacing
                columnSpacing: Sizes.barLabelSpacing
                MaterialSymbol {
                    Layout.preferredWidth: Sizes.barIconSize
                    Layout.preferredHeight: Sizes.barIconSize
                    Layout.alignment: Qt.AlignCenter
                    visible: root.iconSource.toString() === ""
                    text: root.iconName
                    iconSize: Sizes.barIconSize
                    color: root.selected || pointer.visualFocus || pointer.pointerHovered
                           ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                }
                Item {
                    Layout.preferredWidth: Sizes.barIconSize + 4
                    Layout.preferredHeight: Sizes.barIconSize + 4
                    Layout.alignment: Qt.AlignCenter
                    visible: root.iconSource.toString() !== ""

                    Image {
                        id: iconArt

                        anchors.fill: parent
                        source: root.iconSource
                        sourceSize.width: Math.round((Sizes.barIconSize + 4) * 4)
                        sourceSize.height: Math.round((Sizes.barIconSize + 4) * 4)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        opacity: pointer.pointerHovered ? 0.85 : 1
                    }

                    ColorOverlay {
                        anchors.fill: parent
                        source: iconArt
                        visible: root.iconTinted
                        color: root.selected || pointer.visualFocus || pointer.pointerHovered
                               ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                    }
                }
                Item {
                    visible: root.hasLabel
                    readonly property real extent: Math.min(120, labelText.implicitWidth)
                    implicitWidth: root.vertical ? labelText.implicitHeight : extent
                    implicitHeight: root.vertical ? extent : labelText.implicitHeight
                    Layout.alignment: Qt.AlignCenter
                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        width: parent.extent
                        rotation: root.vertical ? (PersonalizationConfig.barPosition === "right" ? 90 : -90) :
                                                  0
                        text: root.label
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        color: Appearance.colors.colOnSurface
                    }
                }
            }
        }
    }
    PopupToolTip {
        extraVisibleCondition: pointer.pointerHovered
        text: root.tooltipText
    }
}
