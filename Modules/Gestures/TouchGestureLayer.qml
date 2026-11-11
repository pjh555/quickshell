import QtQuick
import Quickshell
import qs.Modules.Gestures
import qs.Services

Item {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: gestureLoader

            required property var modelData

            active: PlatformService.layerShellAvailable && PlatformService.touchGesturesEnabled
            sourceComponent: gestureWindow

            onLoaded: {
                if (item)
                    item.targetScreen = gestureLoader.modelData;
            }
        }
    }

    Component {
        id: gestureWindow

        TouchGestureWindow {}
    }
}
