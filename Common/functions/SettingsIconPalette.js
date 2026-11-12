.pragma library

var systemBlue = "#0A84FF";
var systemGreen = "#30D158";
var systemIndigo = "#5E5CE6";
var systemOrange = "#FF9F0A";
var systemPink = "#FF375F";
var systemPurple = "#BF5AF2";
var systemRed = "#FF453A";
var systemTeal = "#64D2FF";
var systemGray = "#8E8E93";

function backgroundFor(iconName) {
    switch (String(iconName || "")) {
    case "account_circle":
    case "person":
    case "badge":
        return systemGray;
    case "wifi":
    case "network_wifi":
    case "bluetooth":
    case "devices_other":
    case "monitor":
    case "display_settings":
        return systemBlue;
    case "wallpaper":
    case "image":
    case "photo_library":
        return systemGreen;
    case "palette":
    case "blur_on":
    case "auto_awesome":
        return systemPurple;
    case "smart_toy":
    case "android":
    case "apps":
    case "rocket_launch":
        return systemIndigo;
    case "dock_to_bottom":
    case "side_navigation":
    case "dashboard_customize":
    case "widgets":
        return systemTeal;
    case "keyboard":
    case "language":
    case "translate":
        return systemOrange;
    case "notifications":
    case "volume_up":
    case "mic":
        return systemRed;
    case "schedule":
    case "calendar_month":
    case "timer":
        return systemPink;
    case "security":
    case "key":
    case "lock":
        return systemGreen;
    case "settings":
    case "settings_suggest":
    case "tune":
    case "build":
        return systemGray;
    default:
        return systemBlue;
    }
}

function foregroundFor(iconName) {
    return "#FFFFFF";
}
