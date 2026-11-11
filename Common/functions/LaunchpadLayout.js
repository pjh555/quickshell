.pragma library

var schemaVersion = 1;

function text(value) {
    return typeof value === "string" ? value : "";
}

function appItem(id) {
    return {
        type: "app",
        id: text(id)
    };
}

function folderItem(id, name, items) {
    return {
        type: "folder",
        id: text(id),
        name: text(name),
        items: Array.from(items || []).map(item => appItem(item.id))
    };
}

function isApp(item) {
    return !!item && item.type === "app" && text(item.id) !== "";
}

function isFolder(item) {
    return !!item && item.type === "folder" && text(item.id) !== "" && Array.isArray(item.items);
}

function folderAppIds(folder) {
    return isFolder(folder) ? folder.items.filter(isApp).map(item => item.id) : [];
}

function cloneItem(item) {
    if (isApp(item))
        return appItem(item.id);
    if (isFolder(item))
        return folderItem(item.id, item.name, item.items);
    return null;
}

function cloneItems(items) {
    const result = [];
    for (const item of Array.from(items || [])) {
        const clone = cloneItem(item);
        if (clone)
            result.push(clone);
    }
    return result;
}

function folderId(seed) {
    const base = String(seed || Date.now()).replace(/[^a-zA-Z0-9]/g, "");
    return "folder-" + (base || "group") + "-" + Math.floor(Math.random() * 1679616).toString(36);
}

function decode(textValue) {
    let value;
    try {
        value = JSON.parse(textValue);
    } catch (error) {
        return null;
    }
    if (!value || value.schemaVersion !== schemaVersion || !Array.isArray(value.items))
        return null;
    if (value.hidden !== undefined && (!Array.isArray(value.hidden) || !value.hidden.every(id => typeof id === "string")))
        return null;

    const seen = new Set();
    const items = [];
    for (const raw of value.items) {
        if (isApp(raw)) {
            if (seen.has(raw.id))
                continue;
            seen.add(raw.id);
            items.push(appItem(raw.id));
            continue;
        }
        if (!isFolder(raw) || text(raw.name) === "" || seen.has(raw.id))
            continue;
        const nested = [];
        const nestedSeen = new Set();
        for (const child of raw.items) {
            if (!isApp(child) || seen.has(child.id) || nestedSeen.has(child.id))
                continue;
            nestedSeen.add(child.id);
            nested.push(appItem(child.id));
        }
        if (nested.length === 0)
            continue;
        seen.add(raw.id);
        if (nested.length === 1) {
            if (seen.has(nested[0].id))
                continue;
            seen.add(nested[0].id);
            items.push(nested[0]);
        } else {
            nested.forEach(item => seen.add(item.id));
            items.push(folderItem(raw.id, raw.name, nested));
        }
    }
    const hidden = Array.from(new Set(value.hidden || [])).filter(id => id !== "");
    return {
        items: items,
        hidden: hidden
    };
}

function encode(layout) {
    const normalized = layout || {
        items: [],
        hidden: []
    };
    return JSON.stringify({
        schemaVersion: schemaVersion,
        hidden: Array.from(normalized.hidden || []),
        items: cloneItems(normalized.items)
    }, null, 2);
}

function visibleApplications(appIds, hidden) {
    const hiddenSet = new Set(hidden || []);
    return Array.from(appIds || []).filter(id => !hiddenSet.has(id));
}

// Keep the user's arrangement while removing vanished applications and
// appending newly installed applications to the last page.
function reconcile(layout, appIds, hidden) {
    const source = layout || {
        items: [],
        hidden: []
    };
    const valid = new Set(Array.from(appIds || []));
    const hiddenIds = Array.from(new Set(hidden || source.hidden || [])).filter(id => valid.has(id));
    const hiddenSet = new Set(hiddenIds);
    const seen = new Set();
    const items = [];

    for (const raw of cloneItems(source.items)) {
        if (isApp(raw)) {
            if (!valid.has(raw.id) || hiddenSet.has(raw.id) || seen.has(raw.id))
                continue;
            seen.add(raw.id);
            items.push(raw);
            continue;
        }
        const nested = [];
        for (const child of raw.items) {
            if (!valid.has(child.id) || hiddenSet.has(child.id) || seen.has(child.id))
                continue;
            seen.add(child.id);
            nested.push(child);
        }
        if (nested.length === 0)
            continue;
        if (nested.length === 1) {
            items.push(nested[0]);
        } else {
            items.push(folderItem(raw.id, raw.name, nested));
        }
    }

    for (const id of Array.from(appIds || [])) {
        if (seen.has(id) || hiddenSet.has(id))
            continue;
        seen.add(id);
        items.push(appItem(id));
    }

    return {
        items: items,
        hidden: hiddenIds
    };
}

