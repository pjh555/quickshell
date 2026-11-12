import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import "../ControlCenter" as ControlCenter
import "../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property var network: ({})
    property var aggregateDownloadHistory: []
    property var aggregateUploadHistory: []
    property var downloadHistories: ({})
    property var uploadHistories: ({})
    property string preferredInterface: ""
    property color surfaceColor: Appearance.colors.colPrimary
    property color panelColor: Appearance.colors.colPrimaryContainer
    property bool glassSurface: false
    property color foregroundColor: Appearance.colors.colOnSurface
    property color secondaryForegroundColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.78)
    property color accentColor: Appearance.colors.colTertiary
    property bool chartActive: visible
    property int updateInterval: 1000
    readonly property color leftColor: root.glassSurface ? "transparent" : root.surfaceColor
    readonly property color leftForeground: root.glassSurface ? root.foregroundColor :
                                                                Appearance.colors.colOnPrimary
    readonly property color rightColor: root.glassSurface ? Qt.rgba(1, 1, 1, 0.14) : root.panelColor
    readonly property color rightForeground: root.glassSurface ? root.secondaryForegroundColor :
                                                                 Appearance.colors.colOnPrimaryContainer
    readonly property color downloadIconColor: root.glassSurface ? root.accentColor :
                                                                   Appearance.colors.colTertiary
    readonly property color uploadIconColor: root.glassSurface ? Qt.rgba(1, 1, 1, 0.86) : Appearance.mix(
                                                                     Appearance.colors.colPrimary,
                                                                     Appearance.colors.colOnPrimary, 0.76)
    readonly property color downloadChartColor: root.glassSurface ? root.downloadIconColor : Appearance.mix(
                                                                        root.downloadIconColor,
                                                                        root.leftForeground, 0.64)
    readonly property color uploadChartColor: root.glassSurface ? root.uploadIconColor : Appearance.mix(root.uploadIconColor,
                                                                                                        root.leftForeground,
                                                                                                        0.58)
    readonly property var interfaces: Array.isArray(root.network.interfaces) ? root.network.interfaces : []
    readonly property string defaultInterface: String(root.network.defaultInterface || "")
    readonly property string selectedInterfaceName: root.preferredInterface === "" ? root.defaultInterface :
                                                                                     root.preferredInterface
    readonly property var selectedInterface: {
        if (root.preferredInterface === "all")
            return root.network;

        for (let index = 0; index < root.interfaces.length; index += 1) {
            if (String(root.interfaces[index].name || "") === root.selectedInterfaceName)
                return root.interfaces[index];
        }
        return ({});
    }
    readonly property var interfaceOptions: {
        const options = [
                  {
                      "value": "",
                      "label": root.defaultInterface !== "" ? qsTr("Default · %1").arg(root.defaultInterface) :
                                                              qsTr("Default")
                  },
                  {
                      "value": "all",
                      "label": qsTr("Total")
                  }
              ];
        const names = [];
        for (let index = 0; index < root.interfaces.length; index += 1) {
            const networkInterface = root.interfaces[index];
            const name = String(networkInterface.name || "");
            if (name !== "" && networkInterface.loopback !== true)
                names.push(name);
        }
        names.sort();
        for (let index = 0; index < names.length; index += 1) {
            options.push({
                             "value": names[index],
                             "label": names[index]
                         });
        }
        return options;
    }
    readonly property var downloadHistory: root.preferredInterface === "all" ? root.aggregateDownloadHistory :
                                                                               root.downloadHistories[root.selectedInterfaceName]
                                                                               || []
    readonly property var uploadHistory: root.preferredInterface === "all" ? root.aggregateUploadHistory :
                                                                             root.uploadHistories[root.selectedInterfaceName]
                                                                             || []
    readonly property real rightPanelX: Math.round(width * 0.53)
    readonly property int chartHistoryLength: 18
    readonly property real chartMaximum: {
        let maximum = 0;
        const series = [root.downloadHistory || [], root.uploadHistory || []];
        for (let seriesIndex = 0; seriesIndex < series.length; seriesIndex += 1) {
            const points = series[seriesIndex];
            const firstVisibleIndex = Math.max(0, points.length - root.chartHistoryLength);
            for (let index = firstVisibleIndex; index < points.length; index += 1) {
                const value = points[index];
                if (typeof value === "number" && isFinite(value))
                    maximum = Math.max(maximum, value);
            }
        }
        return Math.max(1, maximum * 1.2);
    }
    readonly property var expressiveBoldAxes: Fonts.familyAvailable(Fonts.bundledFamilyName)
                                              && Fonts.expressive === Fonts.bundledFamilyName ? ({
                                                                                                     "GRAD": 100,
                                                                                                     "ROND": 35,
                                                                                                     "wdth": 85
                                                                                                 }) : ({})

    signal interfaceSelected(string networkInterface)

    clip: true
    layer.enabled: true
    Accessible.name: qsTr("Network, download ") + Format.bytesPerSecond(
                         root.selectedInterface.downloadBytesPerSecond) + qsTr(", upload ")
                     + Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.veryLarge
        color: root.leftColor
    }

    Text {
        text: qsTr("Network")
        color: root.leftForeground
        renderType: Text.NativeRendering
        font.family: root.glassSurface ? Fonts.ui : Fonts.expressive
        font.pixelSize: root.glassSurface ? 18 : 34
        font.weight: root.glassSurface ? Font.DemiBold : Font.Black
        font.variableAxes: root.glassSurface ? ({}) : root.expressiveBoldAxes

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: root.glassSurface ? 18 : Appearance.spacing.medium
            topMargin: root.glassSurface ? 18 : 16
        }
    }

    SystemSparkline {
        values: root.uploadHistory
        maximum: root.chartMaximum
        historyLength: root.chartHistoryLength
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.3
        lineColor: root.uploadChartColor
        baselineColor: "transparent"
        lineWidth: 0
        Accessible.ignored: true

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 0
            rightMargin: 0
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }
    }

    SystemSparkline {
        values: root.downloadHistory
        secondaryValues: root.uploadHistory
        maximum: root.chartMaximum
        historyLength: root.chartHistoryLength
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.26
        accessibilityName: qsTr("Recent network activity")
        accessibilityDescription: qsTr("Download ") + Format.bytesPerSecond(
                                      root.selectedInterface.downloadBytesPerSecond) + qsTr(", upload ")
                                  + Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)
        lineColor: root.downloadChartColor
        secondaryLineColor: root.uploadChartColor
        baselineColor: "transparent"
        lineWidth: 3

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 0
            rightMargin: 0
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }
    }

    Rectangle {
        id: ratePanel

        x: root.rightPanelX
        y: 0
        width: root.width - x
        height: root.height
        radius: Appearance.rounding.veryLarge
        color: root.rightColor
        clip: true
        z: 2

        Column {
            id: rateColumn

            spacing: 2
            z: 2

            anchors {
                fill: parent
                leftMargin: Appearance.spacing.medium
                rightMargin: Appearance.spacing.medium
                topMargin: 10
                bottomMargin: 10
            }

            ControlCenter.SplitMenuButton {
                width: parent.width
                height: 36
                buttonHeight: 36
                minimumWidth: parent.width
                maximumWidth: parent.width
                menuMinimumWidth: Math.max(190, width)
                menuMaximumWidth: Math.max(260, width)
                model: root.interfaceOptions
                currentValue: root.preferredInterface
                leadingIcon: "lan"
                buttonColor: root.glassSurface ? Qt.rgba(1, 1, 1, 0.16) : root.leftColor
                buttonHoverColor: root.glassSurface ? Qt.rgba(1, 1, 1, 0.24) : Appearance.mix(root.leftColor,
                                                                                              root.leftForeground,
                                                                                              0.88)
                buttonPressedColor: root.glassSurface ? Qt.rgba(1, 1, 1, 0.30) : Appearance.mix(root.leftColor,
                                                                                                root.leftForeground,
                                                                                                0.76)
                buttonTextColor: root.leftForeground
                Accessible.name: qsTr("Select network interface")
                onValueSelected: value => {
                                     return root.interfaceSelected(value);
                                 }
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "download"
                value: Format.bytesPerSecond(root.selectedInterface.downloadBytesPerSecond)
                accentColor: root.downloadIconColor
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "upload"
                value: Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)
                accentColor: root.uploadIconColor
            }
        }
    }

    layer.effect: OpacityMask {

        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: Appearance.rounding.veryLarge
        }
    }

    component NetworkRate: Item {
        id: rate

        required property string iconName
        required property string value
        required property color accentColor

        MaterialSymbol {
            id: rateIcon

            text: rate.iconName
            iconSize: root.glassSurface ? 24 : 27
            fill: 1
            color: rate.accentColor

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: rate.value
            color: root.rightForeground
            renderType: Text.NativeRendering
            font.family: root.glassSurface ? Fonts.ui : Fonts.expressive
            font.pixelSize: root.glassSurface ? 30 : 27
            font.weight: root.glassSurface ? Font.Bold : Font.Black
            font.variableAxes: root.glassSurface ? ({}) : root.expressiveBoldAxes
            elide: Text.ElideRight

            anchors {
                left: rateIcon.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Appearance.spacing.small
            }
        }
    }
}
