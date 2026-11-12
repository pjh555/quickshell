import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import M3Shapes
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    property bool glassSurface: false
    property color foregroundColor: Appearance.colors.colOnSurface
    property color secondaryForegroundColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.78)
    property color accentColor: Appearance.colors.colPrimary
    readonly property bool dataAvailable: WeatherPlugin.hasValidData
    readonly property string temperature: root.dataAvailable && isFinite(Number(
                                                                             WeatherPlugin.currentTemperatureC))
                                          ? Math.round(UiPreferences.weatherTemperature(
                                                           WeatherPlugin.currentTemperatureC)) + "°" : "--°"
    readonly property string weatherIcon: root.dataAvailable && String(WeatherPlugin.currentIconName
                                                                       || "").length > 0
                                          ? WeatherPlugin.currentIconName : "cloud"

    implicitWidth: backgroundShape.implicitWidth
    implicitHeight: backgroundShape.implicitHeight
    Accessible.name: qsTr("Weather,") + root.temperature + "，" + (root.dataAvailable
                                                                  ? WeatherPlugin.currentWeatherText : qsTr(
                                                                        "Weather unavailable"))

    MaterialShape {
        id: backgroundShape

        visible: !root.glassSurface
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        shape: MaterialShape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: 200
        layer.enabled: true

        Text {
            text: root.temperature
            color: Appearance.colors.colPrimary
            renderType: Text.NativeRendering

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 16
            }

            font {
                family: Fonts.expressive
                pixelSize: 80
                weight: Font.Medium
            }
        }

        MaterialSymbol {
            text: root.weatherIcon
            iconSize: 80
            color: Appearance.colors.colOnPrimaryContainer

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 16
                bottomMargin: 20
            }
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.colors.colShadow
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    ColumnLayout {
        visible: root.glassSurface
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Appearance.rounding.small
                color: Qt.rgba(1, 1, 1, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "cloud"
                    iconSize: 18
                    color: root.accentColor
                    fill: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Weather")
                color: root.foregroundColor
                font.family: Fonts.ui
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: Appearance.rounding.large
            color: Qt.rgba(1, 1, 1, 0.16)

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.weatherIcon
                iconSize: 40
                color: root.accentColor
                fill: 1
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.temperature
            color: root.foregroundColor
            renderType: Text.NativeRendering
            font {
                family: Fonts.ui
                pixelSize: 36
                weight: Font.Bold
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.dataAvailable ? WeatherPlugin.currentWeatherText : qsTr("Weather unavailable")
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }
}
