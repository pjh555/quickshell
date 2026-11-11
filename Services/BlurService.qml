pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool runningOnNiri: ThemeService.isNiriSession
    property bool compositorSupported: false
    readonly property bool available: root.runningOnNiri && root.compositorSupported
    readonly property bool enabled: root.available && PersonalizationConfig.shellBlurEnabled
    readonly property bool xray: PersonalizationConfig.shellBlurXray
    readonly property bool integrationBusy: NiriConfigService.busy && NiriConfigService.activeFeature
                                            === "effects"

    readonly property bool niriIntegrationReady: NiriConfigService.ready("effects")
    property string versionErrorText: ""
    readonly property string lastError: versionErrorText || NiriConfigService.error
    property string niriVersion: ""

    signal integrationConfigured
    signal integrationFailed(string message)

    function backgroundColor(baseColor) {
        const material = Appearance.mix(baseColor, Appearance.macos.surfaceElevated, 0.18);
        return Appearance.applyAlpha(material, PersonalizationConfig.shellBackgroundOpacity);
    }

    // A shell-managed Material surface. It starts from an opaque base but
    // intentionally follows the shell's configurable glass opacity.
    function opaqueBackgroundColor(baseColor) {
        return backgroundColor(Appearance.applyAlpha(baseColor, 1));
    }

    // A material surface that must remain opaque independently from the
    // shell's configurable glass opacity.
    function solidBackgroundColor(baseColor) {
        return Appearance.applyAlpha(baseColor, 1);
    }

    function supportsVersion(versionText) {
        const match = String(versionText || "").match(/(?:^|\s)(\d+)\.(\d+)(?:\D|$)/);
        if (!match)
            return false;
        const major = Number(match[1]);
        const minor = Number(match[2]);
        return major > 26 || (major === 26 && minor >= 4);
    }

    function refreshIntegrationState() {
        NiriConfigService.refresh();
    }
    function writeEffectsConfig() {
        if (root.available)
            NiriConfigService.update("effects");
    }
    function configureNiriIntegration() {
        NiriConfigService.setup("effects");
    }

    function ensureIntegration() {
        if (!root.available || !PersonalizationConfig.shellBlurEnabled || root.integrationBusy)
            return;
        if (root.niriIntegrationReady)
            NiriConfigService.update("effects");
        else
            root.configureNiriIntegration();
    }

    Connections {
        target: PersonalizationConfig

        function onShellBlurXrayChanged() {
            root.writeEffectsConfig();
        }

        function onShellBlurEnabledChanged() {
            root.writeEffectsConfig();
            root.ensureIntegration();
        }
    }

    onAvailableChanged: Qt.callLater(root.ensureIntegration)
    onNiriIntegrationReadyChanged: Qt.callLater(root.ensureIntegration)

    Process {
        id: versionProcess

        command: ["niri", "--version"]
        running: root.runningOnNiri

        stdout: StdioCollector {
            id: versionOutput
        }

        stderr: StdioCollector {
            id: versionError
        }

        onExited: exitCode => {
            root.niriVersion = versionOutput.text.trim();
            root.compositorSupported = exitCode === 0 && root.supportsVersion(root.niriVersion);
            if (!root.compositorSupported) {
                root.versionErrorText = exitCode === 0 ? qsTr(
                                                             "The current Niri version does not support background blur") :
                                                         (versionError.text.trim() || qsTr(
                                                              "Unable to detect the Niri version"));
                return;
            }

            root.versionErrorText = "";
            root.refreshIntegrationState();
        }
    }
}
