pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Files
import qs.Common
import qs.Services

Singleton {
    id: root

    property var applications: []
    property var flatpakApplications: ({})
    property bool packageIndexReady: false
    property string uninstallingId: ""
    property string uninstallingKind: ""
    property string uninstallError: ""

    signal uninstallFinished(string applicationId, bool succeeded, string message)
    readonly property string settingsIconName: {
        // Re-evaluate availability after Qt has applied the selected theme.
        const revision = ThemeService.iconThemeRevision;
        for (const name of ["preferences-system", "preferences-desktop"]) {
            if (Quickshell.hasThemeIcon(name))
            return name;
        }
        return "";
    }
    readonly property var settingsApplication: ({
                                                    id: "org.clavis.Settings",
                                                    name: qsTranslate("ControlCenterWindow", "Settings"),
                                                    genericName: "Clavis",
                                                    keywords: ["Clavis", "settings", "preferences",
                                                        "control center"],
                                                    symbol: root.settingsIconName ? "" : "settings",
                                                    icon: root.settingsIconName
                                                })
    readonly property var spaceApplication: ({
                                                 id: "org.clavis.Space",
                                                 name: qsTr("Space"),
                                                 genericName: qsTr("Drag to Dock to add a blank space"),
                                                 keywords: ["space", "spacer", "blank", "dock"],
                                                 symbol: "check_box_outline_blank",
                                                 icon: "",
                                                 dragOnly: true
                                             })
    readonly property var smallSpaceApplication: ({
                                                      id: "org.clavis.SmallSpace",
                                                      name: qsTr("Small Space"),
                                                      genericName: qsTr("Drag to Dock to add a blank space"),
                                                      keywords: ["space", "spacer", "blank", "dock", "small",
                                                          "narrow"],
                                                      symbol: "check_box_outline_blank",
                                                      icon: "",
                                                      dragOnly: true
                                                  })
    // Internal shell entries belong in the launcher, not in default-app or
    // autostart pickers that require an installed desktop application.
    readonly property var launcherApplications: applications.concat([settingsApplication, spaceApplication,
                                                                     smallSpaceApplication])

    function launchCommand(command, workingDirectory) {
        const argv = Array.from(command || []);
        if (argv.length === 0 || !String(argv[0]).trim())
            return false;

        // Enter the scope before executing the app, so even its earliest
        // children cannot inherit clavis-shell.service's control group.
        // Scope mode preserves the caller's environment and working directory.
        const scopedCommand = ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--slice=app.slice",
                               "--expand-environment=no"];
        if (workingDirectory)
            scopedCommand.push("--working-directory=" + String(workingDirectory));
        // A software-rendered shell (for example a nested Sway session on an
        // ARM64 device) must also let GTK/Qt applications find a usable
        // renderer. Otherwise they exit before mapping a window even though
        // the shell itself is still visible.
        if (PlatformService.softwareRendering) {
            scopedCommand.push("--setenv=LIBGL_ALWAYS_SOFTWARE=1");
            scopedCommand.push("--setenv=GSK_RENDERER=cairo");
            scopedCommand.push("--setenv=QT_QUICK_BACKEND=software");
        }
        Quickshell.execDetached(scopedCommand.concat(["--"], argv));
        return true;
    }

    function launchApplication(application) {
        if (!application || application.dragOnly)
            return false;
        if (application.id === root.settingsApplication.id)
            return ControlCenterService.openOrFocus();
        return root.launchApplicationCommand(application, application.command);
    }

    function actionsForApplication(identifier) {
        const application = root.findById(identifier);
        // Preserve the native list's order, labels and DesktopAction objects.
        const actions = Array.from(application ? application.actions || [] : []);
        return actions.filter(action => {
                                  if (!action || !String(action.id || "").trim() || !String(action.name || "").trim(
                                          ))
                                  return false;
                                  const command = Array.from(action.command || []);
                                  return command.length > 0 && String(command[0]).trim() !== "";
                              });
    }

    function launchApplicationAction(identifier, actionId) {
        const application = root.findById(identifier);
        if (!application || application.dragOnly)
            return false;
        // Resolve again on activation: an open menu may outlive an entry refresh.
        const action = root.actionsForApplication(identifier).find(candidate => candidate.id === actionId);
        return !!action && root.launchApplicationCommand(application, action.command);
    }

    function launchApplicationCommand(application, argumentsList) {
        const command = Array.from(argumentsList || []);
        if (command.length === 0 || !String(command[0]).trim())
            return false;
        if (application.runInTerminal) {
            const terminal = ["xdg-terminal-exec"];
            if (application.workingDirectory)
                terminal.push("--dir=" + String(application.workingDirectory));
            // Optional terminal support: let Dock match a TUI's window to its
            // desktop entry without guessing from the window title.
            const appId = String(application.startupClass || application.id || "").replace(/\.desktop$/, "");
            if (appId)
                terminal.push("--app-id=" + appId);
            return root.launchCommand(terminal.concat(["--"], command), application.workingDirectory);
        }
        return root.launchCommand(command, application.workingDirectory);
    }

    function normalizedApplicationId(value) {
        const id = String(value || "").trim();
        return id.endsWith(".desktop") ? id.substring(0, id.length - ".desktop".length) : id;
    }

    function appImagePath(application) {
        if (!application || !application.command || Array.from(application.command).length === 0)
            return "";
        const command = String(Array.from(application.command)[0] || "").trim();
        const home = String(Paths.homeDir || "").replace(/\/$/, "");
        if (home === "" || !command.startsWith(home + "/") || !/\.appimage$/i.test(command))
            return "";
        if (command.indexOf("..") >= 0 || command.indexOf("\u0000") >= 0)
            return "";
        return command;
    }

    // There is no portable uninstall API for native Linux packages. Only
    // advertise deletion when the source can be identified unambiguously.
    function removalKind(application) {
        if (!application || application.dragOnly)
            return "none";
        const id = root.normalizedApplicationId(application.id);
        if (id !== "" && root.flatpakApplications[id] === true)
            return "flatpak";
        if (root.appImagePath(application) !== "")
            return "appimage";
        return "none";
    }

    function canUninstall(application) {
        return root.removalKind(application) !== "none";
    }

    function userDesktopEntryFor(application) {
        const id = root.normalizedApplicationId(application ? application.id : "");
        if (id === "")
            return "";
        const url = Paths.fileUrl(Paths.xdgDataHome + "/applications/" + id + ".desktop");
        const info = DesktopFiles.info(url);
        return info && info.available ? url : "";
    }

    function finishUninstall(succeeded, message) {
        const id = root.uninstallingId;
        root.uninstallingId = "";
        root.uninstallingKind = "";
        root.uninstallError = succeeded ? "" : (message || qsTr("The application could not be uninstalled."));
        root.uninstallFinished(id, succeeded, root.uninstallError);
    }

    function uninstallApplication(application) {
        const kind = root.removalKind(application);
        const id = root.normalizedApplicationId(application ? application.id : "");
        if (id === "" || kind === "none" || root.uninstallingId !== "" || uninstallProcess.running)
            return false;

        root.uninstallError = "";
        root.uninstallingId = String(application.id);
        root.uninstallingKind = kind;
        if (kind === "appimage") {
            const urls = [Paths.fileUrl(root.appImagePath(application))];
            const desktopEntry = root.userDesktopEntryFor(application);
            if (desktopEntry !== "")
                urls.push(desktopEntry);
            const started = DesktopFiles.moveToTrash(urls);
            if (!started) {
                root.uninstallError = qsTr("Could not move the AppImage to the Trash.");
                root.uninstallingId = "";
                root.uninstallingKind = "";
                root.uninstallFinished(String(application.id), false, root.uninstallError);
            }
            return started;
        }

        uninstallProcess.command = ["flatpak", "uninstall", "-y", "--app", id];
        uninstallProcess.running = true;
        return true;
    }

    function refreshPackageIndex() {
        if (flatpakListProcess.running)
            return;
        root.packageIndexReady = false;
        flatpakListProcess.running = true;
    }

    function openUrl(url) {
        const value = String(url || "");
        if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value))
            return false;
        if (/^file:/i.test(value)) {
            const desktopFile = DesktopFiles.defaultApplicationForFile(value);
            // Launch the MIME handler explicitly: gio open may instead select
            // x-scheme-handler/file. GIO still honors Terminal=true for TUI apps.
            return !!desktopFile && root.launchCommand(["gio", "launch", desktopFile, value]);
        }
        return root.launchCommand(/^trash:/i.test(value) ? ["gio", "open", value] : ["xdg-open", value]);
    }

    function isVisibleApplication(application) {
        if (!application)
            return false;
        if (application.noDisplay === true || application.hidden === true)
            return false;
        return String(application.id || "").trim() !== "" && String(application.execString || application.exec
                                                                    || "").trim() !== "";
    }

    function refresh() {
        const source = DesktopEntries.applications.values || [];
        const seen = new Set();
        const next = [];
        for (const application of source) {
            if (!root.isVisibleApplication(application))
                continue;
            const id = String(application.id);
            if (seen.has(id))
                continue;
            seen.add(id);
            next.push(application);
        }
        next.sort((left, right) => {
                      const byName = String(left.name || left.id).localeCompare(String(right.name
                                                                                       || right.id));
                      return byName !== 0 ? byName : String(left.id).localeCompare(String(right.id));
                  });
        root.applications = next;
    }

    function getVisibleApplications() {
        return root.applications.slice();
    }

    function findById(identifier) {
        const value = String(identifier || "");
        if (value === root.smallSpaceApplication.id)
            return root.smallSpaceApplication;
        if (value === root.spaceApplication.id)
            return root.spaceApplication;
        if (value === root.settingsApplication.id)
            return root.settingsApplication;
        const withoutSuffix = value.endsWith(".desktop") ? value.substring(0, value.length
                                                                           - ".desktop".length) : value;
        for (const application of root.applications) {
            const id = String(application.id || "");
            if (id === value || id === withoutSuffix || id === withoutSuffix + ".desktop") {
                return application;
            }
        }
        return null;
    }

    function iconSource(iconName) {
        const revision = ThemeService.iconThemeRevision;
        const value = String(iconName || "");
        if (value.startsWith("file://") || value.startsWith("image://"))
            return value;
        if (value.startsWith("/"))
            return "file://" + value;
        if (value === "" || !Quickshell.hasThemeIcon(value))
            return Paths.appIcon("application-x-executable.svg");
        const resolved = Quickshell.iconPath(value, "");
        return resolved && resolved !== "" ? resolved : Paths.appIcon("application-x-executable.svg");
    }

    function iconSourceForEntry(entry) {
        if (!entry)
            return root.iconSource("");
        const application = root.findById(entry.id);
        if (application && application.icon)
            return root.iconSource(application.icon);
        if (entry.icon)
            return root.iconSource(entry.icon);

        const command = String(entry.exec || "").trim().split(/\s+/)[0];
        const commandName = command.substring(command.lastIndexOf("/") + 1);
        if (commandName) {
            for (const candidate of root.applications) {
                const candidateCommand = String(candidate.execString || candidate.exec || "").trim().split(
                          /\s+/)[0];
                if (candidateCommand.substring(candidateCommand.lastIndexOf("/") + 1) === commandName) {
                    return root.iconSource(candidate.icon);
                }
            }
        }
        return root.iconSource("");
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.refresh();
            root.refreshPackageIndex();
        }
    }

    Process {
        id: flatpakListProcess

        command: ["flatpak", "list", "--app", "--columns=application"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.create(null);
                for (const line of String(text || "").split(/\r?\n/)) {
                    const id = root.normalizedApplicationId(line);
                    if (id !== "")
                    next[id] = true;
                }
                root.flatpakApplications = next;
            }
        }

        onExited: root.packageIndexReady = true
    }

    Process {
        id: uninstallProcess

        command: []
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.uninstallError = String(text || "").trim()
        }

        onExited: exitCode => {
            const succeeded = exitCode === 0;
            const error = root.uninstallError;
            if (succeeded)
            root.refreshPackageIndex();
            root.finishUninstall(succeeded, error);
        }
    }

    Connections {
        target: DesktopFiles

        function onFinished(action, succeeded, errors) {
            if (action !== "trash" || root.uninstallingKind !== "appimage" || root.uninstallingId === "")
                return;
            const messages = Array.from(errors || []);
            root.finishUninstall(succeeded > 0 && messages.length === 0, messages.join("\n"));
        }
    }

    Component.onCompleted: {
        root.refresh();
        root.refreshPackageIndex();
    }
}
