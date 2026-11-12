pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    property bool glassSurface: true
    property color foregroundColor: "#FFFFFF"
    property color secondaryForegroundColor: Qt.rgba(1, 1, 1, 0.78)
    property color accentColor: "#FFFFFF"

    readonly property string alternateDir: Paths.homeDir + "/图片"
    readonly property string picturesDir: UserDirs.picturesDir
    readonly property var photoModel: primaryModel.count > 0 ? primaryModel : alternateModel
    readonly property int photoCount: root.photoModel ? root.photoModel.count : 0
    property int indexA: 0
    property int indexB: -1
    property bool showA: true
    readonly property int activeIndex: root.showA ? root.indexA : root.indexB
    readonly property string activePath: root.pathAt(root.activeIndex)
    readonly property string activeFileName: {
        root.photoCount;
        const model = root.photoModel;
        const index = root.activeIndex;
        if (!model || index < 0 || index >= model.count)
        return "";

        const name = String(model.get(index, "fileName") || "");
        return name.replace(/\.[^.]+$/, "");
    }
    readonly property date activeModified: {
        root.photoCount;
        const model = root.photoModel;
        const index = root.activeIndex;
        if (!model || index < 0 || index >= model.count)
        return new Date(NaN);

        return model.get(index, "fileModified") || new Date(NaN);
    }
    readonly property string activeDateText: isNaN(root.activeModified.getTime()) ? "" : Qt.formatDate(
                                                                                        root.activeModified,
                                                                                        "MMM d, yyyy")
    // SystemCardContent owns the full-bleed image and the bottom scrim.  These
    // properties keep the existing two-image crossfade and auto-advance.
    readonly property string shellBackgroundSourceA: root.photoUrl(root.indexA)
    readonly property string shellBackgroundSourceB: root.photoUrl(root.indexB)
    readonly property bool shellBackgroundShowA: root.showA

    function pathAt(index) {
        const model = root.photoModel;
        if (!model || index < 0 || index >= model.count)
            return "";

        return String(model.get(index, "filePath") || "");
    }

    function photoUrl(index) {
        const path = root.pathAt(index);
        return path.length > 0 ? Paths.fileUrl(path) : "";
    }

    function advance() {
        if (root.photoCount < 2)
            return;

        const next = (root.activeIndex + 1) % root.photoCount;
        if (root.showA)
            root.indexB = next;
        else
            root.indexA = next;

        root.showA = !root.showA;
    }

    function openCurrent() {
        if (root.activePath.length > 0)
            FileActionService.run("open", root.activePath);
    }

    onPhotoModelChanged: {
        root.indexA = 0;
        root.indexB = -1;
        root.showA = true;
    }

    onPhotoCountChanged: {
        if (root.indexA >= root.photoCount)
        root.indexA = 0;

        if (root.indexB >= root.photoCount)
        root.indexB = -1;
    }

    Accessible.name: qsTr("Photos")

    FolderListModel {
        id: primaryModel

        folder: Paths.fileUrl(root.picturesDir)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        sortCaseSensitive: false
    }

    FolderListModel {
        id: alternateModel

        folder: Paths.fileUrl(root.alternateDir)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        sortCaseSensitive: false
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.visible && root.photoCount > 1
        onTriggered: root.advance()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 18
        width: 30
        height: 30
        radius: Appearance.rounding.small
        color: Qt.rgba(1, 1, 1, 0.18)

        MaterialSymbol {
            anchors.centerIn: parent
            text: "photo_library"
            iconSize: 18
            color: root.accentColor
            fill: 1
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 18
        width: photoCountLabel.implicitWidth + Appearance.spacing.medium
        height: 28
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.20)
        visible: root.photoCount > 0

        Text {
            id: photoCountLabel

            anchors.centerIn: parent
            text: String(root.photoCount)
            color: root.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 18
        }
        spacing: 2
        visible: root.photoCount > 0

        Text {
            Layout.fillWidth: true
            text: qsTr("Photos")
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.activeFileName
            color: root.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.activeDateText
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10
        visible: root.photoCount === 0

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: Appearance.rounding.large
            color: Qt.rgba(1, 1, 1, 0.18)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "photo_library"
                iconSize: 40
                color: root.accentColor
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No photos found")
            color: root.secondaryForegroundColor
            font.family: Fonts.ui
            font.pixelSize: 14
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.photoCount > 0
        cursorShape: Qt.PointingHandCursor
        Accessible.name: qsTr("Open photo")
        Accessible.role: Accessible.Button
        onClicked: root.openCurrent()
    }
}
