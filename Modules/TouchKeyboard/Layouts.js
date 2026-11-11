.pragma library

// Gboard-style key data for the Clavis touch keyboard.
//
// Gboard-style proportions implemented directly for Clavis: ten-column
// QWERTY, swipe-up numbers or punctuation on the letter rows, and a compact
// function/symbol surface.  The layout is plain immutable QML model data so
// the window component stays focused on presentation and input handling.

var accentVariants = {
    "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
    "c": ["ç", "ć", "č"],
    "d": ["ď", "đ"],
    "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
    "g": ["ğ"],
    "h": ["ĥ"],
    "i": ["î", "ï", "í", "ì", "ī", "į"],
    "j": ["ĵ"],
    "k": ["ķ"],
    "l": ["ł", "ĺ", "ľ"],
    "n": ["ñ", "ń"],
    "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
    "r": ["ŕ", "ř"],
    "s": ["ß", "ś", "š"],
    "t": ["ť", "þ"],
    "u": ["û", "ü", "ù", "ú", "ū"],
    "w": ["ŵ"],
    "y": ["ý", "ÿ"],
    "z": ["ź", "ž", "ż"]
};

function longPressFor(letter) {
    var variants = accentVariants[letter];
    if (!variants || variants.length === 0)
        return [];

    var options = [{
            "label": letter,
            "action": "commit",
            "value": letter
        }];
    for (var index = 0; index < variants.length; ++index) {
        options.push({
            "label": variants[index],
            "action": "commit",
            "value": variants[index]
        });
    }
    return options;
}

function letterKey(letter, swipeValue) {
    var result = {
        "id": letter,
        "label": letter,
        "action": "char",
        "value": letter
    };
    var options = longPressFor(letter);
    if (options.length > 0)
        result.longPress = options;
    if (swipeValue !== undefined && swipeValue !== "") {
        result.sublabel = swipeValue;
        result.swipeUp = {
            "action": "commit",
            "value": swipeValue
        };
    }
    return result;
}

function letterRow(letters, swipeValues) {
    var result = [];
    for (var index = 0; index < letters.length; ++index)
        result.push(letterKey(letters[index], swipeValues ? swipeValues[index] : ""));
    return result;
}

function punct(label, value, options, style, weight) {
    var result = {
        "id": "punct_" + value,
        "label": label,
        "action": "char",
        "value": value,
        "style": style || "normal",
        "weight": weight || 1
    };
    if (options && options.length > 0) {
        result.longPress = [];
        for (var index = 0; index < options.length; ++index) {
            result.longPress.push({
                "label": options[index],
                "action": "commit",
                "value": options[index]
            });
        }
    }
    return result;
}

function iconKey(id, icon, action, value, weight, style, round) {
    return {
        "id": id,
        "icon": icon,
        "action": action,
        "value": value || "",
        "weight": weight || 1,
        "style": style || "normal",
        "round": round === true
    };
}

function actionKey(id, label, action, value, weight, style, icon) {
    var result = {
        "id": id,
        "label": label || "",
        "action": action,
        "value": value || "",
        "weight": weight || 1,
        "style": style || "normal"
    };
    if (icon !== undefined && icon !== "")
        result.icon = icon;
    return result;
}

function backspaceKey(weight) {
    var result = iconKey("backspace", "backspace", "backspace", "", weight || 1.5, "special");
    result.repeat = true;
    result.swipeUp = {
        "action": "clear"
    };
    return result;
}

function shiftKey() {
    var result = iconKey("shift", "keyboard_capslock", "shift", "", 1.5, "special");
    result.doubleTap = {
        "action": "capslock"
    };
    return result;
}

var modeLongPress = [{
        "label": "123",
        "action": "numbers"
    }, {
        "label": "?123",
        "action": "symbols"
    }, {
        "label": "Fn",
        "action": "keys"
    }];

