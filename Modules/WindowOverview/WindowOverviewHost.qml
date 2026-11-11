import QtQuick
import Quickshell
import qs.Modules.WindowOverview
import qs.Services

Item {
    id: root

    Variants {
        model: WindowManagerService.available ? Quickshell.screens : []

        delegate: Loader {
            id: overviewLoader

            required property var modelData

            active: true
            sourceComponent: WindowOverview {}

            onLoaded: {
                if (item)
                    item.targetScreen = overviewLoader.modelData;
            }
        }
    }
}
