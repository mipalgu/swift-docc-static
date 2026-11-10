// Loads the pages of a documentation site in a browser and measures their roles.
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchBrowser } from './playwright.mjs';
import { serve } from './server.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (name) => readFileSync(join(root, name), 'utf8');

/**
 * Measures every page of a site.
 *
 * @param {string} siteDirectory the generated site
 * @param {'static'|'main'|'vue'} side which selector of each role and page path to use
 * @param {{pages?: string, viewports?: string, schemes?: string}} options comma separated filters
 * @returns {Promise<object>} raw measurements keyed by page id and `WxH/scheme`
 */
export async function measureSite(siteDirectory, side, options = {}) {
  const config = JSON.parse(read('harness.json'));
  const roles = JSON.parse(read('roles.json'));
  const measureSource = read('measure.js');
  const wanted = options.pages ? new Set(options.pages.split(',')) : null;
  const pages = JSON.parse(read('pages.json')).filter((page) => page[side] && (!wanted || wanted.has(page.id)));
  const viewports = (options.viewports || config.viewports.join(',')).split(',');
  const schemes = (options.schemes || config.schemes.join(',')).split(',');

  const server = await serve(resolve(siteDirectory));
  const browser = await launchBrowser();
  const results = {};
  const measureVariant = async (viewport, scheme) => {
    const [width, height] = viewport.split('x').map(Number);
    const context = await browser.newContext({
      viewport: { width, height }, colorScheme: scheme, deviceScaleFactor: 1, reducedMotion: 'no-preference',
    });
    try {
      for (const page of pages) {
        const tab = await context.newPage();
        await tab.goto(server.base + page[side], { waitUntil: 'load', timeout: 60000 });
        try {
          await tab.waitForSelector(config.readySelector[side], { state: 'attached', timeout: 20000 });
        } catch { /* recorded as missing roles */ }
        await tab.evaluate(() => document.fonts && document.fonts.ready);
        await tab.waitForTimeout(config.settleMilliseconds[side]);
        const pageRoles = Object.fromEntries(
          Object.entries(roles).filter(([, role]) => !role.kinds || role.kinds.includes(page.kind))
        );
        const measurement = await tab.evaluate(
          `(${measureSource})(${JSON.stringify(pageRoles)}, ${JSON.stringify(side)}, ${JSON.stringify(config.properties)})`
        );
        (results[page.id] ??= {})[`${viewport}/${scheme}`] = measurement;
        await tab.close();
      }
    } finally {
      await context.close();
    }
  };
  try {
    // Variants run concurrently, each in its own browser context
    await Promise.all(viewports.flatMap((viewport) => schemes.map((scheme) => measureVariant(viewport, scheme))));
    // Keep the variant order of the configuration, whatever order they finished in
    for (const [pageId, variants] of Object.entries(results)) {
      const ordered = {};
      for (const viewport of viewports) for (const scheme of schemes) ordered[`${viewport}/${scheme}`] = variants[`${viewport}/${scheme}`];
      results[pageId] = ordered;
    }
  } finally {
    await browser.close();
    await server.close();
  }
  return results;
}