function findIndex(items, id) {
    for (let index = 0; index < items.length; index += 1) {
        if (items[index] && items[index].id === id)
            return index;
    }
    return -1;
}

function containsApp(items, appId) {
    for (const item of Array.from(items || [])) {
        if (isApp(item) && item.id === appId)
            return true;
        if (isFolder(item) && folderAppIds(item).indexOf(appId) >= 0)
            return true;
    }
    return false;
}

function removeTopLevel(items, id) {
    const next = cloneItems(items);
    const index = findIndex(next, id);
    if (index >= 0)
        next.splice(index, 1);
    return next;
}

function addFolderToLayout(layout, sourceId, targetId, name, newId) {
    const items = cloneItems(layout.items);
    const sourceIndex = findIndex(items, sourceId);
    const targetIndex = findIndex(items, targetId);
    if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex)
        return layout;
    const source = items[sourceIndex];
    const target = items[targetIndex];
    if (!isApp(source) || !isApp(target))
        return layout;

    const folder = folderItem(newId || folderId(sourceId + targetId), name, [target, source]);
    items.splice(targetIndex, 1, folder);
    items.splice(sourceIndex, 1);
    return {
        items: items,
        hidden: layout.hidden
    };
}

function addAppToFolder(layout, appId, folderIdValue) {
    const items = cloneItems(layout.items);
    const appIndex = findIndex(items, appId);
    const targetIndex = findIndex(items, folderIdValue);
    if (appIndex < 0 || targetIndex < 0 || appIndex === targetIndex)
        return layout;
    const app = items[appIndex];
    const folder = items[targetIndex];
    if (!isApp(app) || !isFolder(folder))
        return layout;
    folder.items.push(appItem(app.id));
    items.splice(appIndex, 1);
    return {
        items: items,
        hidden: layout.hidden
    };
}

function reorder(layout, sourceId, targetIndex) {
    const items = cloneItems(layout.items);
    const sourceIndex = findIndex(items, sourceId);
    if (sourceIndex < 0)
        return layout;
    const moved = items.splice(sourceIndex, 1)[0];
    const destination = Math.max(0, Math.min(items.length, Number(targetIndex) || 0));
    items.splice(destination, 0, moved);
    return {
        items: items,
        hidden: layout.hidden
    };
}

function moveApp(layout, sourceId, targetId, targetIndex, folderName) {
    if (sourceId === targetId)
        return layout;
    const sourceIndex = findIndex(layout.items, sourceId);
    const targetItemIndex = findIndex(layout.items, targetId);
    if (sourceIndex < 0)
        return layout;

    const source = layout.items[sourceIndex];
    if (targetItemIndex >= 0) {
        const target = layout.items[targetItemIndex];
        if (isApp(source) && isApp(target))
            return addFolderToLayout(layout, sourceId, targetId, folderName || "Folder");
        if (isApp(source) && isFolder(target))
            return addAppToFolder(layout, sourceId, targetId);
    }
    return reorder(layout, sourceId, targetIndex);
}

function renameFolder(layout, folderIdValue, name) {
    const value = text(name).trim();
    if (value === "")
        return layout;
    return {
        items: layout.items.map(item => item.id === folderIdValue && isFolder(item) ? folderItem(item.id, value,
                                                                                                  item.items) : item),
        hidden: layout.hidden
    };
}

