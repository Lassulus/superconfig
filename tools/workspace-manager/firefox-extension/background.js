/* Workspace Tabs - Firefox extension for workspace-manager integration
 *
 * Provides "Send to workspace" context menu on tabs.
 * Queries sway tree directly to find Firefox windows per workspace.
 * Saves/restores tabs per workspace across restarts.
 */

const HOST_NAME = "workspace_tabs";

let port = null;
let pendingRequests = new Map();
let requestId = 0;
let lastWorkspace = null;
let restoringWorkspaces = new Set(); // prevent double-restore
let pendingNewWorkspaceTabId = null;

// Handle messages from the new-workspace popup
browser.runtime.onMessage.addListener((msg) => {
  if (
    msg.action === "sendToNewWorkspace" &&
    msg.workspace &&
    pendingNewWorkspaceTabId
  ) {
    const tabId = pendingNewWorkspaceTabId;
    pendingNewWorkspaceTabId = null;
    sendTabToWorkspace(tabId, msg.workspace);
  }
});

function connectNative() {
  try {
    port = browser.runtime.connectNative(HOST_NAME);
    port.onMessage.addListener(handleNativeMessage);
    port.onDisconnect.addListener(() => {
      console.warn("Native host disconnected, reconnecting in 2s...");
      port = null;
      setTimeout(connectNative, 2000);
    });
  } catch (e) {
    console.error("Failed to connect to native host:", e);
    setTimeout(connectNative, 5000);
  }
}

function sendNative(cmd, params = {}) {
  return new Promise((resolve, reject) => {
    if (!port) {
      reject(new Error("Native host not connected"));
      return;
    }
    const id = ++requestId;
    pendingRequests.set(id, { resolve, reject });
    port.postMessage({ id, cmd, ...params });
    setTimeout(() => {
      if (pendingRequests.has(id)) {
        pendingRequests.delete(id);
        reject(new Error("Request timed out"));
      }
    }, 5000);
  });
}

function handleNativeMessage(msg) {
  if (msg.event === "workspace_change") {
    // Push event from workspace-manager — handle workspace switch
    onWorkspaceChange(msg.workspace);
    return;
  }
  if (msg.id && pendingRequests.has(msg.id)) {
    const { resolve } = pendingRequests.get(msg.id);
    pendingRequests.delete(msg.id);
    resolve(msg);
  }
}

async function getCurrentWorkspace() {
  try {
    const resp = await sendNative("current_workspace");
    return resp.workspace || null;
  } catch (e) {
    return null;
  }
}

async function listWorkspaces() {
  try {
    const resp = await sendNative("list_workspaces");
    return resp.workspaces || [];
  } catch (e) {
    return [];
  }
}

// Get Firefox windows per workspace from sway tree (always fresh)
async function getFirefoxWindowMappings() {
  try {
    const resp = await sendNative("map_windows");
    if (!resp.windows) return new Map();

    const allWindows = await browser.windows.getAll({ populate: true });
    const result = new Map();
    const matched = new Set();

    for (const mapping of resp.windows) {
      const swayTitle = mapping.windowTitle || "";
      for (const win of allWindows) {
        if (matched.has(win.id)) continue;
        const activeTab = win.tabs && win.tabs.find((t) => t.active);
        if (
          activeTab &&
          activeTab.title &&
          swayTitle.startsWith(activeTab.title)
        ) {
          result.set(mapping.workspace, win.id);
          matched.add(win.id);
          break;
        }
      }
    }
    return result;
  } catch (e) {
    return new Map();
  }
}

async function getWorkspacesWithFirefox() {
  try {
    const resp = await sendNative("map_windows");
    if (!resp.windows) return new Set();
    return new Set(resp.windows.map((w) => w.workspace));
  } catch (e) {
    return new Set();
  }
}

// ── Tab saving ──────────────────────────────────────────────

async function saveAllTabs() {
  try {
    const mappings = await getFirefoxWindowMappings();
    const stored = (await browser.storage.local.get("savedTabs")) || {};
    const savedTabs = stored.savedTabs || {};

    for (const [workspace, windowId] of mappings) {
      try {
        const tabs = await browser.tabs.query({ windowId });
        savedTabs[workspace] = tabs
          .filter((t) => t.url && !t.url.startsWith("about:"))
          .map((t) => ({
            url: t.url,
            title: t.title,
            pinned: t.pinned,
            active: t.active,
          }));
      } catch (e) {
        // window might have closed
      }
    }

    await browser.storage.local.set({ savedTabs });
  } catch (e) {
    console.error("Failed to save tabs:", e);
  }
}

