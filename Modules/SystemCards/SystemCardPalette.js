.pragma library

// iPadOS-style full-color widget palettes. Most utility widgets use the
// adaptive neutral card supplied by SystemCardContent and reserve this color
// for data emphasis. Weather and media opt into full-color surfaces.
var palettes = {
    "time": {
        "style": "neutral",
        "start": "#1C1C1E",
        "mid": "#2C2C2E",
        "end": "#3A3A3C",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#0A84FF",
        "accentBackground": "#220A84FF"
    },
    "battery": {
        "style": "neutral",
        "start": "#34C759",
        "mid": "#238C40",
        "end": "#0F6B2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#B9F6C8",
        "accentBackground": "#29FFFFFF"
    },
    "cpu": {
        "style": "neutral",
        "start": "#0A84FF",
        "mid": "#0066CC",
        "end": "#0040A0",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#64D2FF",
        "accentBackground": "#29FFFFFF"
    },
    "gpu": {
        "style": "neutral",
        "start": "#BF5AF2",
        "mid": "#8E3DC4",
        "end": "#6A1B9A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#E7B8FF",
        "accentBackground": "#29FFFFFF"
    },
    "memoryUsed": {
        "style": "neutral",
        "start": "#FF9F0A",
        "mid": "#D97A00",
        "end": "#B25000",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFD60A",
        "accentBackground": "#29FFFFFF"
    },
    "wifi": {
        "style": "neutral",
        "start": "#30D158",
        "mid": "#1EA443",
        "end": "#0A6B2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#B9F6C8",
        "accentBackground": "#29FFFFFF"
    },
    "network": {
        "style": "neutral",
        "start": "#5E5CE6",
        "mid": "#4140B8",
        "end": "#26248F",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#A9A7FF",
        "accentBackground": "#29FFFFFF"
    },
    "storage": {
        "style": "neutral",
        "start": "#FF9F0A",
        "mid": "#E07F00",
        "end": "#C25E00",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFD60A",
        "accentBackground": "#29FFFFFF"
    },
    "storageCapacity": {
        "style": "neutral",
        "start": "#FF453A",
        "mid": "#C7342A",
        "end": "#8F1A14",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFB4AB",
        "accentBackground": "#29FFFFFF"
    },
    "calendar": {
        "style": "neutral",
        "start": "#FF375F",
        "mid": "#C92847",
        "end": "#8F0F2A",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFB3C1",
        "accentBackground": "#29FFFFFF"
    },
    "weather": {
        "style": "fullColor",
        "start": "#2E7CC6",
        "mid": "#4A8FCE",
        "end": "#7EB8E8",
        "foreground": "#FFFFFF",
        "secondary": "#D9FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#29FFFFFF"
    },
    "music": {
        "style": "media",
        "start": "#BF5AF2",
        "mid": "#D147B0",
        "end": "#FF375F",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#29FFFFFF"
    },
    "notifications": {
        "style": "neutral",
        "start": "#3A3A3C",
        "mid": "#2A2A2C",
        "end": "#1C1C1E",
        "foreground": "#FFFFFF",
        "secondary": "#C7FFFFFF",
        "accent": "#FFFFFF",
        "accentBackground": "#26FFFFFF"
    },
    "notes": {
        "style": "paper",
        "start": "#FFFFFF",
        "mid": "#FFFFFF",
        "end": "#FFFFFF",
        "foreground": "#1C1C1E",
        "secondary": "#8E8E93",
        "accent": "#FFD60A",
        "accentBackground": "#33FFD60A"
    },
    "photos": {
        "style": "media",
        "start": "#FFFFFF",
        "mid": "#FFFFFF",
        "end": "#FFFFFF",
        "foreground": "#1C1C1E",
        "secondary": "#8E8E93",
        "accent": "#007AFF",
        "accentBackground": "#22007AFF"
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
