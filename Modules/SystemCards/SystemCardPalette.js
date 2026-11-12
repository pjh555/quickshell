.pragma library

// Apple-inspired widget palettes.  Each system card owns a saturated two- or
// three-stop gradient, a foreground tuned for that gradient, and an accent
// used by the icon badge and chart strokes.  Values are QML color strings so
// the palette also works from the plain-JS catalog path.
var palettes = {
    "time": {
        "start": "#1C1C1E",
        "mid": "#2C2C2E",
        "end": "#3A3A3C",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#64D2FF",
        "accentBackground": "#29FFFFFF"
    },
    "battery": {
        "start": "#34C759",
        "mid": "#238C40",
        "end": "#0F6B2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#B9F6C8",
        "accentBackground": "#29FFFFFF"
    },
    "cpu": {
        "start": "#0A84FF",
        "mid": "#0066CC",
        "end": "#0040A0",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#64D2FF",
        "accentBackground": "#29FFFFFF"
    },
    "gpu": {
        "start": "#BF5AF2",
        "mid": "#8E3DC4",
        "end": "#6A1B9A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#E7B8FF",
        "accentBackground": "#29FFFFFF"
    },
    "memoryUsed": {
        "start": "#FF9F0A",
        "mid": "#D97A00",
        "end": "#B25000",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFD60A",
        "accentBackground": "#29FFFFFF"
    },
    "wifi": {
        "start": "#30D158",
        "mid": "#1EA443",
        "end": "#0A6B2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#B9F6C8",
        "accentBackground": "#29FFFFFF"
    },
    "network": {
        "start": "#5E5CE6",
        "mid": "#4140B8",
        "end": "#26248F",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#A9A7FF",
        "accentBackground": "#29FFFFFF"
    },
    "storage": {
        "start": "#FF9F0A",
        "mid": "#E07F00",
        "end": "#C25E00",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFD60A",
        "accentBackground": "#29FFFFFF"
    },
    "storageCapacity": {
        "start": "#FF453A",
        "mid": "#C7342A",
        "end": "#8F1A14",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFB4AB",
        "accentBackground": "#29FFFFFF"
    },
    "calendar": {
        "start": "#FF375F",
        "mid": "#C92847",
        "end": "#8F0F2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFB3C1",
        "accentBackground": "#29FFFFFF"
    },
    "weather": {
        "start": "#0A84FF",
        "mid": "#0A6BC9",
        "end": "#0055A5",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#A6D8FF",
        "accentBackground": "#29FFFFFF"
    },
    "music": {
        "start": "#BF5AF2",
        "mid": "#D147B0",
        "end": "#FF375F",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#29FFFFFF"
    },
    "notifications": {
        "start": "#3A3A3C",
        "mid": "#2A2A2C",
        "end": "#1C1C1E",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#26FFFFFF"
    },
    "notes": {
        // Apple Notes yellow with dark brown type; the warm gradient keeps
        // the card colorful without washing out the white-on-dark family.
        "start": "#FFD60A",
        "mid": "#F5B800",
        "end": "#C77800",
        "foreground": "#2B1D00",
        "secondary": "#B32B1D00",
        "accent": "#8A4B00",
        "accentBackground": "#4DFFFFFF"
    },
    "photos": {
        "start": "#0A84FF",
        "mid": "#0F9E9A",
        "end": "#30D158",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#29FFFFFF"
    }
};

var defaultPalette = palettes.time;

var appColors = ["#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#BF5AF2", "#5E5CE6", "#64D2FF",
    "#FFD60A", "#FF453A", "#32ADE6"];

function paletteFor(id) {
    var palette = palettes[String(id)];
    return palette ? palette : defaultPalette;
}

// Deterministic app tint for notification rows.  The same app always gets the
// same Apple system color, so the circles read as app identity rather than
// random decoration.
function appColorFor(name) {
    var value = String(name || "");
    var hash = 0;
    for (var index = 0; index < value.length; index += 1)
        hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
    return appColors[hash % appColors.length];
}
