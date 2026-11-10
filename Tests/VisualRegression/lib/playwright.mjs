// Locates playwright-core and launches a browser for the visual regression harness.
//
// playwright-core is looked up, in order, from the PLAYWRIGHT_CORE_PATH environment
// variable, the normal Node module resolution, and the installation that provides the
// `playwright-cli` command on the PATH.  The browser is the installed Google Chrome
// (channel `chrome`) unless VISUAL_REGRESSION_BROWSER_CHANNEL names another channel;
// an empty channel selects Playwright's own Chromium build.
import { createRequire } from 'node:module';
import { existsSync, realpathSync } from 'node:fs';
import { delimiter, dirname, join } from 'node:path';

const require = createRequire(import.meta.url);

/** Returns the candidate locations of playwright-core, most specific first. */
function candidates() {
  const list = [];
  if (process.env.PLAYWRIGHT_CORE_PATH) list.push(process.env.PLAYWRIGHT_CORE_PATH);
  list.push('playwright-core');
  for (const directory of (process.env.PATH || '').split(delimiter)) {
    for (const name of ['playwright-cli', 'playwright-cli.cmd']) {
      const executable = join(directory, name);
      if (!existsSync(executable)) continue;
      try {
        const script = realpathSync(executable);
        list.push(join(dirname(script), 'node_modules', 'playwright-core'));
      } catch { /* unreadable link: ignore */ }
    }
  }
  return list;
}

/** Loads playwright-core, or returns null if it cannot be found. */
export function loadPlaywright() {
  for (const candidate of candidates()) {
    try { return require(candidate); } catch { /* try the next candidate */ }
  }
  return null;
}

/** Launches Chromium through playwright-core. */
export async function launchBrowser() {
  const playwright = loadPlaywright();
  if (!playwright) throw new Error('playwright-core not found (set PLAYWRIGHT_CORE_PATH)');
  const channel = process.env.VISUAL_REGRESSION_BROWSER_CHANNEL ?? 'chrome';
  return playwright.chromium.launch(channel ? { channel } : {});
}