async function getSavedTabs() {
  const stored = await browser.storage.local.get("savedTabs");
  return (stored && stored.savedTabs) || {};
}

async function clearSavedTabs(workspace) {
  const savedTabs = await getSavedTabs();
  delete savedTabs[workspace];
  await browser.storage.local.set({ savedTabs });
}

// ── Tab restoring ───────────────────────────────────────────

// Restore tabs into a window, removing the initial blank tab
async function restoreTabsInWindow(tabDataList, windowId) {
  let activeTabId = null;
  for (const tab of tabDataList) {
    const created = await browser.tabs.create({
      windowId,
      url: tab.url,
      pinned: tab.pinned,
      active: tab.active,
    });
    if (tab.active) activeTabId = created.id;
  }

  // Remove initial blank tab
  const allTabs = await browser.tabs.query({ windowId });
  for (const t of allTabs) {
    if (
      (t.url === "about:blank" || t.url === "about:newtab") &&
      t.id !== activeTabId &&
      allTabs.length > 1
    ) {
      await browser.tabs.remove(t.id);
      break;
    }
  }
}

// Restore saved tabs for a workspace on the current sway workspace
async function restoreWorkspace(workspace) {
  if (restoringWorkspaces.has(workspace)) return;
  restoringWorkspaces.add(workspace);

  try {
    const savedTabs = await getSavedTabs();
    const tabs = savedTabs[workspace];
    if (!tabs || tabs.length === 0) return;

    const newWindow = await browser.windows.create({});
    await restoreTabsInWindow(tabs, newWindow.id);
    await clearSavedTabs(workspace);
  } catch (e) {
    console.error(`Failed to restore workspace ${workspace}:`, e);
  } finally {
    restoringWorkspaces.delete(workspace);
  }
}

// On startup: restore windows for all currently open workspaces
async function restoreOnStartup() {
  const savedTabs = await getSavedTabs();
  const openWorkspaces = await listWorkspaces();
  const currentWorkspace = await getCurrentWorkspace();

  // Get the initial window Firefox created (reuse it for current workspace)
  const initialWindows = await browser.windows.getAll({ populate: true });
  let initialWindowUsed = false;

  // Restore current workspace first, reusing the initial window
  if (
    currentWorkspace &&
    savedTabs[currentWorkspace] &&
    savedTabs[currentWorkspace].length > 0 &&
    openWorkspaces.includes(currentWorkspace)
  ) {
    restoringWorkspaces.add(currentWorkspace);
    try {
      const win = initialWindows[0];
      if (win) {
        await restoreTabsInWindow(savedTabs[currentWorkspace], win.id);
        initialWindowUsed = true;
      }
      await clearSavedTabs(currentWorkspace);
    } catch (e) {
      console.error(`Failed to restore current workspace:`, e);
    } finally {
      restoringWorkspaces.delete(currentWorkspace);
    }
  }

  // Restore other workspaces
  for (const ws of Object.keys(savedTabs)) {
    if (ws === currentWorkspace) continue;
    if (!savedTabs[ws] || savedTabs[ws].length === 0) continue;
    if (!openWorkspaces.includes(ws)) continue;

    restoringWorkspaces.add(ws);
    try {
      await sendNative("goto_workspace", { name: ws });
      const newWindow = await browser.windows.create({});
      await restoreTabsInWindow(savedTabs[ws], newWindow.id);
      await clearSavedTabs(ws);
    } catch (e) {
      console.error(`Failed to restore workspace ${ws} on startup:`, e);
    } finally {
      restoringWorkspaces.delete(ws);
    }
  }

  // Switch back to the original workspace
  if (currentWorkspace) {
    await sendNative("goto_workspace", { name: currentWorkspace });
  }

  // Close the initial window if it wasn't used
  if (!initialWindowUsed && initialWindows.length > 0) {
    const allWindows = await browser.windows.getAll();
    if (allWindows.length > 1) {
      try {
        await browser.windows.remove(initialWindows[0].id);
      } catch (e) {
        // already closed
      }
    }
  }
}

