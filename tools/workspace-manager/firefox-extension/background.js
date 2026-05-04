/* Workspace Tabs - Firefox extension for workspace-manager integration
 *
 * - Saves tabs to ~/workspaces/<name>.json via native host on every tab change
 * - Restores tabs from workspace file when switching to a workspace
 * - Maintains a hidden anchor window to keep Firefox alive
 * - Provides "Send to workspace" context menu
 */

const HOST_NAME = "workspace_tabs";
const ANCHOR_TITLE = "workspace-anchor";

let port = null;
let pendingRequests = new Map();
let requestId = 0;
let lastWorkspace = null;
let anchorWindowId = null;
let restoringWorkspaces = new Set();
let pendingNewWorkspaceTabId = null;
let savePending = false;
let initialized = false;

// ── Native messaging ────────────────────────────────────────

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
    onWorkspaceChange(msg.workspace);
    return;
  }
  if (msg.id && pendingRequests.has(msg.id)) {
    const { resolve } = pendingRequests.get(msg.id);
    pendingRequests.delete(msg.id);
    resolve(msg);
  }
}

// ── Workspace queries ───────────────────────────────────────

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

// ── Firefox window <-> workspace mapping ────────────────────

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
        if (matched.has(win.id) || win.id === anchorWindowId) continue;
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

// ── Anchor window (keeps Firefox alive) ─────────────────────

async function ensureAnchorWindow() {
  if (anchorWindowId !== null) {
    try {
      await browser.windows.get(anchorWindowId);
      return; // still exists
    } catch (e) {
      anchorWindowId = null;
    }
  }

  // Close any existing windows (Firefox's default startup window)
  const existingWindows = await browser.windows.getAll();

  // Create anchor window with a page that sets the window title
  const win = await browser.windows.create({
    url: browser.runtime.getURL("anchor.html"),
  });
  anchorWindowId = win.id;

  // Close Firefox's default window(s)
  for (const w of existingWindows) {
    if (w.id !== anchorWindowId) {
      try {
        await browser.windows.remove(w.id);
      } catch (e) {
        // already closed
      }
    }
  }
  // Daemon's for_window rule hides anchor when title updates to "workspace-anchor"
}

// Prevent anchor window from being closed
browser.windows.onRemoved.addListener((windowId) => {
  if (windowId === anchorWindowId) {
    anchorWindowId = null;
    ensureAnchorWindow();
  }
});

// ── Tab saving (to workspace file) ─────────────────────────

async function saveTabsForWorkspace(workspace) {
  if (!workspace) return;

  const mappings = await getFirefoxWindowMappings();
  const windowId = mappings.get(workspace);
  if (!windowId) return;

  try {
    const tabs = await browser.tabs.query({ windowId });
    const tabData = tabs
      .filter((t) => t.url && !t.url.startsWith("about:"))
      .map((t) => ({
        url: t.url,
        pinned: t.pinned,
        active: t.active,
      }));

    await sendNative("save_tabs", { workspace, tabs: tabData });
  } catch (e) {
    console.error(`Failed to save tabs for ${workspace}:`, e);
  }
}

async function saveAllTabs() {
  const mappings = await getFirefoxWindowMappings();
  for (const [workspace] of mappings) {
    await saveTabsForWorkspace(workspace);
  }
}

// Debounced save: collects rapid changes, saves after 500ms idle
function scheduleSave() {
  if (savePending) return;
  savePending = true;
  setTimeout(async () => {
    savePending = false;
    await saveAllTabs();
  }, 500);
}

// Listen to all tab events that should trigger a save
browser.tabs.onCreated.addListener(scheduleSave);
browser.tabs.onRemoved.addListener(scheduleSave);
browser.tabs.onUpdated.addListener((_tabId, changeInfo) => {
  // Save on URL changes and title changes (navigation complete)
  if (changeInfo.url || changeInfo.title) {
    scheduleSave();
  }
});
browser.tabs.onMoved.addListener(scheduleSave);
browser.tabs.onActivated.addListener(scheduleSave);
browser.tabs.onAttached.addListener(scheduleSave);
browser.tabs.onDetached.addListener(scheduleSave);

// ── Tab restoring (from workspace file) ─────────────────────

async function restoreWorkspace(workspace) {
  if (restoringWorkspaces.has(workspace)) return;
  restoringWorkspaces.add(workspace);

  try {
    const resp = await sendNative("get_tabs", { workspace });
    const tabs = resp.tabs || [];
    if (tabs.length === 0) return;

    // Create window with the first tab to avoid a blank "new tab"
    const first = tabs[0];
    const newWindow = await browser.windows.create({ url: first.url });
    const windowId = newWindow.id;

    // Pin the first tab if needed
    if (first.pinned && newWindow.tabs && newWindow.tabs[0]) {
      await browser.tabs.update(newWindow.tabs[0].id, { pinned: true });
    }

    // Create remaining tabs
    for (let i = 1; i < tabs.length; i++) {
      await browser.tabs.create({
        windowId,
        url: tabs[i].url,
        pinned: tabs[i].pinned,
        active: tabs[i].active,
      });
    }
  } catch (e) {
    console.error(`Failed to restore workspace ${workspace}:`, e);
  } finally {
    restoringWorkspaces.delete(workspace);
  }
}

// ── Workspace change handling ────────────────────────────────

async function onWorkspaceChange(workspace) {
  if (!workspace || workspace === lastWorkspace) return;

  // Save all workspaces' tabs before switching
  await saveAllTabs();

  lastWorkspace = workspace;

  // Don't restore tabs during startup — only after user switches workspace
  if (!initialized) return;

  // Check if this workspace already has a Firefox window
  const withFirefox = await getWorkspacesWithFirefox();
  if (withFirefox.has(workspace)) return;

  // No Firefox window — restore saved tabs
  const resp = await sendNative("get_tabs", { workspace });
  const tabs = resp.tabs || [];
  if (tabs.length > 0) {
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
    // Save both workspaces after move
    scheduleSave();
  } catch (e) {
    console.error(`Failed to send tab to workspace ${targetWorkspace}:`, e);
  }
}

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
  // Connect to native host first — we need it to save existing tabs
  connectNative();
  await new Promise((r) => setTimeout(r, 500));

  try {
    lastWorkspace = await getCurrentWorkspace();
  } catch (e) {
    console.warn("Failed to get current workspace:", e);
  }

  const hadExistingWindows = (await browser.windows.getAll()).length > 0;

  // Save all existing tabs before creating the anchor window
  // (ensureAnchorWindow closes all windows, so save first)
  if (hadExistingWindows) {
    try {
      await saveAllTabs();
    } catch (e) {
      console.error("Failed to save existing tabs before anchor creation:", e);
    }
  }

  // Create anchor window — closes existing windows via the for_window rule
  try {
    await ensureAnchorWindow();
  } catch (e) {
    console.error("Failed to create anchor window:", e);
  }

  try {
    await rebuildContextMenu();
  } catch (e) {
    console.warn("Failed to build context menu:", e);
  }

  // Mark init complete — workspace changes from now on will restore tabs
  initialized = true;

  // Restore tabs for the initial workspace if it has saved tabs from a previous session
  if (lastWorkspace) {
    const withFirefox = await getWorkspacesWithFirefox();
    if (!withFirefox.has(lastWorkspace)) {
      const resp = await sendNative("get_tabs", { workspace: lastWorkspace });
      const tabs = resp.tabs || [];
      if (tabs.length > 0) {
        await restoreWorkspace(lastWorkspace);
      }
    }
  }
}

init();
