.pragma library

// Pure data layer for the desktop-pet runtime. A pack owns its own actions,
// dialogue, menu labels, interaction mapping, agent-state reactions and
// language. The framework only interprets that data; it never invents a
// character's catchphrases or a common "pet/feed/play" vocabulary.

var STATE_NAMES = ["thinking", "working", "result", "waiting", "success", "error"]

var STATE_FALLBACK = {
    "thinking": ["thinking", "think", "review", "working"],
    "working": ["working", "running", "review", "walk"],
    "result": ["result", "review", "working", "success"],
    "waiting": ["waiting", "wait", "idle"],
    "success": ["success", "celebrate", "jumping", "joy", "idle"],
    "error": ["error", "failed", "disappointed", "idle"]
}

function asArray(value) {
    if (value === undefined || value === null)
        return [];
    return Array.isArray(value) ? value : [value];
}

function textList(value) {
    var out = [];
    var list = asArray(value);
    for (var i = 0; i < list.length; i++) {
        if (typeof list[i] === "string" && list[i] !== "")
            out.push(list[i]);
    }
    return out;
}

function pick(list) {
    if (!list || list.length === 0)
        return "";
    return list[Math.floor(Math.random() * list.length)];
}

function durationOf(anim) {
    if (!anim)
        return 2.0;
    var count = anim.frames ? anim.frames.length : 1;
    var fps = Number(anim.fps) || 8;
    var duration = count / Math.max(0.1, fps);
    if (anim.pingpong === true)
        duration *= 1.2;
    return Math.max(0.5, Math.min(8.0, duration));
}

function localeKey(value) {
    return String(value || "").trim().replace(/-/g, "_").toLowerCase();
}

function localeBase(value) {
    var key = localeKey(value);
    var cut = key.indexOf("_");
    return cut > 0 ? key.slice(0, cut) : key;
}

function localeBundles(pack) {
    if (pack && pack.locales && typeof pack.locales === "object")
        return pack.locales;
    if (pack && pack.i18n && typeof pack.i18n === "object")
        return pack.i18n;
    return null;
}

function findLocaleBundle(pack, preferred) {
    var bundles = localeBundles(pack);
    if (!bundles)
        return null;
    var wanted = [preferred, pack.language, pack.locale];
    var candidates = [];
    for (var i = 0; i < wanted.length; i++) {
        var raw = localeKey(wanted[i]);
        if (!raw)
            continue;
        if (candidates.indexOf(raw) < 0)
            candidates.push(raw);
        var base = localeBase(raw);
        if (base && candidates.indexOf(base) < 0)
            candidates.push(base);
    }
    // Exact locale match first, then base-language match. This supports both
    // zh_CN / zh-CN and en_US / en without a hard-coded language table.
    for (var c = 0; c < candidates.length; c++) {
        for (var key in bundles) {
            if (localeKey(key) === candidates[c])
                return { "key": String(key), "data": bundles[key] };
        }
    }
    for (var b = 0; b < candidates.length; b++) {
        for (var key2 in bundles) {
            if (localeBase(key2) === candidates[b])
                return { "key": String(key2), "data": bundles[key2] };
        }
    }
    return null;
}

function mergeActions(base, override) {
    var out = {};
    for (var key in base)
        out[key] = base[key];
    for (var key2 in override) {
        if (out[key2] && typeof out[key2] === "object" && typeof override[key2] === "object")
            out[key2] = Object.assign({}, out[key2], override[key2]);
        else
            out[key2] = override[key2];
    }
    return out;
}

function mergeBehavior(base, override) {
    var out = Object.assign({}, base || {}, override || {});
    var nested = ["wander", "sleep"];
    for (var i = 0; i < nested.length; i++) {
        var key = nested[i];
        if (base && base[key] && typeof base[key] === "object"
                && override && override[key] && typeof override[key] === "object")
            out[key] = Object.assign({}, base[key], override[key]);
    }
    return out;
}

