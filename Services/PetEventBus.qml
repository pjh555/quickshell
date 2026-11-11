pragma Singleton

import QtQuick
import Quickshell

// Small command/event bus so the shell IPC, the agent monitor and the pet can
// talk to each other without anybody holding a direct reference to AgentPet.
Singleton {
    signal actionRequested(string action)
    signal menuRequested()
    signal sayRequested(string text)
    signal stateRequested(string state)
}