function removeAppFromFolder(layout, folderIdValue, appId) {
    const items = cloneItems(layout.items);
    const index = findIndex(items, folderIdValue);
    if (index < 0 || !isFolder(items[index]))
        return layout;
    const folder = items[index];
    const nested = folder.items.filter(item => item.id !== appId);
    if (nested.length === folder.items.length)
        return layout;
    if (nested.length === 0) {
        items.splice(index, 1);
    } else if (nested.length === 1) {
        items.splice(index, 1, appItem(nested[0].id));
    } else {
        folder.items = nested;
    }
    return {
        items: items,
        hidden: layout.hidden
    };
}

// Drag an application out of a folder. Unlike removeApplication(), the app
// stays in the layout: it is placed after the folder, or at the folder's
// position when the folder dissolves.
function releaseFromFolder(layout, folderIdValue, appId) {
    const items = cloneItems(layout.items);
    const index = findIndex(items, folderIdValue);
    if (index < 0 || !isFolder(items[index]))
        return layout;
    const folder = items[index];
    if (!folder.items.some(item => item.id === appId))
        return layout;
    const nested = folder.items.filter(item => item.id !== appId);
    const released = appItem(appId);
    if (nested.length === 0) {
        items.splice(index, 1, released);
    } else if (nested.length === 1) {
        items.splice(index, 1, appItem(nested[0].id), released);
    } else {
        folder.items = nested;
        items.splice(index + 1, 0, released);
    }
    return {
        items: items,
        hidden: layout.hidden
    };
}

function reorderFolder(layout, folderIdValue, sourceId, targetIndex) {
    const items = cloneItems(layout.items);
    const index = findIndex(items, folderIdValue);
    if (index < 0 || !isFolder(items[index]))
        return layout;
    const folder = items[index];
    const sourceIndex = folder.items.findIndex(item => item.id === sourceId);
    if (sourceIndex < 0)
        return layout;
    const moved = folder.items.splice(sourceIndex, 1)[0];
    const destination = Math.max(0, Math.min(folder.items.length, Number(targetIndex) || 0));
    folder.items.splice(destination, 0, moved);
    return {
        items: items,
        hidden: layout.hidden
    };
}

function hideApplication(layout, appId) {
    if (!containsApp(layout.items, appId))
        return layout;
    let items = cloneItems(layout.items);
    const folder = items.find(item => isFolder(item) && folderAppIds(item).indexOf(appId) >= 0);
    if (folder)
        items = removeAppFromFolder({
                                        items: items,
                                        hidden: layout.hidden
                                    }, folder.id, appId).items;
    else
        items = removeTopLevel(items, appId);
    const hidden = Array.from(new Set(Array.from(layout.hidden || []).concat([appId])));
    return {
        items: items,
        hidden: hidden
    };
}

// Remove an application because its backing package/bundle was uninstalled.
// Unlike hideApplication(), this must not leave a hidden tombstone that would
// hide the application again if it is later installed.
function removeApplication(layout, appId) {
    let items = cloneItems(layout.items);
    const folder = items.find(item => isFolder(item) && folderAppIds(item).indexOf(appId) >= 0);
    if (folder) {
        items = removeAppFromFolder({
                                         items: items,
                                         hidden: layout.hidden
                                     }, folder.id, appId).items;
    } else {
        items = removeTopLevel(items, appId);
    }
    return {
        items: items,
        hidden: Array.from(layout.hidden || []).filter(id => id !== appId)
    };
}

function restoreApplication(layout, appId) {
    const hidden = Array.from(layout.hidden || []).filter(id => id !== appId);
    if (!containsApp(layout.items, appId))
        layout.items = cloneItems(layout.items).concat([appItem(appId)]);
    layout.hidden = hidden;
    return layout;
}

function pageCount(total, capacity) {
    const size = Math.max(1, Math.floor(Number(capacity) || 1));
    return Math.max(1, Math.ceil(Math.max(0, total) / size));
}

function pageSlice(items, page, capacity) {
    const size = Math.max(1, Math.floor(Number(capacity) || 1));
    return Array.from(items || []).slice(Math.max(0, page) * size, (Math.max(0, page) + 1) * size);
}

function itemAt(items, page, cell, capacity) {
    const slice = pageSlice(items, page, capacity);
    return cell >= 0 && cell < slice.length ? slice[cell] : null;
}

function pageForApp(items, appId, capacity) {
    const index = findIndex(items, appId);
    return index < 0 ? 0 : Math.floor(index / Math.max(1, capacity));
}
