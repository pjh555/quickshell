import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import "PetProfile.js" as PetProfile

// A native desktop pet and always-visible Agent Mission Control HUD. The
// character is a data-driven pack; this file interprets PetProfile and never
// refers to a specific pet or action name.
PanelWindow {
    id: root

    readonly property var petSettings: PetSettingsService.forPack(AgentService.petEntry)
    readonly property real petSize: Math.max(64, Math.min(240, Number(petSettings.size)
                                                             || Number(AgentService.pet.size) || 112))
    property real petX: screen ? screen.width - petSize - 36 : 800
    property real petY: screen ? screen.height - petSize - 92 : 500
    property real squash: 0
    property real pressX: 0
    property real pressY: 0
    property bool moved: false
    property bool positionReady: false
    property bool hovering: false
    property bool dragging: false
    property bool wandering: false
    property int wanderDir: 1
    property bool petMirror: false

    property string currentAction: ""
    property real actionUntil: 0
    property bool sleeping: false
    property real lastInteraction: Date.now() / 1000
    property real lastTick: Date.now() / 1000
    property real lastClickAt: 0
    property real nextAmbient: Date.now() / 1000 + 10
    property real nextWander: Date.now() / 1000 + 5
    property real wanderUntil: 0
    property string lastAgentState: ""
    property bool agentActive: false
    property string lastBubbleKey: ""

    readonly property var petEntry: AgentService.petEntry
    readonly property string preferredLocale: PetSettingsService.languageFor(AgentService.petEntry)
    readonly property var uiDefaults: ({
        "menuTitle": qsTr("Actions"),
        "agentPanel": qsTr("Open Agent"),
        "petSettings": qsTr("Pet settings")
    })
    readonly property var profile: PetProfile.build(AgentService.petEntry, root.preferredLocale,
                                                     root.uiDefaults)
    readonly property bool wanderEnabled: profile && profile.wander ? profile.wander.enabled
                                                                   && !PetSettingsService.fixed(AgentService.petEntry) : false
    readonly property bool workStatusEnabled: PetSettingsService.workStatusEnabled(AgentService.petEntry)
    readonly property bool soundsEnabled: PetSettingsService.soundsEnabled(AgentService.petEntry)
    readonly property bool desktopVisible: PetSettingsService.isDesktopVisible(AgentService.petEntry)
    readonly property real wanderSpeed: profile && profile.wander ? profile.wander.speed : 26
    readonly property bool baseFacesLeft: profile && profile.wander && profile.wander.facing === "left"
    readonly property bool rendererReady: renderer.item ? renderer.item.ready === true : false

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: AgentService.petEnabled && root.desktopVisible
    color: "transparent"
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-agent-pet"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: inputRegion
    }

    function playPet(name) {
        if (renderer.item && typeof renderer.item.play === "function")
            renderer.item.play(name);
    }

    function dragAnimation() {
        const spec = root.profile && root.profile.interactions ? root.profile.interactions.dragStart : null;
        if (spec && typeof spec === "object" && spec.animation)
            return String(spec.animation);
        if (typeof spec === "string" && AgentService.petEntry && AgentService.petEntry.animations
                && AgentService.petEntry.animations[spec])
            return spec;
        return "drag";
    }

    function statusText(state) {
        const order = ["thinking", "working", "result", "waiting", "success", "error"];
        const idx = order.indexOf(state);
        const imported = root.petSettings ? root.petSettings.workStatusTexts : null;
        if (idx >= 0 && Array.isArray(imported) && Array.isArray(imported[idx]) && imported[idx].length)
            return PetProfile.pickText(imported[idx]);
        const texts = profile && profile.statusTexts ? profile.statusTexts[state] : null;
        return texts && texts.length ? PetProfile.pickText(texts) : "";
    }

    function agentActionFor(state) {
        const override = root.petSettings && root.petSettings.agentStates
                ? root.petSettings.agentStates[state] : null;
        if (override) {
            if (profile.actions && profile.actions[override])
                return profile.actions[override];
            const anims = AgentService.petEntry && AgentService.petEntry.animations;
            if (anims && anims[override])
                return { "id": "agent:" + state, "animation": override,
                         "duration": state === "success" ? 2.5 : 3.5, "loop": true };
        }
        return profile.agentStates ? profile.agentStates[state] : null;
    }

    function showBubble(text, ms) {
        if (!text)
            return;
        petBubble.show(text, ms);
    }

    function showAgentBubble(state, force) {
        const task = AgentFleetService.petTask || "";
        const key = String(state) + "|" + task;
        if (!force && key === root.lastBubbleKey)
            return;
        root.lastBubbleKey = key;
        // The character's own statusTexts are the voice. If the pack has no
        // wording, show the actual task; never inject a generic pet phrase.
        const body = task || root.statusText(state);
        if (!body)
            return;
        const name = (AgentFleetService.petAgent
                      && String(AgentFleetService.petAgent.status || "") === String(state))
                ? AgentFleetService.petName : "";
        root.showBubble((name ? "[" + name + "] " : "") + body,
                        state === "waiting" || state === "error" ? 9000 : 5000);
    }

    function stopWander() {
        if (!root.wandering)
            return;
        root.wandering = false;
        root.petMirror = false;
        if (root.currentAction === "" && !root.agentActive && !root.sleeping)
            root.playPet("idle");
    }

    function openMenu() {
        if (!petMenu.entries || petMenu.entries.length === 0)
            return;
        const mw = petMenu.menuWidth;
        const mh = petMenu.contentHeight;
        let mx = pet.x + pet.width + 8;
        if (mx + mw > root.width - 8)
            mx = pet.x - mw - 8;
        mx = Math.max(8, Math.min(root.width - mw - 8, mx));
        let my = pet.y + pet.height - mh;
        my = Math.max(8, Math.min(root.height - mh - 8, my));
        petMenu.x = mx;
        petMenu.y = my;
        petMenu.open();
    }

    function startWander() {
        if (!root.wanderEnabled || root.dragging || root.hovering || root.agentActive)
            return;
        root.wandering = true;
        root.wanderDir = Math.random() < 0.5 ? -1 : 1;
        root.wanderUntil = Date.now() / 1000 + 4 + Math.random() * 7;
        root.playPet(profile.wander.animation || "walk");
        const lines = profile.wander && profile.wander.say ? profile.wander.say : [];
        if (lines.length && Math.random() < 0.35)
            root.showBubble(PetProfile.pickText(lines), 2200);
    }

    function startSleep() {
        if (!profile || !profile.sleep || root.sleeping || root.agentActive)
            return;
        root.sleeping = true;
        root.stopWander();
        root.playPet(profile.sleep.animation || "sleep");
        const lines = profile.sleep.say ? profile.sleep.say : [];
        if (lines.length)
            root.showBubble(PetProfile.pickText(lines), 3000);
    }

    function wake() {
        if (!root.sleeping)
            return;
        root.sleeping = false;
        root.lastInteraction = Date.now() / 1000;
        if (profile.sleep && profile.sleep.wakeAnimation) {
            root.currentAction = "wake";
            root.actionUntil = root.lastInteraction + 1.2;
            root.playPet(profile.sleep.wakeAnimation);
        } else {
            root.playPet("idle");
        }
        const lines = profile.sleep && profile.sleep.wakeSay ? profile.sleep.wakeSay : [];
        if (lines.length)
            root.showBubble(PetProfile.pickText(lines), 1800);
    }

    function runAction(actionOrId) {
        if (actionOrId === undefined || actionOrId === null)
            return;
        if (typeof actionOrId === "string") {
            if (actionOrId === "agentPanel") {
                AgentService.openPanel();
                return;
            }
            if (actionOrId === "petSettings") {
                AgentService.openPetSettings();
                return;
            }
            if (actionOrId === "fleet") {
                AgentFleetService.openPanel();
                return;
            }
            if (actionOrId === "fleetSummary") {
                AgentFleetService.sendSummary();
                return;
            }
            if (actionOrId === "menu") {
                petMenu.open();
                return;
            }
            if (actionOrId === "idle" || actionOrId === "") {
                root.finishAction();
                return;
            }
            const known = profile.actions ? profile.actions[actionOrId] : null;
            if (!known) {
                // Allow an interaction to point directly at an animation.
                if (AgentService.petEntry && AgentService.petEntry.animations
                        && AgentService.petEntry.animations[actionOrId]) {
                    root.playPet(actionOrId);
                }
                return;
            }
            actionOrId = known;
        }
        if (typeof actionOrId !== "object")
            return;
        const action = actionOrId;
        if (action.agent === "sleep") {
            if (root.sleeping)
                root.wake();
            else
                root.startSleep();
            return;
        }
        if (action.agent === "wake") {
            root.wake();
            return;
        }
        root.stopWander();
        root.sleeping = false;
        root.lastInteraction = Date.now() / 1000;
        root.currentAction = String(action.id || "action");
        root.actionUntil = root.lastInteraction + Math.max(0.35, Number(action.duration) || 2.2);
        if (action.animation)
            root.playPet(action.animation);
        else
            root.playPet("idle");
        if (action.say && action.say.length)
            root.showBubble(PetProfile.pickText(action.say), Math.max(1500, action.duration * 1000));
        if (action.agent === "panel") {
            AgentService.openPanel();
        } else if (action.agent === "toggle") {
            AgentService.toggle();
        } else if (action.agent === "prompt" && action.prompt) {
            AgentService.openPanel();
            AgentService.send(action.prompt);
        } else if (action.agent === "settings") {
            AgentService.openPetSettings();
        } else if (action.agent === "fleet") {
            AgentFleetService.openPanel();
        } else if (action.agent === "summary") {
            AgentFleetService.sendSummary();
        }
    }

    function triggerInteraction(name) {
        const spec = profile.interactions ? profile.interactions[name] : null;
        if (!spec)
            return;
        root.runAction(spec);
    }

    function finishAction() {
        root.currentAction = "";
        root.actionUntil = 0;
        if (root.lastAgentState !== "" && root.lastAgentState !== "idle"
                && root.lastAgentState !== "success") {
            root.applyAgentState(true);
        } else {
            root.agentActive = false;
            root.playPet("idle");
        }
        root.nextAmbient = Date.now() / 1000 + 10 + Math.random() * 8;
        root.nextWander = Date.now() / 1000 + 4 + Math.random() * 8;
    }

    function applyAgentState(force) {
        if (!root.workStatusEnabled) {
            root.lastAgentState = "idle";
            root.agentActive = false;
            if (root.currentAction.indexOf("agent:") === 0) {
                root.currentAction = "";
                root.playPet("idle");
            }
            return;
        }
        const state = AgentFleetService.petState || "idle";
        if (!force && state === root.lastAgentState)
            return;
        root.lastAgentState = state;
        if (state === "idle") {
            root.agentActive = false;
            if (root.currentAction.indexOf("agent:") === 0) {
                root.currentAction = "";
                root.playPet("idle");
            }
            return;
        }
        // Do not stomp a user-triggered pet/feed animation; alert states win.
        if (root.currentAction !== "" && root.currentAction.indexOf("agent:") !== 0
                && state !== "waiting" && state !== "error")
            return;
        if (root.currentAction !== "" && root.currentAction.indexOf("agent:") !== 0
                && (state === "waiting" || state === "error")) {
            root.currentAction = "";
        }
        root.agentActive = true;
        root.sleeping = false;
        root.stopWander();
        const action = root.agentActionFor(state);
        root.currentAction = "agent:" + state;
        if (state === "success") {
            root.actionUntil = Date.now() / 1000 + (action ? action.duration : 2.5);
        } else {
            root.actionUntil = Number.MAX_VALUE;
        }
        if (action && action.animation)
            root.playPet(action.animation);
        root.showAgentBubble(state, true);
        if (state === "success")
            root.agentActive = true;
    }

    function tick() {
        if (!root.visible)
            return;
        const now = Date.now() / 1000;
        const dt = Math.min(0.2, Math.max(0, now - root.lastTick));
        root.lastTick = now;

        if (root.currentAction !== "" && now >= root.actionUntil)
            root.finishAction();

        if (root.sleeping)
            return;
        if (AgentFleetService.panelOpen || ControlCenterService.visible) {
            root.stopWander();
            return;
        }
        if (root.currentAction !== "" || root.dragging || root.hovering || root.agentActive)
            return;

        if (root.wanderEnabled && !root.wandering && now >= root.nextWander)
            root.startWander();
        if (root.wandering) {
            const minX = 8;
            const maxX = root.width - root.petSize - 8;
            let nextX = root.petX + root.wanderDir * root.wanderSpeed * dt;
            if (nextX <= minX) {
                nextX = minX;
                root.wanderDir = 1;
            } else if (nextX >= maxX) {
                nextX = maxX;
                root.wanderDir = -1;
            }
            root.petX = nextX;
            root.petMirror = (root.wanderDir < 0) !== root.baseFacesLeft;
            if (now >= root.wanderUntil)
                root.stopWander();
            return;
        }

        if (profile.ambient && profile.ambient.length > 0 && now >= root.nextAmbient) {
            const item = root.pickAmbient(profile.ambient);
            root.nextAmbient = now + 14 + Math.random() * 12;
            if (item)
                root.runAction(item.action);
            return;
        }

        if (profile.sleep && now - root.lastInteraction > profile.sleep.after) {
            root.startSleep();
        }
    }

    function pickAmbient(list) {
        let total = 0;
        for (let i = 0; i < list.length; i++)
            total += Number(list[i].weight) || 1;
        let roll = Math.random() * total;
        for (let i = 0; i < list.length; i++) {
            roll -= Number(list[i].weight) || 1;
            if (roll <= 0)
                return list[i];
        }
        return list[list.length - 1];
    }

    function resumeAfterInteraction() {
        root.lastInteraction = Date.now() / 1000;
        if (root.agentActive || root.lastAgentState === "waiting"
                || root.lastAgentState === "error" || root.lastAgentState === "working") {
            root.applyAgentState(true);
        } else {
            root.playPet("idle");
        }
        root.nextAmbient = Date.now() / 1000 + 8 + Math.random() * 8;
        root.nextWander = Date.now() / 1000 + 4 + Math.random() * 8;
    }

    Item {
        id: pet

        x: root.petX
        y: root.petY
        width: root.petSize
        height: root.petSize
        transformOrigin: Item.Bottom
        scale: 1 - root.squash * 0.12
        z: 20

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: 10
            radius: 5
            color: Qt.rgba(0, 0, 0, 0.26)
            y: parent.height - 12
            visible: !root.profile || !root.profile.appearance || root.profile.appearance.shadow !== false
        }

        Loader {
            id: renderer

            anchors.fill: parent
            sourceComponent: AgentService.petIsAnimated ? framesRenderer : imageRenderer
        }

        Text {
            anchors.centerIn: parent
            visible: !root.rendererReady
            text: "🐳"
            font.pixelSize: Math.max(42, root.petSize * 0.64)
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            text: AgentService.config.name || qsTr("Clavis Agent")
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: 10
            style: Text.Outline
            styleColor: Appearance.applyAlpha(Appearance.macos.background, 0.8)
            visible: pointer.containsMouse && (!root.profile || !root.profile.appearance
                                               || root.profile.appearance.label !== false)
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                root.hovering = true;
                root.lastInteraction = Date.now() / 1000;
                root.stopWander();
                if (root.currentAction === "" && !root.agentActive && !root.sleeping)
                    root.playPet("idle");
            }

            onExited: {
                root.hovering = false;
                root.nextAmbient = Date.now() / 1000 + 8 + Math.random() * 8;
                root.nextWander = Date.now() / 1000 + 4 + Math.random() * 8;
            }

            onPressed: event => {
                           root.lastInteraction = Date.now() / 1000;
                           if (event.button === Qt.RightButton) {
                               root.stopWander();
                               root.openMenu();
                               return;
                           }
                           petMenu.close();
                           if (root.sleeping)
                               root.wake();
                           root.pressX = event.x;
                           root.pressY = event.y;
                           root.moved = false;
                           root.positionReady = true;
                           root.dragging = true;
                           root.currentAction = "";
                           root.squash = 1;
                           root.stopWander();
                           root.playPet(root.dragAnimation());
                           if (root.soundsEnabled) AgentService.playPetSound(true);
                       }

            onPositionChanged: event => {
                                   if (!pressed)
                                   return;
                                   const dx = event.x - root.pressX;
                                   const dy = event.y - root.pressY;
                                   if (Math.hypot(dx, dy) <= 8 && !root.moved)
                                   return;
                                   root.moved = true;
                                   const targetScreen = root.screen;
                                   if (!targetScreen)
                                   return;
                                   root.petX = Math.max(8, Math.min(targetScreen.width - root.petSize - 8,
                                                                    root.petX + dx));
                                   root.petY = Math.max(32, Math.min(targetScreen.height - root.petSize - 48,
                                                                     root.petY + dy));
                               }

            onReleased: event => {
                            if (event.button === Qt.RightButton)
                            return;
                            root.squash = 0;
                            root.dragging = false;
                            if (root.soundsEnabled) AgentService.playPetSound(false);
                            if (root.moved) {
                                PetSettingsService.setPosition(AgentService.petEntry, root.petX, root.petY);
                                root.resumeAfterInteraction();
                                return;
                            }
                            const now = Date.now();
                            if (now - root.lastClickAt < 360) {
                                root.lastClickAt = 0;
                                root.triggerInteraction("doubleClick");
                            } else {
                                root.lastClickAt = now;
                                root.triggerInteraction("singleClick");
                            }
                        }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
            }
        }
    }

    PetBubble {
        id: petBubble
        anchorItem: pet
        z: 30
    }

    PetMenu {
        id: petMenu
        entries: root.profile.menu || []
        menuTitle: root.profile.ui ? root.profile.ui.menuTitle : ""
        onActionTriggered: action => {
                               root.lastInteraction = Date.now() / 1000;
                               root.runAction(action);
                           }
    }

    // The layer surface's input region must include the in-surface menu while
    // it is open; otherwise its clicks would pass through to the app below.
    Item {
        id: inputRegion

        x: petMenu.visible ? Math.min(pet.x, petMenu.x) : pet.x
        y: petMenu.visible ? Math.min(pet.y, petMenu.y) : pet.y
        width: petMenu.visible ? Math.max(pet.x + pet.width, petMenu.x + petMenu.width) - x : pet.width
        height: petMenu.visible ? Math.max(pet.y + pet.height, petMenu.y + petMenu.height) - y : pet.height
    }

    Component {
        id: framesRenderer

        PetFrames {
            anchors.fill: parent
            pack: AgentService.petEntry
            petSize: root.petSize
            mirror: root.petMirror
        }
    }

    Component {
        id: imageRenderer

        Image {
            property bool ready: status === Image.Ready

            anchors.fill: parent
            source: AgentService.petImageUrl
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            mirror: root.petMirror
        }
    }

    Timer {
        id: behaviorTimer

        interval: 40
        repeat: true
        running: true
        onTriggered: root.tick()
    }

    Connections {
        target: AgentFleetService

        function onPetStateChanged() {
            root.applyAgentState(false);
        }

        function onPetTaskChanged() {
            if (root.agentActive)
                root.showAgentBubble(root.lastAgentState, false);
        }

        function onPanelOpenChanged() {
            if (AgentFleetService.panelOpen)
                root.stopWander();
        }
    }

    Connections {
        target: PetEventBus

        function onActionRequested(action) {
            root.runAction(action);
        }

        function onMenuRequested() {
            root.openMenu();
        }

        function onSayRequested(text) {
            root.showBubble(text, 4500);
        }

        function onStateRequested(state) {
            AgentFleetService.debugState = String(state || "");
            root.lastAgentState = "";
            root.applyAgentState(true);
        }
    }

    Connections {
        target: ControlCenterService

        function onVisibleChanged() {
            if (ControlCenterService.visible)
                root.stopWander();
        }
    }

    function clampPetPosition() {
        const targetScreen = root.screen;
        if (!targetScreen || targetScreen.width <= 0 || targetScreen.height <= 0)
            return;
        root.petX = Math.max(8, Math.min(targetScreen.width - root.petSize - 8, root.petX));
        root.petY = Math.max(32, Math.min(targetScreen.height - root.petSize - 48, root.petY));
    }

    function placePet() {
        const targetScreen = root.screen;
        if (!targetScreen || targetScreen.width <= 0 || targetScreen.height <= 0)
            return;
        if (!root.positionReady) {
            const p = PetSettingsService.positionForPack(AgentService.petEntry,
                                                          targetScreen.width, targetScreen.height,
                                                          root.petSize);
            root.petX = p.x;
            root.petY = p.y;
            root.positionReady = true;
            root.clampPetPosition();
        } else {
            root.clampPetPosition();
        }
    }

    Component.onCompleted: {
        Qt.callLater(function () { root.placePet(); });
        Qt.callLater(function () { root.applyAgentState(true); });
    }

    onWidthChanged: root.placePet()
    onVisibleChanged: {
        if (!root.visible)
            petMenu.close();
    }
    onHeightChanged: root.placePet()
    onScreenChanged: Qt.callLater(root.placePet)
    onPetSizeChanged: root.clampPetPosition()

    onPetSettingsChanged: {
        root.positionReady = false;
        Qt.callLater(function () { root.placePet(); });
    }
    onWorkStatusEnabledChanged: {
        if (!root.workStatusEnabled) {
            root.lastAgentState = "";
            root.agentActive = false;
            root.currentAction = "";
            root.playPet("idle");
            petBubble.hide();
        } else {
            Qt.callLater(function () { root.applyAgentState(true); });
        }
    }

    onWanderEnabledChanged: {
        if (!root.wanderEnabled)
            root.stopWander();
    }

    onProfileChanged: {
        petMenu.close();
        root.currentAction = "";
        root.actionUntil = 0;
        root.agentActive = false;
        root.lastAgentState = "";
        root.lastBubbleKey = "";
        root.sleeping = false;
        root.wandering = false;
        root.petMirror = false;
        root.positionReady = false;
        root.playPet("idle");
        Qt.callLater(function () {
            root.placePet();
            root.applyAgentState(true);
        });
    }
}
