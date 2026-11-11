import QtQuick
import Quickshell
import qs.Modules.Launchpad
import qs.Services

Item {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: windowLoader

            required property var modelData

            active: true
            sourceComponent: PlatformService.layerShellAvailable ? layerWindow : floatingWindow

            onLoaded: {
                if (item)
                    item.targetScreen = windowLoader.modelData;
            }
        }
    }

    Component {
        id: layerWindow

        LaunchpadPanelWindow {}
    }

    Component {
        id: floatingWindow

        LaunchpadFloatingWindow {}
    }
}
