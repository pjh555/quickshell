pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool visible: false
    property string page: "letters"
    property string layoutMode: "qwerty"
    property bool chinese: true
    property bool shift: false
    property bool capsLock: false
    property bool autoShift: false
    property bool ctrlLatch: false
    property bool altLatch: false
    property bool superLatch: false
    property string pinyinBuffer: ""
    property string nineKeyDigits: ""
    property string nineKeyPreedit: ""
    property var nineKeySegments: []
    property int nineKeySegmentIndex: 0
    property var candidates: []
    property var recentSymbols: []
    property var recentEmojis: []
    property bool recentReady: false
    property bool candidatePending: false
    property string candidateRunningQuery: ""
    property string candidateResultQuery: ""
    property var queue: []
    property bool sending: false

    readonly property bool composing: root.pinyinBuffer !== "" || root.nineKeyDigits !== ""
    readonly property bool nineKeyComposing: root.layoutMode === "nine" && root.nineKeyDigits !== ""
    readonly property bool effectiveShift: root.shift || root.capsLock || (root.autoShift && !root.chinese)
    readonly property bool modifierLatched: root.ctrlLatch || root.altLatch || root.superLatch
    readonly property string preedit: root.nineKeyDigits !== "" ? (root.nineKeyPreedit !== ""
                                                                   ? root.nineKeyPreedit :
                                                                     root.nineKeyDigits) : root.pinyinBuffer
    readonly property string candidateQuery: root.nineKeyDigits !== "" ? "t9:" + root.nineKeyDigits :
                                                                         root.pinyinBuffer

    readonly property bool rawCandidateVisible: root.chinese && root.pinyinBuffer !== ""
    readonly property int rawCandidateIndex: root.rawCandidateVisible ? 0 : -1
    readonly property var visibleCandidates: {
        let list = root.candidateResultQuery === root.candidateQuery ? root.candidates.slice() : [];
        if (root.rawCandidateVisible)
        list.unshift(root.pinyinBuffer);
        return list;
    }

    function open() {
        root.visible = true;
        root.page = "letters";
        root.shift = false;
        root.capsLock = false;
        root.autoShift = false;
        root.clearModifiers();
        root.clearComposition();
        StatusMenuService.close();
    }

    function close() {
        root.visible = false;
        root.page = "letters";
        root.shift = false;
        root.capsLock = false;
        root.autoShift = false;
        root.clearModifiers();
        root.clearComposition();
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open();
    }

    function sendText(text) {
        const value = String(text || "");
        if (value === "")
            return;
        // wtype cannot join the compositor's input-method grab, so the touch
        // keyboard owns pinyin composition locally and commits the selected
        // text as ordinary key events. Serialize commands so rapid taps
        // cannot reorder pinyin or modifiers.
        root.noteCommitted(value);
        root.enqueue(["wtype", "--", value]);
    }

    function clearModifiers() {
        root.ctrlLatch = false;
        root.altLatch = false;
        root.superLatch = false;
    }

    function sendModifiedKey(key, forceShift) {
        const value = String(key || "");
        if (value === "")
            return;
        const command = ["wtype"];
        const releases = [];
        if (root.ctrlLatch) {
            command.push("-M", "ctrl");
            releases.unshift("ctrl");
        }
        if (root.altLatch) {
            command.push("-M", "alt");
            releases.unshift("alt");
        }
        if (root.superLatch) {
            command.push("-M", "logo");
            releases.unshift("logo");
        }
        if (root.shift || forceShift === true) {
            command.push("-M", "shift");
            releases.unshift("shift");
        }
        command.push("-k", value);
        for (let index = 0; index < releases.length; ++index)
            command.push("-m", releases[index]);
        root.clearModifiers();
        root.shift = false;
        root.enqueue(command);
    }

    function sendKey(key) {
        const value = String(key || "");
        if (value === "")
            return;
        if (root.modifierLatched || root.shift) {
            root.sendModifiedKey(value, false);
            return;
        }
        if (value === "Return")
            root.autoShift = true;
        root.enqueue(["wtype", "-k", value]);
    }

    function noteCommitted(text) {
        const value = String(text || "");
        const trimmed = value.trim();
        if (root.shift)
            root.shift = false;
        if (trimmed === "")
            return;
        const last = trimmed.charAt(trimmed.length - 1);
        root.autoShift = /[.!?。！？\n]/.test(last);
    }

    function chinesePunctuation(value) {
        switch (value) {
        case ",":
            return "，";
        case ".":
            return "。";
        case "?":
            return "？";
        case "!":
            return "！";
        case ":":
            return "：";
        case ";":
            return "；";
        case "(":
            return "（";
        case ")":
            return "）";
        default:
            return value;
        }
    }

    function typeCharacter(value) {
        let text = String(value || "");
        if (text === "")
            return;

        if (root.modifierLatched) {
            root.sendModifiedKey(text, root.capsLock);
            return;
        }

        const upper = root.effectiveShift;
        const letter = /^[a-z]$/.test(text);
        if (root.page === "letters" && root.chinese && letter && !root.shift && !root.capsLock) {
            root.pinyinBuffer += text;
            root.requestCandidates();
            return;
        }

        if (root.composing)
            root.commitComposition();

        if (root.page === "letters" && root.chinese && !letter && !/^[0-9]$/.test(text))
            text = root.chinesePunctuation(text);

        if (upper)
            text = text.toUpperCase();
        root.sendText(text);
    }

    function typeDirect(value) {
        const text = String(value || "");
        if (text === "")
            return;
        if (root.modifierLatched) {
            root.sendModifiedKey(text, root.capsLock);
            return;
        }
        const upper = root.effectiveShift;
        if (root.composing)
            root.commitComposition();
        root.sendText(upper ? text.toUpperCase() : text);
    }

    function typeNineKey(value) {
        if (root.modifierLatched) {
            root.sendModifiedKey(value, false);
            return;
        }
        if (!root.chinese || root.page !== "letters")
            return;
        const digits = String(value || "").replace(/[^2-9]/g, "");
        if (digits === "")
            return;
        root.pinyinBuffer = "";
        root.nineKeyDigits += digits;
        root.nineKeyPreedit = "";
        root.nineKeySegments = [];
        root.nineKeySegmentIndex = 0;
        root.requestCandidates();
    }

    function pushRecent(list, value, limit) {
        const entry = String(value || "");
        if (entry === "")
            return list;
        const next = list.slice();
        const existing = next.indexOf(entry);
        if (existing >= 0)
            next.splice(existing, 1);
        next.unshift(entry);
        if (next.length > limit)
            next.length = limit;
        return next;
    }

    function noteRecentSymbol(symbol) {
        root.recentSymbols = root.pushRecent(root.recentSymbols, symbol, 64);
        root.saveRecent();
    }

    function noteRecentEmoji(emoji) {
        root.recentEmojis = root.pushRecent(root.recentEmojis, emoji, 32);
        root.saveRecent();
    }

    function saveRecent() {
        if (!root.recentReady)
            return;
        recentFile.setText(JSON.stringify({
                                              "symbols": root.recentSymbols,
                                              "emojis": root.recentEmojis
                                          }));
    }

    function clearComposition() {
        root.pinyinBuffer = "";
        root.nineKeyDigits = "";
        root.nineKeyPreedit = "";
        root.nineKeySegments = [];
        root.nineKeySegmentIndex = 0;
        root.candidates = [];
        root.candidatePending = false;
        root.candidateResultQuery = "";
    }

    function requestCandidates() {
        if (root.candidateQuery === "") {
            root.candidates = [];
            root.candidateResultQuery = "";
            root.nineKeyPreedit = "";
            root.nineKeySegments = [];
            root.nineKeySegmentIndex = 0;
            root.candidatePending = false;
            candidateDebounce.stop();
            return;
        }
        root.candidatePending = true;
        candidateDebounce.restart();
    }

    function runCandidateQuery() {
        const query = root.candidateQuery;
        if (query === "")
            return;
        if (candidateProcess.running) {
            root.candidatePending = true;
            return;
        }
        root.candidatePending = false;
        root.candidateRunningQuery = query;
        candidateProcess.command = query.startsWith("t9:") ? ["python3", Paths.shellDir
                                                              + "/scripts/system/clavis-pinyin.py", "--t9",
                                                              query.slice(3)] : ["python3", Paths.shellDir
                                                                                 + "/scripts/system/clavis-pinyin.py",
                                                                                 query];
        candidateProcess.running = true;
    }

    function selectNineKeySegment(index) {
        if (index < 0 || index >= root.nineKeySegments.length)
            return;
        const segment = root.nineKeySegments[index];
        root.nineKeySegmentIndex = index;
        root.nineKeyPreedit = String(segment.text || "");
        root.candidates = Array.isArray(segment.candidates) ? segment.candidates : [];
        root.candidateResultQuery = root.candidateQuery;
    }

    function commitCandidate(index) {
        if (index === root.rawCandidateIndex) {
            const raw = root.pinyinBuffer;
            root.clearComposition();
            root.sendText(raw);
            return;
        }
        if (root.candidateResultQuery !== root.candidateQuery)
            return;
        const candidateIndex = index - (root.rawCandidateVisible ? 1 : 0);
        if (candidateIndex < 0 || candidateIndex >= root.candidates.length)
            return;
        const text = String(root.candidates[candidateIndex] || "");
        const segment = root.nineKeyDigits !== "" && root.nineKeySegments.length > 0
              ? root.nineKeySegments[root.nineKeySegmentIndex] : null;
        if (segment !== null && Array.isArray(segment.syllables) && segment.syllables.length > text.length) {
            const covered = Math.max(1, Math.min(segment.syllables.length, text.length));
            const groups = Array.isArray(segment.digitGroups) ? segment.digitGroups : [];
            const consumed = groups.slice(0, covered).join("");
            const remaining = consumed.length > 0 ? root.nineKeyDigits.slice(consumed.length) :
                                                    root.nineKeyDigits;
            root.clearComposition();
            root.nineKeyDigits = remaining;
            root.sendText(text);
            if (root.nineKeyDigits !== "")
                root.requestCandidates();
            return;
        }
        root.clearComposition();
        root.sendText(text);
    }

    function commitComposition() {
        if (!root.composing)
            return;
        if (root.candidateResultQuery === root.candidateQuery && root.candidates.length > 0) {
            root.commitCandidate(root.rawCandidateVisible ? 1 : 0);
            return;
        }
        const raw = root.nineKeyDigits !== "" ? root.nineKeyDigits : root.pinyinBuffer;
        root.clearComposition();
        root.sendText(raw);
    }

    function backspace() {
        if (root.modifierLatched) {
            root.sendModifiedKey("BackSpace", false);
            return;
        }
        if (root.page === "letters" && root.nineKeyDigits !== "") {
            root.nineKeyDigits = root.nineKeyDigits.slice(0, -1);
            root.nineKeyPreedit = "";
            root.nineKeySegments = [];
            root.nineKeySegmentIndex = 0;
            root.requestCandidates();
            return;
        }
        if (root.page === "letters" && root.pinyinBuffer !== "") {
            root.pinyinBuffer = root.pinyinBuffer.slice(0, -1);
            root.requestCandidates();
            return;
        }
        root.sendKey("BackSpace");
    }

    function space() {
        if (root.modifierLatched) {
            root.sendModifiedKey("space", false);
            return;
        }
        if (root.composing)
            root.commitComposition();
        else
            root.sendText(" ");
    }

    function enter() {
        if (root.modifierLatched) {
            root.sendModifiedKey("Return", false);
            return;
        }
        if (root.composing)
            root.commitComposition();
        else
            root.sendKey("Return");
    }

    function toggleShift() {
        if (root.capsLock) {
            root.capsLock = false;
            root.shift = false;
        } else {
            root.shift = !root.shift;
        }
        root.autoShift = false;
    }

    function toggleCapsLock() {
        root.capsLock = !root.capsLock;
        root.shift = false;
        root.autoShift = false;
    }

    function setChinese(value) {
        root.chinese = !!value;
        if (!root.chinese && root.layoutMode === "nine")
            root.layoutMode = "qwerty";
        root.page = "letters";
        root.shift = false;
        root.capsLock = false;
        root.autoShift = false;
        root.clearModifiers();
        root.clearComposition();
    }

    function setPage(value) {
        const next = String(value || "").toLowerCase();
        if (next !== "letters" && next !== "symbols" && next !== "symbolsall" && next !== "numbers" && next
                !== "emoji" && next !== "keys")
            return;
        if (root.page === next)
            return;
        if (root.page === "letters" && root.composing)
            root.commitComposition();
        root.page = next;
        root.shift = false;
        root.autoShift = false;
        root.clearModifiers();
    }

    function setLayoutMode(value) {
        const mode = String(value || "").toLowerCase() === "nine" ? "nine" : "qwerty";
        root.layoutMode = mode;
        if (mode === "nine")
            root.chinese = true;
        root.page = "letters";
        root.shift = false;
        root.capsLock = false;
        root.autoShift = false;
        root.clearModifiers();
        root.clearComposition();
    }

    function toggleLayout() {
        root.setLayoutMode(root.layoutMode === "nine" ? "qwerty" : "nine");
    }

    function toggleEngine() {
        root.setChinese(!root.chinese);
    }

    function press(action, value) {
        switch (String(action || "")) {
        case "shift":
            root.toggleShift();
            break;
        case "capslock":
            root.toggleCapsLock();
            break;
        case "symbols":
            root.setPage("symbols");
            break;
        case "symbolsAll":
        case "open_symbols":
            root.setPage("symbolsall");
            break;
        case "number":
        case "numbers":
            root.setPage("numbers");
            break;
        case "emoji":
            root.setPage("emoji");
            break;
        case "keys":
            root.setPage("keys");
            break;
        case "letters":
            root.setPage("letters");
            break;
        case "space":
            root.space();
            break;
        case "backspace":
            root.backspace();
            break;
        case "enter":
            root.enter();
            break;
        case "tab":
            root.sendKey("Tab");
            break;
        case "escape":
            root.sendKey("Escape");
            break;
        case "left":
            root.sendKey("Left");
            break;
        case "right":
            root.sendKey("Right");
            break;
        case "up":
            root.sendKey("Up");
            break;
        case "down":
            root.sendKey("Down");
            break;
        case "pageup":
            root.sendKey("Page_Up");
            break;
        case "pagedown":
            root.sendKey("Page_Down");
            break;
        case "insert":
            root.sendKey("Insert");
            break;
        case "print":
            root.sendKey("Print");
            break;
        case "menu":
            root.sendKey("Menu");
            break;
        case "home":
            root.sendKey("Home");
            break;
        case "end":
            root.sendKey("End");
            break;
        case "delete":
            root.sendKey("Delete");
            break;
        case "language":
            root.toggleEngine();
            break;
        case "layout":
            root.toggleLayout();
            break;
        case "nine":
            root.typeNineKey(value);
            break;
        case "ctrl":
            root.ctrlLatch = !root.ctrlLatch;
            break;
        case "alt":
            root.altLatch = !root.altLatch;
            break;
        case "super":
            root.superLatch = !root.superLatch;
            break;
        case "key":
            root.sendKey(value);
            break;
        case "clear":
            root.clearComposition();
            break;
        case "commit":
        case "digit":
            root.typeDirect(value);
            break;
        case "hide":
            root.close();
            break;
        case "char":
        default:
            root.typeCharacter(value);
            break;
        }
    }

    function enqueue(command) {
        if (!command || command.length === 0)
            return;
        root.queue.push(command);
        root.pump();
    }

    function pump() {
        if (root.sending || root.queue.length === 0)
            return;
        root.sending = true;
        sender.command = root.queue.shift();
        sender.running = true;
    }

    Timer {
        id: candidateDebounce

        interval: 40
        repeat: false
        onTriggered: root.runCandidateQuery()
    }

    Process {
        id: sender

        onExited: {
            root.sending = false;
            Qt.callLater(root.pump);
        }

        stderr: SplitParser {
            onRead: data => console.warn("[touch-keyboard]", data.trim())
        }
    }

    Process {
        id: candidateProcess

        stdout: StdioCollector {
            id: candidateOutput
        }

        onExited: {
            const query = root.candidateRunningQuery;
            let parsed = [];
            let segments = [];
            let preedit = "";
            try {
                const value = JSON.parse(String(candidateOutput.text || "[]").trim() || "[]");
                if (Array.isArray(value)) {
                    parsed = value;
                } else if (value && Array.isArray(value.candidates)) {
                    parsed = value.candidates;
                    preedit = String(value.preedit || "");
                    segments = Array.isArray(value.segments) ? value.segments : [];
                }
            } catch (error) {
                parsed = [];
            }
            if (query !== "" && query === root.candidateQuery) {
                root.candidates = parsed;
                root.candidateResultQuery = query;
                if (root.nineKeyDigits !== "") {
                    root.nineKeyPreedit = preedit;
                    root.nineKeySegments = segments;
                    root.nineKeySegmentIndex = 0;
                }
            }
            root.candidateRunningQuery = "";
            if (root.candidatePending || (query !== root.candidateQuery && root.candidateQuery !== ""))
            Qt.callLater(root.requestCandidates);
        }

        stderr: SplitParser {
            onRead: data => console.warn("[touch-keyboard-pinyin]", data.trim())
        }
    }

    Process {
        id: ensureStateDir

        command: ["mkdir", "-p", Paths.stateHome]

        running: true

        onExited: {
            recentFile.blockLoading = false;
            recentFile.blockWrites = false;
            recentFile.reload();
        }
    }

    FileView {
        id: recentFile

        path: Paths.stateHome + "/touch-keyboard-recent.json"
        watchChanges: false
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const value = JSON.parse(recentFile.text().trim() || "{}");
                root.recentSymbols = Array.isArray(value.symbols) ? value.symbols.filter(item => typeof item
                                                                                         === "string").slice(0,
                                                                                                             64) : [];
                root.recentEmojis = Array.isArray(value.emojis) ? value.emojis.filter(item => typeof item
                                                                                      === "string").slice(0,
                                                                                                          32) : [];
            } catch (error) {
                root.recentSymbols = [];
                root.recentEmojis = [];
            }
            root.recentReady = true;
        }

        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
            console.warn("[touch-keyboard-recent]", error);
            root.recentReady = true;
        }
    }
}
