pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property string _desktopDir: Paths.homeDir + "/Desktop"
    property string _picturesDir: Paths.homeDir + "/Pictures"

    readonly property string desktopDir: root._desktopDir
    readonly property string picturesDir: root._picturesDir

    function acceptedPath(value) {
        const path = String(value || "").trim().replace(/\/+$/, "");
        const home = String(Paths.homeDir || "").replace(/\/+$/, "");
        // A disabled desktop directory resolves to $HOME; keep the fallback
        // instead of treating the whole home directory as the desktop.
        if (!path.startsWith("/") || path === home)
            return "";
        return path;
    }

    Process {
        id: desktopDirProcess

        command: ["xdg-user-dir", "DESKTOP"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const path = root.acceptedPath(text);
                if (path !== "")
                root._desktopDir = path;
            }
        }
    }

    Process {
        id: picturesDirProcess

        command: ["xdg-user-dir", "PICTURES"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const path = root.acceptedPath(text);
                if (path !== "")
                root._picturesDir = path;
            }
        }
    }
}
