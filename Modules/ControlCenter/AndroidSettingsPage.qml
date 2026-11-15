import QtQuick

// The Android business page is fully native in Clavis. It intentionally does
// not embed the Android Settings task or any Droidloom-owned QML surface.
Item {
    AndroidPage {
        anchors.fill: parent
    }
}