function localizePack(pack, bundle) {
    if (!bundle || !bundle.data || typeof bundle.data !== "object")
        return pack;
    var out = {};
    for (var key in pack)
        out[key] = pack[key];
    var data = bundle.data;
    for (var field in data) {
        if (field === "actions" && pack.actions && typeof pack.actions === "object"
                && data[field] && typeof data[field] === "object") {
            out.actions = mergeActions(pack.actions, data[field]);
        } else if (field === "behavior" && pack.behavior && typeof pack.behavior === "object"
                   && data[field] && typeof data[field] === "object") {
            out.behavior = mergeBehavior(pack.behavior, data[field]);
        } else if (field === "ui" && pack.ui && typeof pack.ui === "object"
                   && data[field] && typeof data[field] === "object") {
            out.ui = Object.assign({}, pack.ui, data[field]);
        } else {
            out[field] = data[field];
        }
    }
    out.language = data.language ? String(data.language) : bundle.key;
    out.locale = data.locale ? String(data.locale) : bundle.key;
    return out;
}

function availableLocales(pack) {
    var out = [];
    var add = function(value) {
        var key = String(value || "");
        if (key && out.indexOf(key) < 0)
            out.push(key);
    };
    if (pack.language)
        add(pack.language);
    if (pack.locale)
        add(pack.locale);
    var bundles = localeBundles(pack);
    if (bundles) {
        for (var key in bundles)
            add(key);
    }
    return out;
}

function normalizeAction(id, spec, animations) {
    if (typeof spec === "string")
        spec = { "animation": spec };
    if (!spec || typeof spec !== "object")
        return null;
    var animation = spec.animation ? String(spec.animation) : "";
    var action = {
        "id": id,
        "animation": animation,
        "say": textList(spec.say),
        "duration": Number(spec.duration) || 0,
        "loop": spec.loop === true,
        "agent": spec.agent ? String(spec.agent) : "",
        "prompt": spec.prompt ? String(spec.prompt) : "",
        "label": spec.label ? String(spec.label) : "",
        "icon": spec.icon ? String(spec.icon) : "",
        "menu": spec.menu !== false
    };
    if (!action.duration)
        action.duration = animation && animations[animation] ? durationOf(animations[animation]) : 2.2;
    if (action.loop && !spec.duration)
        action.duration = Math.max(action.duration, 3.5);
    action.duration = Math.max(0.35, Math.min(12.0, action.duration));
    return action;
}

function resolveAction(raw, actions, animations) {
    if (!raw)
        return null;
    if (typeof raw === "string") {
        if (actions[raw])
            return actions[raw];
        if (animations[raw])
            return normalizeAction("state:" + raw, { "animation": raw }, animations);
        return null;
    }
    if (typeof raw === "object")
        return normalizeAction("state:" + (raw.animation || "action"), raw, animations);
    return null;
}

function isSpecial(action) {
    return action === "agentPanel" || action === "petSettings" || action === "fleet"
            || action === "fleetSummary" || action === "menu";
}

function uiOf(pack, defaults) {
    var raw = pack && pack.ui && typeof pack.ui === "object" ? pack.ui : {};
    var fallback = defaults && typeof defaults === "object" ? defaults : {};
    return {
        "menuTitle": raw.menuTitle ? String(raw.menuTitle)
                : String(pack && pack.name ? pack.name : (fallback.menuTitle || "")),
        "agentPanel": raw.agentPanel ? String(raw.agentPanel) : String(fallback.agentPanel || ""),
        "petSettings": raw.petSettings ? String(raw.petSettings) : String(fallback.petSettings || "")
    };
}

