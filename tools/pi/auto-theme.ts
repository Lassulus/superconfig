import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { readFileSync, watch, type FSWatcher } from "node:fs";

const THEME_FILE = "/var/theme/current_theme";

function readTheme(): "dark" | "light" | null {
  try {
    const value = readFileSync(THEME_FILE, "utf-8").trim();
    if (value === "dark" || value === "light") return value;
    return null;
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  let watcher: FSWatcher | null = null;

  pi.on("session_start", async (_event, ctx) => {
    // Set initial theme
    const scheme = readTheme();
    if (scheme) ctx.ui.setTheme(scheme);

    // Watch for changes
    try {
      watcher = watch(THEME_FILE, () => {
        const newScheme = readTheme();
        if (newScheme) ctx.ui.setTheme(newScheme);
      });
    } catch {
      // file doesn't exist yet, ignore
    }
  });

  pi.on("resources_discover", async () => {
    if (watcher) {
      watcher.close();
      watcher = null;
    }
  });
}
