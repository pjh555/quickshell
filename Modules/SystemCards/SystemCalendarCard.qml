import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool active: true
    property bool glassSurface: false
    property color surfaceColor: Appearance.colors.colSurfaceContainerHigh
    property color foregroundColor: Appearance.colors.colOnSurface
    property color secondaryForegroundColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.78)
    property color accentColor: Appearance.colors.colPrimary
    property date currentDate: new Date()
    readonly property var monthNames: [qsTr("January"), qsTr("February"), qsTr("March"), qsTr("April"), qsTr(
            "May"), qsTr("June"), qsTr("July"), qsTr("August"), qsTr("September"), qsTr("October"), qsTr(
            "November"), qsTr("December")]
    readonly property var weekdayNames: [qsTr("Sun"), qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr(
            "Fri"), qsTr("Sat")]
    readonly property var accessibleWeekdayNames: [qsTr("Sunday"), qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"),
        qsTr("Thursday"), qsTr("Friday"), qsTr("Saturday")]
    readonly property string calendarFamily: Fonts.expressive
    readonly property var calendarAxes: Fonts.familyAvailable(Fonts.bundledFamilyName) && Fonts.expressive
                                        === Fonts.bundledFamilyName ? ({
                                                                           "ROND": 45,
                                                                           "wdth": 78
                                                                       }) : ({})

    radius: root.glassSurface ? Appearance.rounding.veryLarge : Appearance.rounding.extraLarge
    color: root.surfaceColor
    clip: true
    Accessible.name: currentDate.getFullYear() + qsTr(" ") + (currentDate.getMonth() + 1) + qsTr("/")
                     + currentDate.getDate() + qsTr(", ") + accessibleWeekdayNames[currentDate.getDay()]

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Rectangle {
        id: headingBand

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Math.max(42, root.height * 0.36)
        color: root.glassSurface ? Qt.rgba(1, 1, 1, 0.16) : Appearance.colors.colSecondaryContainer
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Text {
            anchors.centerIn: parent
            text: root.monthNames[root.currentDate.getMonth()] + "  "
                  + root.weekdayNames[root.currentDate.getDay()]
            color: root.glassSurface ? root.foregroundColor : Appearance.colors.colOnSecondaryContainer
            renderType: Text.NativeRendering
            font {
                family: root.glassSurface ? Fonts.ui : root.calendarFamily
                pixelSize: root.glassSurface ? 16 : Math.min(Typography.titleMedium.pixelSize,
                                                             headingBand.height * 0.36)
                weight: root.glassSurface ? Font.DemiBold : Font.Bold
                letterSpacing: root.glassSurface ? 0.4 : 0.8
                variableAxes: root.glassSurface ? ({}) : root.calendarAxes
            }
        }
    }

    Text {
        anchors {
            top: headingBand.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        text: String(root.currentDate.getDate())
        color: root.glassSurface ? root.foregroundColor : Appearance.colors.colOnSurface
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: root.calendarFamily
            pixelSize: Math.min(root.width * 0.52, root.height * 0.5)
            weight: Font.Medium
            variableAxes: root.calendarAxes
        }
    }
}
