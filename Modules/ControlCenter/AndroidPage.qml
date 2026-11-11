pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Components

Item {
    id: root

    property var parentModal: null
    property bool presentationActive: false
    property bool launchRequested: false
    property int launchAttempts: 0
    property bool settleLaunched: false
    property string statusText: qsTr("Connecting to Android Settings…")

    readonly property string ctl: Quickshell.env("DROIDLOOM_CTL") || "/usr/bin/droidloomctl"

    function launchSettings() {
        if (launchProcess.running || launchAttempts >= 20)
            return;
        launchAttempts += 1;
        statusText = qsTr("Starting Android Settings…");
        launchProcess.running = true;
    }

    function retrySession() {
        launchRequested = false;
        launchAttempts = 0;
        settleLaunched = false;
        statusText = qsTr("Reconnecting to Android Settings…");
        embedded.active = false;
        embedded.active = true;
    }

    onPresentationActiveChanged: {
        if (!presentationActive) {
            launchRequested = false;
            launchAttempts = 0;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.normal
        clip: true

        AndroidEmbeddedSurface {
            id: embedded
            anchors.fill: parent
            anchors.margins: 1
            // Keep the consumer alive for the lifetime of this page. The page
            // host destroys it when the route is retired; reacting to
            // presentation fades would tear down the Android task.
            active: true

            onSettingsReady: {
                if (!root.launchRequested) {
                    root.launchAttempts = 0;
                    root.launchRequested = true;
                    launchTimer.restart();
                }
            }

            onProcessExited: code => {
                if (code === 0 || launchProcess.running)
                return;
                root.launchRequested = false;
                root.launchAttempts = 0;
                root.settleLaunched = false;
                root.statusText = qsTr("Reconnecting to Android Settings…");
                if (root.presentationActive)
                launchRetryTimer.restart();
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: embedded.surfaceCount === 0
            color: Appearance.colors.colLayer0

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 420)
                spacing: Metrics.spacingM

                Text {
                    Layout.fillWidth: true
                    text: root.statusText
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr(
                              "The Android task is rendered inside this page through the Droidloom embedded surface protocol.")
                    color: Appearance.colors.colOnLayer1Inactive
                    font.pixelSize: Typography.bodySmall.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: retryLabel.implicitWidth + 32
                    height: 40
                    radius: 20
                    color: retryArea.containsMouse ? Appearance.colors.colPrimaryHover :
                                                     Appearance.colors.colPrimary

                    Text {
                        id: retryLabel
                        anchors.centerIn: parent
                        text: qsTr("Retry")
                        color: Appearance.colors.colOnPrimary
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }

                    MouseArea {
                        id: retryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.retrySession()
                    }
                }
            }
        }
    }

    Timer {
        id: initialLaunchTimer
        interval: 1200
        repeat: false
        running: true
        onTriggered: root.launchSettings()
    }

    Timer {
        id: launchTimer
        interval: 300
        repeat: false
        onTriggered: root.launchSettings()
    }

    Timer {
        id: settleTimer
        interval: 1500
        repeat: false
        onTriggered: root.launchSettings()
    }

    Timer {
        id: launchRetryTimer
        interval: 1500
        repeat: false
        onTriggered: root.launchSettings()
    }

    Process {
        id: launchProcess
        command: [root.ctl, "launch", "com.android.settings"]
        running: false
        onExited: code => {
            if (code === 0) {
                if (!root.settleLaunched && root.presentationActive) {
                    root.settleLaunched = true;
                    settleTimer.restart();
                }
                return;
            }
            root.statusText = qsTr("Waiting for the Android runtime…");
            if (root.presentationActive && root.launchAttempts < 20)
            launchRetryTimer.restart();
        }
    }
}
