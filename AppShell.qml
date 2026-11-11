import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri
import qs.Modules.Bar
import qs.Modules.Agent
import qs.Modules.ControlCenter
import qs.Modules.DesktopCards
import qs.Modules.Dock
import qs.Modules.Gestures
import qs.Modules.HotCorners
import qs.Modules.FilePicker
import qs.Modules.Keystone
import qs.Modules.Launcher
import qs.Modules.Launchpad
import qs.Modules.Lock
import qs.Modules.PowerMenu
import qs.Modules.RegionSelector
import qs.Modules.StageManager
import qs.Modules.TouchKeyboard
import qs.Modules.Sidebars
import qs.Modules.Wallpaper
import qs.Modules.WindowOverview
import qs.Common
import qs.Services

Item {
    id: root

    property string pendingSecurePowerAction: ""

    // The catalog only supplies fixed, build-validated calls. Both IPC and
    // Search use the same existing business functions, without self-IPC.
    function executeSearchAction(action) {
        switch (action.target) {
        case "lock":
            const status = sessionLocker.open();
            return status === "LOCKED" || status === "ALREADY_LOCKED";
        case "wallpaper":
            switch (action.method) {
            case "clear":
                return WallpaperService.clearWallpaper("");
            case "previous":
                return WallpaperService.cyclePrevious() || WallpaperService.pendingCycleAction === "previous";
            case "next":
                return WallpaperService.cycleNext() || WallpaperService.pendingCycleAction === "next";
            case "random":
                return WallpaperService.cycleRandom() || WallpaperService.pendingCycleAction === "random";
            }
            return false;
        case "keystone":
        {
            const component = keystoneLoader.item;
            if (!component)
                return false;
            switch (action.method) {
            case "closeAllOthers":
            case "dashboard":
            case "hub":
            case "lyrics":
            case "tools":
                return component.invoke(action.method) !== "KEYSTONE_UNAVAILABLE";
            }
            return false;
        }
        case "sidebar":
            const sidebar = sidebarHostLoader.item;
            if (!sidebar)
                return false;
            return (action.method === "toggle" ? sidebar.toggleSidebar(action.args[0]) : sidebar.setSidebarOpen(
                                                     action.args[0], true)) !== "INVALID_SIDE";
        case "launchpad":
            if (action.method === "toggle") {
                LaunchpadService.toggle("");
                return true;
            }
            return false;
        case "stage-manager":
            if (action.method === "toggle") {
                StageManagerService.toggle();
                return true;
            }
            return false;
        case "touch-keyboard":
            if (action.method === "toggle") {
                TouchKeyboardService.toggle();
                return true;
            }
            return false;
        case "shortcut-map":
            ShortcutMapService.open();
            return true;
        case "power-menu":
            return PowerMenuService.open();
        default:
            return false;
        }
    }

    function performGestureAction(action, screenName) {
        const target = String(action || "").toLowerCase();
        const screen = String(screenName || "");
        switch (target) {
        case "home":
            LaunchpadService.toggle(screen);
            return true;
        case "overview":
            if (WindowManagerService.available) {
                WidgetState.closeAllPopups();
                return WindowManagerService.toggle(screen);
            }
            if (!PlatformService.isNiri)
                return false;
            WidgetState.closeAllPopups();
            return Niri.toggleOverview();
        case "quick-settings":
        case "notifications":
        {
            const sidebar = sidebarHostLoader.item;
            if (!sidebar)
                return false;
            if (screen === "")
                return sidebar.toggleSidebar(target === "quick-settings" ? "quicksettings" : "dashboard")
                        !== "INVALID_SIDE";
            const result = target === "quick-settings" ? sidebar.openOnScreen("quicksettings", "settings",
                                                                              screen) : sidebar.openOnScreen(
                                                             "dashboard", "info", screen);
            return result !== "INVALID_VIEW" && result !== "SCREEN_UNAVAILABLE";
        }
        case "app-previous":
            return PlatformService.isNiri && Niri.focusColumnLeft();
        case "app-next":
            return PlatformService.isNiri && Niri.focusColumnRight();
        case "workspace-previous":
            return PlatformService.isNiri && Niri.focusWorkspaceUp();
        case "workspace-next":
            return PlatformService.isNiri && Niri.focusWorkspaceDown();
        case "stage-manager":
            return StageManagerService.toggle();
        case "touch-keyboard":
            TouchKeyboardService.toggle();
            return true;
        default:
            return false;
        }
    }

    function runSecurePowerAction() {
        if (pendingSecurePowerAction === "" || !sessionLocker.secure)
            return;

        const action = pendingSecurePowerAction;
        pendingSecurePowerAction = "";
        Quickshell.execDetached(["systemctl", action]);
    }

    function requestSecurePowerAction(action) {
        if (pendingSecurePowerAction !== "")
            return;

        const result = sessionLocker.open();
        if (result !== "LOCKED" && result !== "ALREADY_LOCKED")
            return;

        pendingSecurePowerAction = action;
        runSecurePowerAction();
    }

    Component.onCompleted: {
        SpotlightCatalog.actionExecutor = root.executeSearchAction;
        SpotlightCatalog.keystoneAvailable = Qt.binding(() => keystoneLoader.item
                                                        ? keystoneLoader.item.searchActionsAvailable : false);
        I18nService.initialize();
        DisplayColor.evaluate();
        LyricsTrackService.initialize();
        SystemIdentityService.initialize();
        // Niri and Sway have no XDG autostart phase of their own. Prefer the
        // native fcitx5 Wayland input method. It uses zwp_input_method_v2, so
        // terminals such as Alacritty get Chinese input instead of raw Latin
        // text. If fcitx5 is unavailable, keep the IBus Wayland bridge as a
        // fallback. GNOME continues to own its IBus unit.
        if (PlatformService.isNiri || PlatformService.isSway) {
            Quickshell.execDetached(["sh", "-c", "if command -v fcitx5 >/dev/null 2>&1 || "
                                     + "[ -x \"$HOME/.local/bin/clavis-fcitx5\" ]; then "
                                     + "pkill -x ibus-wayland >/dev/null 2>&1 || true; "
                                     + "pkill -x ibus-daemon >/dev/null 2>&1 || true; "
                                     + "if ! pgrep -x fcitx5 >/dev/null 2>&1; then "
                                     + "if command -v fcitx5 >/dev/null 2>&1; then "
                                     + "setsid fcitx5 -D --replace --disable xim >/dev/null 2>&1 & "
                                     + "else setsid \"$HOME/.local/bin/clavis-fcitx5\" >/dev/null 2>&1 & fi; "
                                     + "sleep 3; fi; " + "if command -v fcitx5-remote >/dev/null 2>&1; then "
                                     + "fcitx5-remote -s pinyin >/dev/null 2>&1 || true; "
                                     + "elif [ -x \"$HOME/.local/share/clavis-fcitx5/root/usr/bin/fcitx5-remote\" ]; then "
                                     + "LD_LIBRARY_PATH=\"$HOME/.local/share/clavis-fcitx5/root/usr/lib/aarch64-linux-gnu\" "
                                     + "\"$HOME/.local/share/clavis-fcitx5/root/usr/bin/fcitx5-remote\" -s pinyin "
                                     + ">/dev/null 2>&1 || true; fi; " + "else "
                                     + "pgrep -x ibus-daemon >/dev/null 2>&1 || ibus-daemon -drx; "
                                     + "sleep 1; ibus engine libpinyin >/dev/null 2>&1 || true; "
                                     + "if ! pgrep -x ibus-wayland >/dev/null 2>&1; then "
                                     + "if command -v ibus-wayland >/dev/null 2>&1; then "
                                     + "setsid ibus-wayland >/dev/null 2>&1 & "
                                     + "elif [ -x /usr/libexec/ibus-wayland ]; then "
                                     + "setsid /usr/libexec/ibus-wayland >/dev/null 2>&1 & fi; "
                                     + "sleep 1; fi; fi"]);
        }
    }

    DisplayOverlays {}

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: WallpaperBackground {}
    }

    // Desktop cards are an independent bottom-layer subsystem.  It remains
    // loaded when the awww backend hides Clavis' wallpaper renderer.
    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: DesktopCardHost {}
    }

    LazyLoader {
        id: controlCenterLoader

        active: false
        Component.onCompleted: ControlCenterService.registerLoader(controlCenterLoader)
        onItemChanged: {
            if (item)
                ControlCenterService.registerWindow(item);
        }

        ControlCenterWindow {
            id: controlCenterWindow

            onPopoutClosed: ControlCenterService.windowClosed(controlCenterWindow)
        }
    }

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: Bar {}
    }

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: DockHost {}
    }

    Loader {
        id: keystoneLoader

        active: PlatformService.layerShellAvailable
        sourceComponent: Keystone {}
    }

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: RegionSelector {}
    }

    Loader {
        id: sidebarHostLoader

        active: PlatformService.layerShellAvailable
        sourceComponent: SidebarHostWindow {}
    }

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: HotCorners {
            locked: sessionLocker.active
            onTriggered: (action, screenName) => {
                             if (action === "overview") {
                                 WidgetState.closeAllPopups();
                                 if (WindowManagerService.available)
                                 WindowManagerService.toggle(screenName);
                                 else if (PlatformService.isNiri)
                                 Niri.toggleOverview();
                                 return;
                             }
                             const target = action.split(":");
                             const sidebar = sidebarHostLoader.item;
                             if (target.length === 2 && sidebar) {
                                 if (WindowManagerService.visible)
                                 WindowManagerService.close();
                                 else if (Niri.inOverview)
                                 Niri.toggleOverview();
                                 sidebar.openOnScreen(target[0], target[1], screenName);
                             }
                         }
        }
    }

    LaunchpadHost {}

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: AgentPanel {}
    }

    // 附件选择器：独立浮动窗口（可拖动、与控制面板同款玻璃材质）。
    // 常驻在 AppShell，避免对话面板关闭时被一并隐藏。
    FilePickerWindow {
        id: agentAttachmentPicker

        dialogTitle: qsTr("Add attachments")
        description: qsTr("Choose a file to attach to the conversation")
        selectionMode: FilePickerWindow.Files
        nameFilters: []
        windowIconName: "attach_file"
        emptyStateText: qsTr("This folder is empty")
        selectionPrompt: qsTr("Choose a file")
        acceptLabel: qsTr("Add")
        formatSummary: qsTr("Any file up to 20 MB")

        onAccepted: (path, isDirectory) => {
                        if (!isDirectory)
                        AgentService.addAttachmentPath(path);
                        AgentService.openPanel();
                    }
        onRejected: AgentService.openPanel()

        Connections {
            target: AgentService

            function onAttachmentPickRequested() {
                agentAttachmentPicker.openAt(Paths.homeDir);
            }
        }
    }

    Loader {
        active: PlatformService.layerShellAvailable && AgentService.petEnabled
        sourceComponent: AgentPet {}
    }

    Loader {
        active: PlatformService.layerShellAvailable
        sourceComponent: TouchKeyboardWindow {}
    }

    Loader {
        active: PlatformService.layerShellAvailable && WindowManagerService.available
        sourceComponent: WindowOverviewHost {}
    }

    Loader {
        active: PlatformService.layerShellAvailable && StageManagerService.available
        sourceComponent: StageManagerStrip {}
    }

    TouchGestureLayer {}

    Lock {
        id: sessionLocker
    }

    PowerMenu {}

    Connections {
        target: TouchGestureService

        function onActionRequested(action, screenName) {
            root.performGestureAction(action, screenName);
        }
    }

    Connections {
        function onActionRequested(action) {
            switch (action) {
            case "lock":
                sessionLocker.open();
                break;
            case "logout":
                PlatformService.requestLogout();
                break;
            case "suspend":
                root.requestSecurePowerAction("suspend");
                break;
            case "poweroff":
                Quickshell.execDetached(["systemctl", "poweroff"]);
                break;
            case "hibernate":
                root.requestSecurePowerAction("hibernate");
                break;
            case "reboot":
                Quickshell.execDetached(["systemctl", "reboot"]);
                break;
            }
        }

        target: PowerMenuService
    }

    Connections {
        function onSecured() {
            root.runSecurePowerAction();
        }

        function onActiveChanged() {
            if (sessionLocker.active)
                TouchKeyboardService.close();
            else
                root.pendingSecurePowerAction = "";
        }

        target: sessionLocker
    }

    Connections {
        function onLockRequested() {
            IdleService.reportLockResult(sessionLocker.open());
        }

        target: IdleService
    }

    Loader {
        active: ShortcutMapService.visible
        sourceComponent: ShortcutMap {
            targetScreen: ShortcutMapService.targetScreen
            onDismissed: ShortcutMapService.close()
        }
    }

    IpcHandler {
        target: "power-menu"
        function open(): void {
        PowerMenuService.open();
    }
        function close(): void {
                              PowerMenuService.close();
                          }
        function toggle(): void {
        PowerMenuService.toggle();
    }
    }

        IpcHandler {
            target: "shortcut-map"
            function open(): void {
            ShortcutMapService.open();
        }
            function close(): void {
                                  ShortcutMapService.close();
                              }
            function toggle(): void {
            ShortcutMapService.toggle();
        }
        }

            IpcHandler {
                function open() {
                    return sessionLocker.open();
                }

                function isLocked() {
                    return sessionLocker.isLocked();
                }

                target: "lock"
            }

            LauncherWindow {
                id: spotlightLauncher
            }

            IpcHandler {
                function toggle(): string {
                    spotlightLauncher.toggleWindow();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function open(): string {
                    spotlightLauncher.openSpotlight();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function search(): string {
                    spotlightLauncher.openSpotlight("search");
                    return "SEARCH";
                }

                function close(): string {
                    spotlightLauncher.requestClose();
                    return spotlightLauncher.windowPhase.toUpperCase();
                }

                function web(): string {
                    spotlightLauncher.openWebMode();
                    return "WEB";
                }

                function command(name: string): string {
                    return spotlightLauncher.runCommand(name);
                }

                function commands(): string {
                    return openMode("commands");
                }

                function files(): string {
                    return openMode("files");
                }

                function openMode(mode: string): string {
                    if (spotlightLauncher.normalizedMode(mode || "") === "")
                        return "INVALID_MODE";

                    spotlightLauncher.openSpotlight(mode);
                    return String(mode).toUpperCase();
                }

                target: "spotlight"
            }

            IpcHandler {
                function open(): string {
                    LaunchpadService.open("");
                    return "OPEN";
                }

                function openOn(screenName: string): string {
                    LaunchpadService.open(screenName || "");
                    return LaunchpadService.targetScreenName === "" ? "NO_SCREEN" : "OPEN";
                }

                function close(): string {
                    LaunchpadService.close();
                    return "CLOSED";
                }

                function toggle(): string {
                    LaunchpadService.toggle("");
                    return LaunchpadService.visible ? "OPEN" : "CLOSED";
                }

                function toggleOn(screenName: string): string {
                    LaunchpadService.toggle(screenName || "");
                    return LaunchpadService.visible ? "OPEN" : "CLOSED";
                }

                function page(index: int): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    LaunchpadService.goToPage(index);
                    return String(LaunchpadService.page);
                }

                function next(): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    LaunchpadService.nextPage();
                    return String(LaunchpadService.page);
                }

                function previous(): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    LaunchpadService.previousPage();
                    return String(LaunchpadService.page);
                }

                function edit(): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    LaunchpadService.beginEditing();
                    return "EDITING";
                }

                function search(text: string): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    LaunchpadService.setQuery(text || "");
                    return "SEARCH";
                }

                function folder(id: string): string {
                    LaunchpadService.open(LaunchpadService.targetScreenName);
                    return LaunchpadService.openFolderById(id || "") ? "FOLDER" : "INVALID";
                }

                function reset(): string {
                    LaunchpadService.reset();
                    return "RESET";
                }

                function restoreHidden(): string {
                    LaunchpadService.restoreHidden();
                    return "RESTORED";
                }

                function remove(id: string): string {
                    return LaunchpadService.requestRemoval(id || "") ? "CONFIRM" : "INVALID";
                }

                target: "launchpad"
            }

            IpcHandler {
                function trigger(action: string): string {
                    return root.performGestureAction(action, "") ? "OK" : "INVALID";
                }

                function triggerOn(action: string, screenName: string): string {
                    return root.performGestureAction(action, screenName || "") ? "OK" : "INVALID";
                }

                function actions(): string {
                    return TouchGestureService.actions.join(",");
                }

                target: "gesture"
            }

            IpcHandler {
                function open(): string {
                    return WindowManagerService.open("") ? "OPEN" : "UNAVAILABLE";
                }

                function close(): string {
                    WindowManagerService.close();
                    return "CLOSED";
                }

                function toggle(): string {
                    WindowManagerService.toggle("");
                    return WindowManagerService.visible ? "OPEN" : WindowManagerService.loading ? "LOADING" :
                                                                                                  "CLOSED";
                }

                function swap(source: int, target: int): string {
                    return WindowManagerService.swapWindows(source, target) ? "OK" : "INVALID";
                }

                function fullscreen(id: int): string {
                    return WindowManagerService.toggleFullscreen(id) ? "OK" : "INVALID";
                }

                target: "windows"
            }

            IpcHandler {
                function capture(): string {
                    return ScreenshotService.capture() ? "OK" : "UNAVAILABLE";
                }

                target: "screenshot"
            }

            IpcHandler {
                function toggle(): string {
                    StatusMenuService.toggle();
                    return StatusMenuService.opened ? "OPENING" : "CLOSING";
                }

                function close(): string {
                    StatusMenuService.close();
                    return "CLOSED";
                }

                target: "status-menu"
            }

            IpcHandler {
                function open(): string {
                    TouchKeyboardService.open();
                    return "OPEN";
                }

                function close(): string {
                    TouchKeyboardService.close();
                    return "CLOSED";
                }

                function press(action: string, value: string): string {
                    TouchKeyboardService.press(action || "", value || "");
                    return "OK";
                }

                function candidate(index: int): string {
                    TouchKeyboardService.commitCandidate(index);
                    return "OK";
                }

                function layout(mode: string): string {
                    TouchKeyboardService.setLayoutMode(mode || "qwerty");
                    return TouchKeyboardService.layoutMode;
                }

                function page(value: string): string {
                    TouchKeyboardService.setPage(value || "letters");
                    return TouchKeyboardService.page;
                }

                function state(): string {
                    return JSON.stringify({
                                              "layout": TouchKeyboardService.layoutMode,
                                              "page": TouchKeyboardService.page,
                                              "chinese": TouchKeyboardService.chinese,
                                              "shift": TouchKeyboardService.shift,
                                              "capsLock": TouchKeyboardService.capsLock,
                                              "preedit": TouchKeyboardService.preedit,
                                              "pinyin": TouchKeyboardService.pinyinBuffer,
                                              "digits": TouchKeyboardService.nineKeyDigits,
                                              "segments": TouchKeyboardService.nineKeySegments,
                                              "segmentIndex": TouchKeyboardService.nineKeySegmentIndex,
                                              "candidates": TouchKeyboardService.visibleCandidates
                                          });
                }

                function toggle(): string {
                    TouchKeyboardService.toggle();
                    return TouchKeyboardService.visible ? "OPEN" : "CLOSED";
                }

                target: "touch-keyboard"
            }

            IpcHandler {
                function open(): string {
                    AgentService.openPanel();
                    return "OPEN";
                }

                function close(): string {
                    AgentService.closePanel();
                    return "CLOSED";
                }

                function toggle(): string {
                    AgentService.toggle();
                    return AgentService.panelOpen ? "OPEN" : "CLOSED";
                }

                function send(message: string): string {
                    return AgentService.send(message || "") ? "OK" : "INVALID";
                }

                function settings(): string {
                    AgentService.openSettings();
                    return "OPEN";
                }

                function voice(): string {
                    if (AgentService.voiceState === "listening") {
                        AgentService.stopVoice();
                        return "STOPPED";
                    }
                    AgentService.startVoice();
                    return AgentService.voiceState === "listening" ? "LISTENING" : "BUSY";
                }

                function pets(): string {
                    return JSON.stringify(AgentService.petCatalog.map(entry => ({
                                                                                    "id": entry.id,
                                                                                    "name": entry.name,
                                                                                    "renderer":
                                                                                    entry.renderer || "image",
                                                                                    "aliases": entry.aliases
                                                                                               || [],
                                                                                    "dsh": !!entry.dsh
                                                                                })));
                }

                function importDsh(): string {
                    PetSettingsService.importDsh();
                    return "STARTED";
                }

                function reloadPets(): string {
                    PetPackService.reload();
                    return "OK";
                }

                function setPet(id: string): string {
                    AgentService.setPetImage(id || "whale");
                    return id || "whale";
                }

                function setPetLanguage(language: string): string {
                    PetSettingsService.setLanguage(AgentService.petEntry, language || "");
                    return language || "";
                }

                function petLanguages(): string {
                    const entry = AgentService.petEntry || {};
                    const bundles = entry.locales && typeof entry.locales === "object" ? entry.locales : (
                                                                                             entry.i18n
                                                                                             && typeof entry.i18n
                                                                                             === "object"
                                                                                             ? entry.i18n :
                                                                                               {});
                    return JSON.stringify({
                                              "default": entry.language || "",
                                              "available": Object.keys(bundles)
                                          });
                }

                function fleet(): string {
                    AgentFleetService.openPanel();
                    return "OPEN";
                }

                function fleetStatus(): string {
                    return JSON.stringify({
                                              "agents": AgentFleetService.agents,
                                              "summary": AgentFleetService.summary
                                          });
                }

                function petInfo(): string {
                    return JSON.stringify({
                                              "image": AgentService.pet.image,
                                              "entry": AgentService.petEntry ? AgentService.petEntry.id : null,
                                              "renderer": AgentService.petEntry
                                                          ? AgentService.petEntry.renderer : null,
                                              "animated": AgentService.petIsAnimated,
                                              "size": AgentService.pet.size
                                          });
                }

                function petProfile(): string {
                    const entry = AgentService.petEntry || {};
                    return JSON.stringify({
                                              "id": entry.id || "",
                                              "language": entry.language || "",
                                              "ui": entry.ui || {},
                                              "actions": entry.actions || {},
                                              "menu": entry.menu || [],
                                              "interactions": entry.interactions || {},
                                              "behavior": entry.behavior || {},
                                              "workStatusTexts": entry.workStatusTexts || null,
                                              "locales": entry.locales || entry.i18n || {}
                                          });
                }

                function state(): string {
                    return JSON.stringify({
                                              "open": AgentService.panelOpen,
                                              "online": AgentService.online,
                                              "busy": AgentService.busy,
                                              "session": AgentService.sessionId,
                                              "messages": AgentService.messages.length,
                                              "pet": AgentService.petEnabled,
                                              "voice": AgentService.voiceState
                                          });
                }

                target: "agent"
            }

            IpcHandler {
                function action(id: string): string {
                    PetEventBus.actionRequested(id || "");
                    return id || "";
                }

                function menu(): string {
                    PetEventBus.menuRequested();
                    return "OPEN";
                }

                function say(text: string): string {
                    PetEventBus.sayRequested(text || "");
                    return "OK";
                }

                function state(name: string): string {
                    PetEventBus.stateRequested(name || "");
                    return name || "";
                }

                function fleet(): string {
                    AgentFleetService.openPanel();
                    return "OPEN";
                }

                target: "pet"
            }

            IpcHandler {
                function open(): string {
                    return StageManagerService.open() ? "OPEN" : "UNAVAILABLE";
                }

                function close(): string {
                    return StageManagerService.close() ? "CLOSED" : "CLOSED";
                }

                function toggle(): string {
                    return StageManagerService.toggle() ? "OPEN" : "CLOSED";
                }

                function focus(id: int): string {
                    return StageManagerService.focusWindow(id) ? "OK" : "INVALID";
                }

                function state(): string {
                    return JSON.stringify({
                                              "visible": StageManagerService.visible,
                                              "available": StageManagerService.available,
                                              "windows": StageManagerService.windows.length
                                          });
                }

                target: "stage-manager"
            }

            IpcHandler {
                function set(path: string): string {
                    return WallpaperService.setWallpaper(path || "", "") ? "OK" : "INVALID";
                }

                function setForScreen(path: string, screenName: string): string {
                    return WallpaperService.setWallpaper(path || "", screenName || "") ? "OK" : "INVALID";
                }

                function clear(): string {
                    return WallpaperService.clearWallpaper("") ? "OK" : "INVALID";
                }

                function clearForScreen(screenName: string): string {
                    return WallpaperService.clearWallpaper(screenName || "") ? "OK" : "INVALID";
                }

                function previous(): string {
                    return WallpaperService.cyclePrevious() ? "OK" : "PENDING";
                }

                function next(): string {
                    return WallpaperService.cycleNext() ? "OK" : "PENDING";
                }

                function random(): string {
                    return WallpaperService.cycleRandom() ? "OK" : "PENDING";
                }

                function setFolder(path: string): string {
                    return WallpaperService.setWallpaperFolder(path || "") ? "OK" : "INVALID";
                }

                target: "wallpaper"
            }

            IpcHandler {
                function open(pageId: string): string {
                    return ControlCenterService.open(pageId || "") ? "OK" : "UNAVAILABLE";
                }

                function close(): string {
                    return ControlCenterService.close() ? "OK" : "CLOSED";
                }

                function toggle(pageId: string): string {
                    return ControlCenterService.toggle(pageId || "") ? "OPENING" : "CLOSING";
                }

                function search(id: string): string {
                    return ControlCenterService.openSearch(id || "") ? "OK" : "INVALID";
                }

                target: "control-center"
            }
        }