function buildMenu(pack, actions, animations, uiDefaults) {
    var menu = [];
    var explicit = pack && Array.isArray(pack.menu) ? pack.menu : null;
    if (explicit) {
        for (var i = 0; i < explicit.length; i++) {
            var entry = explicit[i];
            if (!entry || typeof entry !== "object")
                continue;
            if (entry.separator === true) {
                menu.push({ "separator": true });
                continue;
            }
            var actionId = entry.action ? String(entry.action) : "";
            if (actionId === "fleet" || actionId === "fleetSummary")
                continue;
            if (!actions[actionId] && !isSpecial(actionId))
                continue;
            menu.push({
                          "id": entry.id ? String(entry.id) : actionId,
                          "label": entry.label ? String(entry.label) : actionId,
                          "icon": entry.icon ? String(entry.icon) : "",
                          "action": actionId
                      });
        }
    } else {
        // No pack menu: expose this pack's own declared actions, not a
        // framework-wide pet/feed/play list. Labels come from the pack.
        for (var key in actions) {
            var action = actions[key];
            if (!action || action.menu === false)
                continue;
            menu.push({
                          "id": key,
                          "label": action.label || key,
                          "icon": action.icon || "",
                          "action": key
                      });
            if (menu.length >= 8)
                break;
        }
    }

    // Agent/settings are framework controls. Their labels are pack-localizable
    // via ui.agentPanel / ui.petSettings; the final fallback comes from the
    // shell's translation layer (qsTr), not from a hard-coded language here.
    var ui = uiOf(pack, uiDefaults);
    var has = {};
    for (var k = 0; k < menu.length; k++)
        if (!menu[k].separator)
            has[menu[k].action] = true;
    if (!has["agentPanel"] || !has["petSettings"]) {
        menu.push({ "separator": true });
        if (!has["agentPanel"])
            menu.push({ "id": "agent", "label": ui.agentPanel,
                        "icon": "chat", "action": "agentPanel" });
        if (!has["petSettings"])
            menu.push({ "id": "settings", "label": ui.petSettings,
                        "icon": "settings", "action": "petSettings" });
    }
    return menu;
}

function buildInteractions(pack, actions, animations) {
    var interactions = {};
    var explicit = pack && pack.interactions && typeof pack.interactions === "object"
            ? pack.interactions : {};
    for (var key in explicit) {
        var value = explicit[key];
        if (typeof value === "string")
            interactions[key] = value;
        else if (value && typeof value === "object")
            interactions[key] = normalizeAction(key, value, animations);
    }
    if (!interactions.singleClick) {
        // A pack without an explicit click mapping gets its own first action;
        // if it declares none, the click belongs to the Agent panel.
        var first = "";
        for (var id in actions) {
            if (actions[id] && actions[id].menu !== false) {
                first = id;
                break;
            }
        }
        interactions.singleClick = first || "agentPanel";
    }
    if (!interactions.doubleClick)
        interactions.doubleClick = "";
    if (!interactions.dragStart)
        interactions.dragStart = animations.drag
                ? { "animation": "drag", "duration": 60, "loop": true } : "";
    if (!interactions.dragEnd)
        interactions.dragEnd = "";
    if (!interactions.rightClick)
        interactions.rightClick = "menu";
    return interactions;
}

function buildAmbient(pack, behavior, actions, animations) {
    var raw = behavior.ambient;
    if (!Array.isArray(raw))
        raw = pack && Array.isArray(pack.ambient) ? pack.ambient : [];
    var out = [];
    for (var i = 0; i < raw.length; i++) {
        var item = raw[i];
        if (typeof item === "string") {
            if (actions[item])
                out.push({ "action": item, "weight": 1 });
            continue;
        }
        if (!item || typeof item !== "object")
            continue;
        var id = item.action ? String(item.action) : "";
        if (actions[id]) {
            out.push({
                         "action": id,
                         "weight": Math.max(0.1, Number(item.weight) || 1),
                         "say": textList(item.say)
                     });
        } else if (item.animation && animations[item.animation]) {
            var aid = "ambient:" + item.animation;
            actions[aid] = normalizeAction(aid, item, animations);
            out.push({ "action": aid, "weight": Math.max(0.1, Number(item.weight) || 1) });
        }
    }
    return out;
}