var qwertyRows = [
    letterRow("qwertyuiop".split(""), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
    letterRow("asdfghjkl".split(""), ["~", ":", ";", "\"", "'", "-", "+", "=", "/"]),
    [shiftKey(), letterKey("z", "\\"),
        letterKey("x", "|"), letterKey("c", "["), letterKey("v", "]"), letterKey("b", "{"),
        letterKey("n", "}"), letterKey("m", "<"),
        backspaceKey(1.5)],
    [actionKey("home", "Home", "home", "", 1, "special"),
        iconKey("left", "arrow_back", "left", "", 1, "special"),
        iconKey("up", "arrow_upward", "up", "", 1, "special"),
        iconKey("down", "arrow_downward", "down", "", 1, "special"),
        iconKey("right", "arrow_forward", "right", "", 1, "special"),
        actionKey("end", "End", "end", "", 1, "special"),
        actionKey("pageup", "PgUp", "pageup", "", 1, "special"),
        actionKey("pagedown", "PgDn", "pagedown", "", 1, "special"),
        actionKey("delete", "Del", "delete", "", 1.2, "special")],
    [{
            "id": "symbols",
            "label": "?123",
            "action": "symbols",
            "weight": 1.3,
            "style": "special",
            "round": true,
            "longPress": modeLongPress
        }, {
            "id": "comma",
            "label": ",",
            "chineseLabel": "，",
            "action": "char",
            "value": ",",
            "weight": 1,
            "sublabel": "😊",
            "swipeUp": {
                "action": "emoji"
            },
            "longPress": [{
                    "label": ",",
                    "action": "commit",
                    "value": ","
                }, {
                    "label": "，",
                    "action": "commit",
                    "value": "，"
                }, {
                    "label": "、",
                    "action": "commit",
                    "value": "、"
                }]
        }, {
            "id": "language",
            "action": "language",
            "weight": 1,
            "style": "flat"
        }, {
            "id": "space",
            "action": "space",
            "weight": 3.7,
            "style": "flat"
        }, {
            "id": "period",
            "label": ".",
            "chineseLabel": "。",
            "action": "char",
            "value": ".",
            "weight": 1,
            "longPress": [{
                    "label": ".",
                    "action": "commit",
                    "value": "."
                }, {
                    "label": "。",
                    "action": "commit",
                    "value": "。"
                }, {
                    "label": "…",
                    "action": "commit",
                    "value": "…"
                }, {
                    "label": "！",
                    "action": "commit",
                    "value": "！"
                }, {
                    "label": "？",
                    "action": "commit",
                    "value": "？"
                }]
        }, iconKey("enter", "keyboard_return", "enter", "", 2, "accent", true)]
];

var symbolRows = [
    [punct("1", "1"), punct("2", "2"), punct("3", "3"), punct("4", "4"), punct("5", "5"),
        punct("6", "6"), punct("7", "7"), punct("8", "8"), punct("9", "9"), punct("0", "0")],
    [punct("@", "@", ["@", "＠"]), punct("#", "#", ["#", "＃"]), punct("$", "$", ["$", "＄", "€", "£", "¥"]),
        punct("&", "&", ["&", "＆"]), punct("_", "_", ["_", "＿"]), punct("-", "-", ["-", "－", "–", "—"]),
        punct("+", "+", ["+", "＋", "±"]), punct("(", "(", ["(", "（", "["]), punct(")", ")", [")", "）", "]"]),
        punct("/", "/", ["/", "／", "\\", "|"])],
    [actionKey("open_symbols", "#+=", "open_symbols", "", 1.3, "special"),
        punct("＊", "＊", ["＊", "*", "×"]), punct("“", "“", ["“", "‘", "«"]),
        punct("”", "”", ["”", "’", "»"]), punct("！", "！", ["！", "!"]),
        punct("？", "？", ["？", "?"]), punct(",", ",", [",", "，", "、"]), punct(".", ".", [".", "。", "…"]),
        backspaceKey(1.2)],
    [actionKey("letters", "ABC", "letters", "", 1.2, "special"),
        actionKey("number", "123", "numbers", "", 1, "special"),
        actionKey("space", "", "space", "", 2.5, "flat", "space_bar"),
        iconKey("enter", "keyboard_return", "enter", "", 1.5, "accent", true)]
];

var numberPadLeft = [actionKey("plus", "+", "char", "+", 1, "special"),
    actionKey("minus", "-", "char", "-", 1, "special"),
    actionKey("multiply", "*", "char", "*", 1, "special"),
    actionKey("divide", "/", "char", "/", 1, "special"),
    iconKey("back", "arrow_back", "letters", "", 1, "special")];

var numberPadCenterRows = [
    [actionKey("n1", "1", "digit", "1"), actionKey("n2", "2", "digit", "2"), actionKey("n3", "3", "digit",
                                                                                          "3")],
    [actionKey("n4", "4", "digit", "4"), actionKey("n5", "5", "digit", "5"), actionKey("n6", "6", "digit",
                                                                                          "6")],
    [actionKey("n7", "7", "digit", "7"), actionKey("n8", "8", "digit", "8"), actionKey("n9", "9", "digit",
                                                                                          "9")],
    [actionKey("open_symbols", "#+=", "open_symbols", "", 1, "special"),
        actionKey("n0", "0", "digit", "0"), actionKey("dot", ".", "char", ".")]
];

var numberPadRight = [backspaceKey(1), actionKey("space", "", "space", "", 1, "flat", "space_bar"),
    actionKey("emoji", "😊", "emoji", "", 1, "special"),
    iconKey("enter", "keyboard_return", "enter", "", 1, "accent", true)];

var nineDigitRows = [
    [{
            "id": "nine_1",
            "label": "1",
            "sublabel": "?123",
            "action": "symbols",
            "longPress": [{
                    "label": "1",
                    "action": "digit",
                    "value": "1"
                }, {
                    "label": "，",
                    "action": "commit",
                    "value": "，"
                }]
        }, {
            "id": "nine_2",
            "label": "ABC",
            "sublabel": "2",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "2",
            "longPress": [{
                    "label": "2",
                    "action": "digit",
                    "value": "2"
                }]
        }, {
            "id": "nine_3",
            "label": "DEF",
            "sublabel": "3",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "3",
            "longPress": [{
                    "label": "3",
                    "action": "digit",
                    "value": "3"
                }]
        }],
    [{
            "id": "nine_4",
            "label": "GHI",
            "sublabel": "4",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "4",
            "longPress": [{
                    "label": "4",
                    "action": "digit",
                    "value": "4"
                }]
        }, {
            "id": "nine_5",
            "label": "JKL",
            "sublabel": "5",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "5",
            "longPress": [{
                    "label": "5",
                    "action": "digit",
                    "value": "5"
                }]
        }, {
            "id": "nine_6",
            "label": "MNO",
            "sublabel": "6",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "6",
            "longPress": [{
                    "label": "6",
                    "action": "digit",
                    "value": "6"
                }]
        }],
    [{
            "id": "nine_7",
            "label": "PQRS",
            "sublabel": "7",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "7",
            "longPress": [{
                    "label": "7",
                    "action": "digit",
                    "value": "7"
                }]
        }, {
            "id": "nine_8",
            "label": "TUV",
            "sublabel": "8",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "8",
            "longPress": [{
                    "label": "8",
                    "action": "digit",
                    "value": "8"
                }]
        }, {
            "id": "nine_9",
            "label": "WXYZ",
            "sublabel": "9",
            "sublabelPosition": "bottom",
            "action": "nine",
            "value": "9",
            "longPress": [{
                    "label": "9",
                    "action": "digit",
                    "value": "9"
                }]
        }]
];

var nineBottomRow = [{
        "id": "numbers",
        "label": "123",
        "action": "numbers",
        "style": "special",
        "weight": 0.8
    }, {
        "id": "space",
        "icon": "space_bar",
        "action": "space",
        "weight": 1.7,
        "style": "flat"
    }, {
        "id": "language",
        "action": "language",
        "style": "flat",
        "weight": 0.8
    }];

var ninePunctuation = ["，", "。", "？", "！"];

var functionRows = [
    [actionKey("escape", "Esc", "escape", "", 1, "special"), actionKey("tab", "Tab", "tab", "", 1,
                                                                      "special"),
        actionKey("ctrl", "Ctrl", "ctrl", "", 1, "special"), actionKey("alt", "Alt", "alt", "", 1,
                                                                      "special"),
        actionKey("super", "Super", "super", "", 1, "special"), actionKey("delete", "Del", "delete", "", 1,
                                                                         "special"),
        actionKey("home", "Home", "home", "", 1, "special"), actionKey("end", "End", "end", "", 1,
                                                                      "special"),
        actionKey("pageup", "PgUp", "pageup", "", 1, "special"), actionKey("pagedown", "PgDn", "pagedown",
                                                                          "", 1, "special")],
    [actionKey("f1", "F1", "key", "F1"), actionKey("f2", "F2", "key", "F2"), actionKey("f3", "F3", "key", "F3"),
        actionKey("f4", "F4", "key", "F4"), actionKey("f5", "F5", "key", "F5"), actionKey("f6", "F6", "key", "F6"),
        actionKey("f7", "F7", "key", "F7"), actionKey("f8", "F8", "key", "F8"), actionKey("f9", "F9", "key", "F9"),
        actionKey("f10", "F10", "key", "F10")],
    [actionKey("f11", "F11", "key", "F11"), actionKey("f12", "F12", "key", "F12"),
        actionKey("insert", "Ins", "insert", "", 1, "special"), actionKey("print", "PrtSc", "print", "", 1,
                                                                          "special"),
        actionKey("menu", "Menu", "menu", "", 1, "special"),
        iconKey("left", "arrow_back", "left", "", 1, "special"),
        iconKey("up", "arrow_upward", "up", "", 1, "special"),
        iconKey("down", "arrow_downward", "down", "", 1, "special"),
        iconKey("right", "arrow_forward", "right", "", 1, "special"), backspaceKey(1)],
    [actionKey("letters", "ABC", "letters", "", 1.2, "special"),
        actionKey("shift", "Shift", "shift", "", 1.2, "special"),
        actionKey("space", "", "space", "", 5.6, "flat", "space_bar"),
        iconKey("enter", "keyboard_return", "enter", "", 2, "accent", true)]
];

var emojiCategories = [{
        "icon": "😀",
        "emojis": "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👻 💀".split(" ")
    }, {
        "icon": "🐶",
        "emojis": "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🦗 🕷 🦂 🐢 🐍 🦎 🦖 🐙 🦑 🦐 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍 🐘 🦛 🦏 🐪 🐫 🦒 🦘 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🦙 🐐 🦌 🐕 🐩 🐈 🐓 🦃 🦚 🦜 🦢 🕊 🐇 🦝 🦨 🦡 🦦 🦥 🐁 🐀 🐿 🦔".split(" ")
    }, {
        "icon": "🍎",
        "emojis": "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶 🥕 🧄 🧅 🌽 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 🥩 🍗 🍖 🦴 🌭 🍔 🍟 🍕 🥪 🥙 🧆 🌮 🌯 🥗 🥘 🥫 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🦪 🍤 🍙 🍚 🍘 🍥 🥠 🥮 🍢 🍡 🍧 🍨 🍦 🥧 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 🌰 🥜 🍯 🥛 🍼 ☕ 🍵 🧃 🥤 🍶 🍺 🍻 🥂 🍷 🥃 🍸 🍹 🧉 🍾".split(" ")
    }, {
        "icon": "⚽",
        "emojis": "⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒 🏑 🥍 🏏 🪃 🥅 ⛳ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹 🛷 ⛸ 🥌 🎿 ⛷ 🏂 🪂 🏋️ 🤼 🤸 ⛹️ 🤺 🤾 🏌️ 🏇 🧘 🏄 🏊 🤽 🚣 🧗 🚵 🚴 🏆 🥇 🥈 🥉 🏅 🎖 🏵 🎗 🎫 🎟 🎪 🤹 🎭 🩰 🎨 🎬 🎤 🎧 🎼 🎹 🥁 🪘 🎷 🎺 🪗 🎸 🪕 🎻 🎲 ♟ 🎯 🎳 🎮 🎰 🧩".split(" ")
    }, {
        "icon": "🚗",
        "emojis": "🚗 🚕 🚙 🚌 🚎 🏎 🚓 🚑 🚒 🚐 🚚 🚛 🚜 🦯 🦽 🦼 🛴 🚲 🛵 🏍 🛺 🚨 🚔 🚍 🚘 🚖 🚡 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉 ✈️ 🛫 🛬 🛩 💺 🛰 🚀 🛸 🚁 🛶 ⛵ 🚤 🛥 🛳 ⛴ 🚢 ⚓ 🪝 ⛽ 🚧 🚦 🚥 🚏 🗺 🗿 🗽 🗼 🏰 🏯 🏟 🎡 🎢 🎠 ⛲ ⛱ 🏖 🏝 🏜 🌋 ⛰ 🏔 🗻 🏕 ⛺ 🛖 🏠 🏡 🏘 🏚 🏗 🏭 🏢 🏬 🏣 🏤 🏥 🏦 🏨 🏪 🏫 🏩 💒 🏛 ⛪ 🕌 🕍 🛕 🕋 ⛩ 🛤 🛣 🗾 🎑 🏞 🌅 🌄 🌠 🎇 🎆 🌇 🌆 🏙 🌃 🌌 🌉 🌁".split(" ")
    }, {
        "icon": "💡",
        "emojis": "⌚ 📱 💻 ⌨️ 🖥 🖨 🖱 🖲 🕹 🗜 💽 💾 💿 📀 📼 📷 📸 📹 🎥 📽 🎞 📞 ☎️ 📟 📠 📺 📻 🎙 🎚 🎛 🧭 ⏱ ⏲ ⏰ 🕰 ⌛ ⏳ 📡 🔋 🔌 💡 🔦 🕯 🪔 🧯 🛢 💸 💵 💴 💶 💷 🪙 💰 💳 🧾 💎 ⚖️ 🪜 🧰 🪛 🔧 🔨 ⚒️ 🛠️ ⛏️ 🔩 ⚙️ 🧱 ⛓️ 🧲 🔫 💣 🧨 🪓 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ 🪦 ⚱️ 🏺 🔮 📿 🧿 💈 ⚗️ 🔭 🔬 🕳️ 🩹 🩺 💊 💉 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🧺 🧻 🚽 🚰 🚿 🛁 🛀 🧼 🪥 🪒 🧽 🪣 🧴 🛎️ 🔑 🗝️ 🚪 🪑 🛋️ 🛏️ 🛌 🧸 🪆 🖼️ 🪞 🪟 🛍️ 🛒 🎁 🎈 🎏 🎀 🪄 🪅 🎊 🎉 🎎 🏮 🎐 🧧 ✉️ 📩 📨 📧 💌 📥 📤 📦 🏷️ 📪 📫 📬 📭 📮 🗳️ ✏️ ✒️ 🖋️ 🖊️ 🖌️ 🖍️ 📝 💼 📁 📂 🗂️ 📅 📆 🗒️ 🗓️ 📇 📈 📉 📊 📋 📌 📍 📎 🖇️ 📏 📐 ✂️ 🗃️ 🗄️ 🗑️ 🔒 🔓 🔏 🔐 🔑".split(" ")
    }
];
