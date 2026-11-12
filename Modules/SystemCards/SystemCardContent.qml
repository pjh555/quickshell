import "../../Common/functions/SystemFormat.js" as Format
import "./SystemCardCatalog.js" as CardCatalog
import "./SystemCardPalette.js" as CardPalette
import M3Shapes
import Qt5Compat.GraphicalEffects as GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property string tileId
    property bool active: true
    property real interactionProgress: 0
    // A card may move between the sidebar and desktop without changing its
    // visual surface contract.  The first six cards retain the original
    // surface bindings; the remaining cards can opt into the shell-managed
    // surface introduced by the sidebar background work.
    property bool useShellManagedSurface: false
    readonly property var catalogEntry: CardCatalog.definitionFor(root.tileId)
    // Catalog metadata retained for compatibility; host surfaces own the
    // background and no longer defer to the legacy per-card shape.
    readonly property bool preserveDefaultSurface: root.catalogEntry !== null
                                                   && root.catalogEntry.preserveDefaultSurface === true
    readonly property bool shellManagedSurface: root.useShellManagedSurface
    readonly property int surfaceRadius: Appearance.rounding.veryLarge
    readonly property var palette: CardPalette.paletteFor(root.tileId)
    // iPad-style widget surface: a saturated diagonal gradient replaces the
    // flat dark rectangle.  Every card consumes these values so icon badges,
    // chart strokes and typography stay legible on their own gradient.
    readonly property real clearMaterialOpacity: BlurService.enabled ? 0.72 : 0.94
    readonly property color glassGradientStart: Appearance.applyAlpha(root.palette.start,
                                                                      root.clearMaterialOpacity)
    readonly property color glassGradientMid: Appearance.applyAlpha(root.palette.mid,
                                                                    root.clearMaterialOpacity * 0.84)
    readonly property color glassGradientEnd: Appearance.applyAlpha(root.palette.end,
                                                                    root.clearMaterialOpacity)
    readonly property color glassForeground: root.palette.foreground
    readonly property color glassSecondaryForeground: root.palette.secondary
    readonly property color glassAccent: root.palette.accent
    readonly property color glassAccentBackground: root.palette.accentBackground
    readonly property color glassPanelColor: Qt.rgba(1, 1, 1, 0.12 + root.interactionProgress * 0.04)
    readonly property color glassBorderColor: Qt.rgba(1, 1, 1, 0.24 + root.interactionProgress * 0.12)
    readonly property var contentItem: contentLoader.item
    // Music supplies album art and Photos supplies its crossfading image pair
    // through these optional properties; every other card leaves them empty
    // and keeps the gradient background.
    readonly property string contentBackgroundSourceA: {
        const item = root.contentItem;
        if (!item)
            return "";

        const source = item.shellBackgroundSourceA !== undefined ? item.shellBackgroundSourceA :
                                                                   item.shellBackgroundSource;
        return typeof source === "string" ? source : "";
    }
    readonly property string contentBackgroundSourceB: {
        const item = root.contentItem;
        if (!item || typeof item.shellBackgroundSourceB !== "string")
            return "";

        return item.shellBackgroundSourceB;
    }
    readonly property bool contentBackgroundShowA: {
        const item = root.contentItem;
        if (!item || item.shellBackgroundShowA === undefined)
            return true;

        return item.shellBackgroundShowA === true;
    }
    readonly property bool contentBackgroundIsPhotos: root.tileId === "photos"
    readonly property bool contentBackgroundEnabled: (root.tileId === "music" || root.tileId === "photos")
                                                     && root.contentBackgroundSourceA.length > 0
    readonly property int chartUpdateInterval: Math.max(250, Number(SystemMonitorService.sourceIntervalMs)
                                                        || SystemMonitorService.intervalMs)
    readonly property var primaryGpu: SystemMonitorService.selectedGpu
    readonly property var cpuTemperature: Format.isNumber(SystemMonitorService.cpu.packageTemperatureCelsius)
                                          ? SystemMonitorService.cpu.packageTemperatureCelsius :
                                            SystemMonitorService.cpu.temperatureCelsius
    readonly property var ioDisk: root.diskForDevice(UiPreferences.systemMonitorDiskDevice, true)
    readonly property var capacityDisk: UiPreferences.storageCapacityDiskDevice === "follow-io" ? root.ioDisk :
                                                                                                  root.diskForDevice(
                                                                                                      UiPreferences.storageCapacityDiskDevice,
                                                                                                      false)
    readonly property bool usesRectangularShadow: root.shellManagedSurface || ["cpu", "gpu", "network",
                                                                               "storage", "calendar"].indexOf(
                                                      root.tileId) >= 0
    readonly property int shadowShape: {
        if (root.shellManagedSurface)
            return -1;

        switch (root.tileId) {
        case "memoryUsed":
            return MaterialShape.Slanted;
        case "wifi":
            return MaterialShape.Pentagon;
        case "storageCapacity":
            return MaterialShape.Cookie9Sided;
        default:
            return -1;
        }
    }
    readonly property color shadowSurfaceColor: {
        if (root.shellManagedSurface)
            return Appearance.applyAlpha(Appearance.m3colors.m3surfaceContainerHigh, BlurService.enabled
                                         ? 0.12 : 0.72);

        switch (root.tileId) {
        case "battery":
        case "gpu":
        case "storageCapacity":
            return root.surfaceColor(Appearance.m3colors.m3secondaryContainer,
                                     Appearance.colors.colSecondaryContainer);
        case "cpu":
        case "memoryUsed":
            return root.surfaceColor(Appearance.m3colors.m3primaryContainer,
                                     Appearance.colors.colPrimaryContainer);
        case "wifi":
            return root.surfaceColor(Appearance.m3colors.m3tertiaryContainer,
                                     Appearance.colors.colTertiaryContainer);
        case "network":
            return root.surfaceColor(Appearance.m3colors.m3primary, Appearance.colors.colPrimary);
        case "storage":
            return root.surfaceColor(Appearance.m3colors.m3tertiary, Appearance.colors.colTertiary);
        case "calendar":
            return root.surfaceColor(Appearance.m3colors.m3surfaceContainerHigh,
                                     Appearance.colors.colSurfaceContainerHigh);
        default:
            return Appearance.m3colors.m3surface;
        }
    }

    function normalizedPercent(value) {
        return Format.isNumber(value) ? Math.max(0, Math.min(1, value / 100)) : -1;
    }

    function diskForDevice(device, fallbackToFirst) {
        const wanted = String(device || "");
        for (let index = 0; index < SystemMonitorService.disks.length; index += 1) {
            const disk = SystemMonitorService.disks[index];
            if (String(disk.device || "") === wanted)
                return disk;
        }
        return fallbackToFirst && SystemMonitorService.disks.length > 0 ? SystemMonitorService.disks[0] : (
                                                                              {});
    }

    function surfaceColor(sidebarBaseColor, defaultColor) {
        if (root.shellManagedSurface)
            return "transparent";

        return BlurService.solidBackgroundColor(defaultColor);
    }

    function temperatureBadge(value) {
        return Format.isNumber(value) ? Math.round(UiPreferences.systemTemperature(value)) + "°" : "";
    }

    function cpuDetail() {
        const physical = SystemIdentityService.physicalCoreCount;
        const logical = SystemIdentityService.logicalCpuCount;
        if (physical > 0 && logical > 0)
            return physical + qsTr(" cores · ") + logical + qsTr(" threads");

        return qsTr("Overall utilization");
    }

    function cpuSupporting() {
        const frequency = Format.frequencyMHz(SystemMonitorService.cpu.frequencyCurrentMHz);
        if (Format.isNumber(SystemMonitorService.cpu.powerWatts))
            return frequency + " · " + Format.watts(SystemMonitorService.cpu.powerWatts);

        return frequency;
    }

    function gpuSupporting() {
        if (SystemMonitorService.selectedGpuId === "")
            return qsTr("No graphics device detected");

        const gpu = root.primaryGpu;
        if (Format.isNumber(gpu.vramUsedBytes) && Format.isNumber(gpu.vramTotalBytes))
            return Format.bytes(gpu.vramUsedBytes) + " / " + Format.bytes(gpu.vramTotalBytes);

        return Format.watts(gpu.powerWatts);
    }

    function tileTitle(id) {
        switch (String(id)) {
        case "time":
            return qsTr("Clock");
        case "battery":
            return qsTr("Battery");
        case "cpu":
            return qsTr("CPU");
        case "gpu":
            return qsTr("GPU");
        case "memoryUsed":
            return qsTr("Memory");
        case "wifi":
            return qsTr("Wi-Fi");
        case "network":
            return qsTr("Network");
        case "storage":
            return qsTr("Disk I/O");
        case "storageCapacity":
            return qsTr("Disk capacity");
        case "calendar":
            return qsTr("Calendar");
        case "weather":
            return qsTr("Weather");
        case "music":
            return qsTr("Now Playing");
        case "notifications":
            return qsTr("Notifications");
        case "notes":
            return qsTr("Notes");
        case "photos":
            return qsTr("Photos");
        default:
            return String(id);
        }
    }

    function componentFor(id) {
        switch (String(id)) {
        case "time":
            return timeComponent;
        case "battery":
            return batteryComponent;
        case "cpu":
            return cpuComponent;
        case "gpu":
            return gpuComponent;
        case "memoryUsed":
            return memoryUsedComponent;
        case "wifi":
            return wifiComponent;
        case "network":
            return networkComponent;
        case "storage":
            return storageComponent;
        case "storageCapacity":
            return storageCapacityComponent;
        case "calendar":
            return calendarComponent;
        case "weather":
            return weatherComponent;
        case "music":
            return musicComponent;
        case "notifications":
            return notificationsComponent;
        case "notes":
            return notesComponent;
        case "photos":
            return photosComponent;
        default:
            return null;
        }
    }

    Rectangle {
        id: rectangularShadowShape

        anchors.fill: parent
        visible: root.usesRectangularShadow
        radius: root.surfaceRadius
        color: root.shadowSurfaceColor
        layer.enabled: visible

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    MaterialShape {
        id: expressiveShadowShape

        anchors.centerIn: parent
        width: Math.max(72, Math.min(parent.width, parent.height) - Appearance.spacing.small)
        height: width
        visible: root.shadowShape >= 0
        shape: root.shadowShape
        color: root.shadowSurfaceColor
        layer.enabled: visible

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: glassSurface

        anchors.fill: parent
        visible: root.shellManagedSurface
        radius: root.surfaceRadius
        color: "transparent"
        antialiasing: true

        // A diagonal, multi-stop gradient is the card material itself.  The
        // Shape keeps the rounded silhouette while the gradient runs corner
        // to corner, which a Rectangle's vertical/horizontal Gradient cannot.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0

                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: glassSurface.width
                    y2: glassSurface.height

                    GradientStop {
                        position: 0
                        color: root.glassGradientStart
                    }

                    GradientStop {
                        position: 0.55
                        color: root.glassGradientMid
                    }

                    GradientStop {
                        position: 1
                        color: root.glassGradientEnd
                    }
                }

                PathRectangle {
                    x: 0
                    y: 0
                    width: glassSurface.width
                    height: glassSurface.height
                    radius: root.surfaceRadius
                }
            }
        }

        // Music album art and the Photos slideshow replace the gradient when
        // the content has an image to contribute.
        Item {
            id: contentBackground

            anchors.fill: parent
            visible: root.contentBackgroundEnabled
            layer.enabled: visible

            layer.effect: GraphicalEffects.OpacityMask {
                maskSource: Rectangle {
                    width: contentBackground.width
                    height: contentBackground.height
                    radius: root.surfaceRadius
                }
            }

            Image {
                anchors.fill: parent
                source: root.contentBackgroundSourceA
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: opacity > 0
                opacity: !root.contentBackgroundIsPhotos || root.contentBackgroundShowA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 650
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Image {
                anchors.fill: parent
                source: root.contentBackgroundSourceB
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: opacity > 0
                opacity: root.contentBackgroundIsPhotos && !root.contentBackgroundShowA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 650
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.tileId === "music"
                color: Qt.rgba(0, 0, 0, 0.50)
            }

            Rectangle {
                anchors.fill: parent
                visible: root.contentBackgroundIsPhotos

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 0.45
                        color: Qt.rgba(0, 0, 0, 0.06)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.80)
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.surfaceRadius
            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                GradientStop {
                    position: 0.35
                    color: Qt.rgba(1, 1, 1, 0.04)
                }

                GradientStop {
                    position: 0.62
                    color: "transparent"
                }
            }
        }

        GlassHighlight {
            anchors.fill: parent
            radius: root.surfaceRadius
            topStrength: 0.14 + root.interactionProgress * 0.08
            bottomStrength: 0.035
        }
    }

    Loader {
        id: contentLoader

        z: 1
        anchors.fill: parent
        sourceComponent: root.componentFor(root.tileId)
    }

    // Keep the hairline above the card content so a full-bleed image or the
    // calendar header cannot hide the widget edge.
    Rectangle {
        z: 2
        anchors.fill: parent
        visible: root.shellManagedSurface
        radius: root.surfaceRadius
        color: "transparent"
        border.width: 1
        border.color: root.glassBorderColor
        antialiasing: true
    }

    Component {
        id: timeComponent

        SystemClockCard {
            active: root.active
            glassSurface: root.shellManagedSurface
            glassForeground: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            glassSecondaryForeground: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            glassAccent: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: batteryComponent

        SystemBatteryTank {
            glassSurface: root.shellManagedSurface
            containerColor: root.shellManagedSurface ? root.glassPanelColor : root.surfaceColor(
                                                           Appearance.m3colors.m3secondaryContainer,
                                                           Appearance.colors.colSecondaryContainer)
            // The battery fill is data visualization, not the card surface;
            // keep it visible while the surrounding tank is transparent.
            levelColor: root.shellManagedSurface ? Qt.rgba(0, 0, 0, 0.24) : root.surfaceColor(Appearance.m3colors.m3secondary,
                                                                                              Appearance.colors.colSecondary)
            foregroundColor: root.shellManagedSurface ? root.glassForeground :
                                                        Appearance.colors.colOnSecondaryContainer
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.applyAlpha(
                                                                     Appearance.colors.colOnSecondaryContainer,
                                                                     0.78)
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colSecondary
        }
    }

    Component {
        id: cpuComponent

        ExpressiveMetricTile {
            glassSurface: root.shellManagedSurface
            label: qsTr("CPU")
            iconName: "memory"
            detailText: root.cpuDetail()
            valueText: Format.percent(SystemMonitorService.cpu.usagePercent, 0)
            supportingText: root.cpuSupporting()
            temperatureText: root.temperatureBadge(root.cpuTemperature)
            usage: root.normalizedPercent(SystemMonitorService.cpu.usagePercent)
            trendValues: SystemMonitorService.cpuHistory
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            decorationSize: 50
            valueSize: root.shellManagedSurface ? 34 : Typography.headlineMedium.pixelSize
            containerColor: root.surfaceColor(Appearance.m3colors.m3primaryContainer,
                                              Appearance.colors.colPrimaryContainer)
            foregroundColor: root.shellManagedSurface ? root.glassForeground :
                                                        Appearance.colors.colOnPrimaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
            accentForegroundColor: root.shellManagedSurface ? root.glassForeground :
                                                              Appearance.colors.colOnPrimary
        }
    }

    Component {
        id: gpuComponent

        ExpressiveMetricTile {
            glassSurface: root.shellManagedSurface
            label: qsTr("GPU")
            iconName: "developer_board"
            detailText: root.primaryGpu.name || qsTr("Graphics device")
            valueText: SystemMonitorService.selectedGpuId !== "" ? Format.percent(
                                                                       root.primaryGpu.utilizationPercent, 0) :
                                                                   "—"
            supportingText: root.gpuSupporting()
            temperatureText: root.temperatureBadge(root.primaryGpu.temperatureCelsius)
            usage: SystemMonitorService.selectedGpuId !== "" ? root.normalizedPercent(
                                                                   root.primaryGpu.utilizationPercent) : -1
            trendValues: SystemMonitorService.gpuHistory
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            shapeOverride: MaterialShape.Gem
            decorationSize: 50
            valueSize: root.shellManagedSurface ? 34 : Typography.headlineMedium.pixelSize
            containerColor: root.surfaceColor(Appearance.m3colors.m3secondaryContainer,
                                              Appearance.colors.colSecondaryContainer)
            foregroundColor: root.shellManagedSurface ? root.glassForeground :
                                                        Appearance.colors.colOnSecondaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colSecondary
            accentForegroundColor: root.shellManagedSurface ? root.glassForeground :
                                                              Appearance.colors.colOnSecondary
        }
    }

    Component {
        id: memoryUsedComponent

        SystemLiquidMetricCard {
            glassSurface: root.shellManagedSurface
            title: root.tileTitle(root.tileId)
            iconName: "memory_alt"
            valueText: Format.percent(SystemMonitorService.memory.usagePercent, 0)
            supportingText: Format.bytes(SystemMonitorService.memory.usedBytes) + " / " + Format.bytes(
                                SystemMonitorService.memory.totalBytes)
            level: root.normalizedPercent(SystemMonitorService.memory.usagePercent)
            valueAvailable: Format.isNumber(SystemMonitorService.memory.usagePercent)
            accessibilityName: qsTr("Memory used ") + Format.percent(SystemMonitorService.memory.usagePercent,
                                                                     0) + "，" + Format.bytes(
                                   SystemMonitorService.memory.usedBytes) + " / " + Format.bytes(
                                   SystemMonitorService.memory.totalBytes)
            shapeId: MaterialShape.Slanted
            shapeColor: root.surfaceColor(Appearance.m3colors.m3primaryContainer,
                                          Appearance.colors.colPrimaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.66)
            contentColor: root.shellManagedSurface ? root.glassForeground :
                                                     Appearance.colors.colOnPrimaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colTertiary
            accentBackgroundColor: root.shellManagedSurface ? root.glassAccentBackground :
                                                              Appearance.applyAlpha(root.contentColor, 0.10)
        }
    }

    Component {
        id: wifiComponent

        SystemLiquidMetricCard {
            glassSurface: root.shellManagedSurface
            title: root.tileTitle(root.tileId)
            iconName: NetworkService.wifiConnected ? "wifi" : "wifi_off"
            valueText: NetworkService.wifiConnected ? Format.percent(NetworkService.signalStrength, 0) : "—"
            supportingText: qsTr("Wi-Fi signal strength")
            level: root.normalizedPercent(NetworkService.signalStrength)
            valueAvailable: NetworkService.wifiConnected
            accessibilityName: NetworkService.wifiConnected ? qsTr("Wi-Fi signal strength ") + Format.percent(
                                                                  NetworkService.signalStrength, 0) : qsTr(
                                                                  "Wi-Fi is not connected")
            shapeId: MaterialShape.Pentagon
            shapeColor: root.surfaceColor(Appearance.m3colors.m3tertiaryContainer,
                                          Appearance.colors.colTertiaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colTertiary, 0.64)
            contentColor: root.shellManagedSurface ? root.glassForeground :
                                                     Appearance.colors.colOnTertiaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colTertiary
            accentBackgroundColor: root.shellManagedSurface ? root.glassAccentBackground :
                                                              Appearance.applyAlpha(root.contentColor, 0.10)
        }
    }

    Component {
        id: networkComponent

        SystemNetworkCard {
            glassSurface: root.shellManagedSurface
            network: SystemMonitorService.network
            aggregateDownloadHistory: SystemMonitorService.networkDownloadHistory
            aggregateUploadHistory: SystemMonitorService.networkUploadHistory
            downloadHistories: NetworkInterfaceHistoryService.downloadHistories
            uploadHistories: NetworkInterfaceHistoryService.uploadHistories
            preferredInterface: UiPreferences.systemMonitorNetworkInterface
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            surfaceColor: root.surfaceColor(Appearance.m3colors.m3primary, Appearance.colors.colPrimary)
            panelColor: root.shellManagedSurface ? root.glassPanelColor : root.surfaceColor(
                                                       Appearance.m3colors.m3primaryContainer,
                                                       Appearance.colors.colPrimaryContainer)
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnPrimary
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnPrimaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colTertiary
            onInterfaceSelected: networkInterface => {
                                     return UiPreferences.setSystemMonitorNetworkInterface(networkInterface);
                                 }
        }
    }

    Component {
        id: storageComponent

        SystemStorageCard {
            glassSurface: root.shellManagedSurface
            disks: SystemMonitorService.disks
            readHistories: SystemMonitorService.diskReadHistories
            writeHistories: SystemMonitorService.diskWriteHistories
            preferredDiskDevice: UiPreferences.systemMonitorDiskDevice
            chartActive: root.active
            updateInterval: root.chartUpdateInterval
            surfaceColor: root.surfaceColor(Appearance.m3colors.m3tertiary, Appearance.colors.colTertiary)
            panelColor: root.shellManagedSurface ? root.glassPanelColor : root.surfaceColor(
                                                       Appearance.m3colors.m3tertiaryContainer,
                                                       Appearance.colors.colTertiaryContainer)
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnTertiary
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnPrimaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
            onDiskSelected: device => {
                                return UiPreferences.setSystemMonitorDiskDevice(device);
                            }
        }
    }

    Component {
        id: storageCapacityComponent

        SystemLiquidMetricCard {
            glassSurface: root.shellManagedSurface
            title: root.tileTitle(root.tileId)
            readonly property bool diskAvailable: String(root.capacityDisk.device || "") !== ""
            readonly property bool capacityAvailable: diskAvailable && Format.isNumber(
                                                          root.capacityDisk.usagePercent)

            iconName: "data_usage"
            valueText: capacityAvailable ? Format.percent(root.capacityDisk.usagePercent, 0) : "—"
            supportingText: diskAvailable ? Format.bytes(root.capacityDisk.usedBytes) + " / " + Format.bytes(
                                                root.capacityDisk.totalBytes) : qsTr("No disk detected")
            level: root.normalizedPercent(root.capacityDisk.usagePercent)
            valueAvailable: capacityAvailable
            accessibilityName: diskAvailable ? qsTr("Disk %1, %2 of %3 used, %4 occupied").arg(String(
                                                                                                   root.capacityDisk.device)).arg(
                                                   Format.bytes(root.capacityDisk.usedBytes)).arg(Format.bytes(
                                                                                                      root.capacityDisk.totalBytes)).arg(
                                                   Format.percent(root.capacityDisk.usagePercent, 0)) : qsTr(
                                                   "No disk detected")
            shapeId: MaterialShape.Cookie9Sided
            shapeColor: root.surfaceColor(Appearance.m3colors.m3secondaryContainer,
                                          Appearance.colors.colSecondaryContainer)
            liquidColor: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.66)
            contentColor: root.shellManagedSurface ? root.glassForeground :
                                                     Appearance.colors.colOnSecondaryContainer
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
            accentBackgroundColor: root.shellManagedSurface ? root.glassAccentBackground :
                                                              Appearance.applyAlpha(root.contentColor, 0.10)
        }
    }

    Component {
        id: calendarComponent

        SystemCalendarCard {
            active: root.active
            glassSurface: root.shellManagedSurface
            surfaceColor: root.shellManagedSurface ? "transparent" : root.surfaceColor(
                                                         Appearance.m3colors.m3surfaceContainerHigh,
                                                         Appearance.colors.colSurfaceContainerHigh)
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: weatherComponent

        SystemWeatherCard {
            glassSurface: root.shellManagedSurface
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: musicComponent

        SystemMusicCard {
            glassSurface: root.shellManagedSurface
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: notificationsComponent

        SystemNotificationsCard {
            glassSurface: root.shellManagedSurface
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: notesComponent

        SystemNotesCard {
            glassSurface: root.shellManagedSurface
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }

    Component {
        id: photosComponent

        SystemPhotosCard {
            glassSurface: root.shellManagedSurface
            foregroundColor: root.shellManagedSurface ? root.glassForeground : Appearance.colors.colOnSurface
            secondaryForegroundColor: root.shellManagedSurface ? root.glassSecondaryForeground :
                                                                 Appearance.colors.colOnSurfaceVariant
            accentColor: root.shellManagedSurface ? root.glassAccent : Appearance.colors.colPrimary
        }
    }
}