// ── Workspace change handling ────────────────────────────────

async function onWorkspaceChange(workspace) {
  if (!workspace || workspace === lastWorkspace) return;
  lastWorkspace = workspace;

  // Check if this workspace has saved tabs but no Firefox window
  const withFirefox = await getWorkspacesWithFirefox();
  if (withFirefox.has(workspace)) return;

  const savedTabs = await getSavedTabs();
  if (savedTabs[workspace] && savedTabs[workspace].length > 0) {
    await restoreWorkspace(workspace);
  }
}

// ── Send tab to workspace ───────────────────────────────────

async function sendTabToWorkspace(tabId, targetWorkspace) {
  try {
    const mappings = await getFirefoxWindowMappings();
    const targetWindowId = mappings.get(targetWorkspace);

    if (targetWindowId) {
      await browser.tabs.move(tabId, { windowId: targetWindowId, index: -1 });
    } else {
      const sourceWorkspace = await getCurrentWorkspace();
      const newWindow = await browser.windows.create({ tabId });
      await sendNative("move_to_workspace", { name: targetWorkspace });
      if (sourceWorkspace) {
        await sendNative("goto_workspace", { name: sourceWorkspace });
      }
    }
  } catch (e) {
    console.error(`Failed to send tab to workspace ${targetWorkspace}:`, e);
  }
}

// ── Context menu ────────────────────────────────────────────

async function rebuildContextMenu() {
  await browser.menus.removeAll();

  browser.menus.create({
    id: "send-to-workspace",
    title: "Send to workspace",
    contexts: ["tab"],
  });

  const allWorkspaces = await listWorkspaces();
  const withFirefox = await getWorkspacesWithFirefox();
  const wsWithFirefox = [];
  const wsWithoutFirefox = [];

  for (const ws of allWorkspaces) {
    if (withFirefox.has(ws)) {
      wsWithFirefox.push(ws);
    } else {
      wsWithoutFirefox.push(ws);
    }
  }

  for (const ws of wsWithFirefox) {
    browser.menus.create({
      id: `ws-${ws}`,
      parentId: "send-to-workspace",
      title: `● ${ws}`,
      contexts: ["tab"],
    });
  }

  if (wsWithFirefox.length > 0 && wsWithoutFirefox.length > 0) {
    browser.menus.create({
      id: "ws-separator",
      parentId: "send-to-workspace",
      type: "separator",
      contexts: ["tab"],
    });
  }

  for (const ws of wsWithoutFirefox) {
    browser.menus.create({
      id: `ws-${ws}`,
      parentId: "send-to-workspace",
      title: `○ ${ws}`,
      contexts: ["tab"],
    });
  }

  browser.menus.create({
    id: "ws-separator-new",
    parentId: "send-to-workspace",
    type: "separator",
    contexts: ["tab"],
  });

  browser.menus.create({
    id: "ws-new",
    parentId: "send-to-workspace",
    title: "New workspace…",
    contexts: ["tab"],
  });
}

browser.menus.onShown.addListener(async (info) => {
  if (info.contexts.includes("tab")) {
    await rebuildContextMenu();
    browser.menus.refresh();
  }
});

browser.menus.onClicked.addListener(async (info, tab) => {
  if (!tab || !tab.id) return;

  if (info.menuItemId === "ws-new") {
    pendingNewWorkspaceTabId = tab.id;
    browser.windows.create({
      url: browser.runtime.getURL("new-workspace.html"),
      type: "popup",
      width: 320,
      height: 60,
    });
    return;
  }

  if (info.menuItemId.startsWith("ws-")) {
    const workspace = info.menuItemId.slice(3);
    await sendTabToWorkspace(tab.id, workspace);
  }
});

// ── Init ────────────────────────────────────────────────────

async function init() {
  connectNative();
  await new Promise((r) => setTimeout(r, 500));

  lastWorkspace = await getCurrentWorkspace();
  await restoreOnStartup();
  await rebuildContextMenu();

  // Save tabs periodically
  setInterval(saveAllTabs, 30000);
}

init();