function build(pack, preferredLocale, uiDefaults) {
    pack = pack || {};
    var locales = availableLocales(pack);
    var bundle = findLocaleBundle(pack, preferredLocale);
    if (bundle)
        pack = localizePack(pack, bundle);
    var animations = pack.animations && typeof pack.animations === "object" ? pack.animations : {};
    var behavior = pack.behavior && typeof pack.behavior === "object" ? pack.behavior : {};
    var actions = {};
    var explicit = pack.actions && typeof pack.actions === "object" ? pack.actions : {};
    for (var key in explicit) {
        var action = normalizeAction(key, explicit[key], animations);
        if (action)
            actions[key] = action;
    }

    var agentStates = {};
    var stateMap = pack.agentStates && typeof pack.agentStates === "object"
            ? pack.agentStates
            : (behavior.agentStates && typeof behavior.agentStates === "object"
               ? behavior.agentStates : {});
    for (var s = 0; s < STATE_NAMES.length; s++) {
        var state = STATE_NAMES[s];
        var resolved = resolveAction(stateMap[state], actions, animations);
        if (!resolved) {
            var fallback = STATE_FALLBACK[state] || [];
            for (var f = 0; f < fallback.length && !resolved; f++)
                resolved = resolveAction(fallback[f], actions, animations);
        }
        if (resolved)
            agentStates[state] = resolved;
    }

    var statusTexts = {};
    var rawTexts = pack.workStatusTexts || pack.statusTexts
            || behavior.workStatusTexts || behavior.statusTexts;
    if (Array.isArray(rawTexts)) {
        for (var t = 0; t < STATE_NAMES.length; t++)
            statusTexts[STATE_NAMES[t]] = textList(rawTexts[t]);
    } else if (rawTexts && typeof rawTexts === "object") {
        for (var n = 0; n < STATE_NAMES.length; n++)
            statusTexts[STATE_NAMES[n]] = textList(rawTexts[STATE_NAMES[n]]);
    }

    var wanderRaw = behavior.wander;
    var wanderEnabled = wanderRaw === true
            || (wanderRaw && typeof wanderRaw === "object" && wanderRaw.enabled !== false);
    var wanderAnimation = "";
    if (wanderRaw && typeof wanderRaw === "object" && wanderRaw.animation)
        wanderAnimation = String(wanderRaw.animation);
    if (!wanderAnimation) {
        wanderAnimation = animations.walk ? "walk"
                : (animations.running ? "running"
                   : (animations["running-right"] ? "running-right" : ""));
    }
    var wanderSay = textList(wanderRaw && typeof wanderRaw === "object" ? wanderRaw.say : []);
    if (wanderSay.length === 0)
        wanderSay = textList(behavior.walkSay || pack.walkSay);
    var wander = {
        "enabled": !!wanderEnabled && wanderAnimation !== "",
        "animation": wanderAnimation,
        "speed": Math.max(8, Math.min(90, Number(wanderRaw && wanderRaw.speed)
                                        || Number(behavior.speed) || 26)),
        "facing": (wanderRaw && wanderRaw.facing) || behavior.facing || "right",
        "say": wanderSay
    };

    var sleepRaw = pack.sleep !== undefined ? pack.sleep : behavior.sleep;
    var sleep = null;
    if (sleepRaw && animations.sleep) {
        var sleepObj = sleepRaw === true ? {} : sleepRaw;
        sleep = {
            "after": Math.max(20, Number(sleepObj.after) || 180),
            "animation": sleepObj.animation || "sleep",
            "wakeAnimation": sleepObj.wakeAnimation
                    || (animations.wake ? "wake" : ""),
            "say": textList(sleepObj.say || sleepObj.lines),
            "wakeSay": textList(sleepObj.wakeSay || sleepObj.wakeLines)
        };
    }

    var appearanceRaw = pack.appearance && typeof pack.appearance === "object"
            ? pack.appearance
            : (behavior.appearance && typeof behavior.appearance === "object"
               ? behavior.appearance : {});
    var appearance = {
        "shadow": appearanceRaw.shadow !== false,
        "label": appearanceRaw.label !== false,
        "defaultSize": Number(appearanceRaw.defaultSize) || 0
    };

    return {
        "actions": actions,
        "agentStates": agentStates,
        "statusTexts": statusTexts,
        "interactions": buildInteractions(pack, actions, animations),
        "menu": buildMenu(pack, actions, animations, uiDefaults),
        "ambient": buildAmbient(pack, behavior, actions, animations),
        "wander": wander,
        "sleep": sleep,
        "appearance": appearance,
        "ui": uiOf(pack, uiDefaults),
        "language": pack.language ? String(pack.language) : "",
        "locale": pack.locale ? String(pack.locale) : "",
        "availableLocales": locales,
        "hasAnimations": Object.keys(animations).length > 0
    };
}

function statusLabel(state) {
    // Framework/debug label only; never used as pet dialogue.
    return String(state || "idle");
}

function pickText(list) {
    return pick(list);
}
