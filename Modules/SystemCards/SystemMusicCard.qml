import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool glassSurface: true
    property color foregroundColor: "#FFFFFF"
    property color secondaryForegroundColor: Qt.rgba(1, 1, 1, 0.78)
    property color accentColor: "#FFFFFF"
    readonly property var player: MediaManager.active
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && root.player.isPlaying
    readonly property string artUrl: root.hasPlayer ? (root.player.trackArtUrl || root.player.artUrl || "") :
                                                      ""

    readonly property bool hasArt: root.artUrl.length > 0
    // SystemCardContent paints this as a full-bleed album-art background.
    readonly property string shellBackgroundSourceA: root.artUrl

    readonly property string trackTitle: root.hasPlayer && root.player.trackTitle ? root.player.trackTitle : qsTr(
                                                                                        "Nothing playing")
    readonly property string trackArtist: root.hasPlayer && root.player.trackArtist ? root.player.trackArtist :
                                                                                      qsTr("No active player")

    function togglePlayback() {
        if (root.hasPlayer)
            root.player.togglePlaying();
    }

    function previousTrack() {
        if (root.hasPlayer)
            root.player.previous();
    }

    function nextTrack() {
        if (root.hasPlayer)
            root.player.next();
    }

    Accessible.name: qsTr("Now Playing") + "，" + root.trackTitle + "，" + root.trackArtist

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Appearance.rounding.small
                color: Qt.rgba(1, 1, 1, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 18
                    color: root.accentColor
                    fill: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Now Playing")
                color: root.foregroundColor
                font.family: Fonts.ui
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                visible: root.hasPlayer
                text: root.playing ? qsTr("Playing") : qsTr("Paused")
                color: root.secondaryForegroundColor
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: Appearance.rounding.normal
            color: Qt.rgba(1, 1, 1, 0.16)
            visible: !root.hasArt

            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 30
                color: root.accentColor
                fill: 1
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.trackTitle
            color: root.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: 20
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: root.trackArtist
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.medium

            IconButton {
                iconName: "skip_previous"
                accessibleName: qsTr("Previous track")
                controlSize: 38
                iconSize: 24
                enabled: root.hasPlayer
                iconColor: root.foregroundColor
                normalContainerColor: "transparent"
                selectedContainerColor: "transparent"
                normalHoverStateLayerColor: Qt.rgba(1, 1, 1, 0.14)
                normalPressedStateLayerColor: Qt.rgba(1, 1, 1, 0.20)
                onClicked: root.previousTrack()
            }

            IconButton {
                iconName: root.playing ? "pause" : "play_arrow"
                accessibleName: root.playing ? qsTr("Pause") : qsTr("Play")
                variant: "filled"
                controlSize: 46
                iconSize: 26
                enabled: root.hasPlayer
                iconColor: root.foregroundColor
                normalContainerColor: Qt.rgba(1, 1, 1, 0.24)
                selectedContainerColor: Qt.rgba(1, 1, 1, 0.24)
                normalHoverStateLayerColor: Qt.rgba(1, 1, 1, 0.34)
                normalPressedStateLayerColor: Qt.rgba(1, 1, 1, 0.42)
                onClicked: root.togglePlayback()
            }

            IconButton {
                iconName: "skip_next"
                accessibleName: qsTr("Next track")
                controlSize: 38
                iconSize: 24
                enabled: root.hasPlayer
                iconColor: root.foregroundColor
                normalContainerColor: "transparent"
                selectedContainerColor: "transparent"
                normalHoverStateLayerColor: Qt.rgba(1, 1, 1, 0.14)
                normalPressedStateLayerColor: Qt.rgba(1, 1, 1, 0.20)
                onClicked: root.nextTrack()
            }
        }
    }
}
