#!/usr/bin/env node
// Checks that a generated site works with JavaScript disabled.
//
// Usage:
//   node Tests/VisualRegression/nojs.mjs --site <directory> [--json <file>]
//
// Every page in pages.json is loaded at the first configured viewport with JavaScript
// disabled.  For each page the check records whether the content renders (the page
// title is visible) and, for documentation pages, whether the embedded sidebar loads,
// whether the current page's row is the highlighted target row and is visible, and
// whether a collapsed row can be expanded and collapsed again by clicking its chevron.
// The results are printed, and written as JSON with --json; the exit status is 1 if a
// check fails.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArguments } from './lib/common.mjs';
import { launchBrowser } from './lib/playwright.mjs';
import { serve } from './lib/server.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = parseArguments(process.argv.slice(2));
if (!args.site) {
  console.error('usage: nojs.mjs --site <directory> [--json <file>]');
  process.exit(2);
}
const config = JSON.parse(readFileSync(join(here, 'harness.json'), 'utf8'));
const pages = JSON.parse(readFileSync(join(here, 'pages.json'), 'utf8')).filter((page) => page.static);
const [width, height] = config.viewports[0].split('x').map(Number);
const titleSelector = 'main h1, .tutorial-hero h1, .overview-hero h1, .index-header h1';

const server = await serve(resolve(args.site));
const browser = await launchBrowser();
const results = [];
try {
  const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled: false });
  for (const page of pages) {
    const tab = await context.newPage();
    await tab.goto(server.base + page.static, { waitUntil: 'load' });
    const checks = {};
    checks.content = await tab.evaluate((selector) => {
      const title = document.querySelector(selector);
      if (!title) return false;
      const box = title.getBoundingClientRect();
      return box.width > 0 && box.height > 0 && title.textContent.trim().length > 0;
    }, titleSelector);
    if (page.kind === 'documentation') {
      const frame = tab.frames().find((candidate) => candidate !== tab.mainFrame() && /sidebar\.html/.test(candidate.url()));
      checks.sidebar = Boolean(frame) && (await frame.evaluate(() => document.querySelectorAll('.navigator-card').length > 0));
      if (frame) {
        const hasOwnRow = await frame.evaluate(() => Boolean(document.querySelector('.navigator-card:target, .module-header:target')));
        if (hasOwnRow) {
          checks.currentRow = await frame.evaluate(() => {
            const row = document.querySelector('.navigator-card:target, .module-header:target');
            const box = row.getBoundingClientRect();
            // A module's row is highlighted through its title link
            const highlighted = [row, row.querySelector(':scope > .technology-title')].filter(Boolean).some((element) => {
              const background = getComputedStyle(element).backgroundColor;
              return background !== 'rgba(0, 0, 0, 0)' && background !== 'transparent';
            });
            return box.height > 0 && highlighted;
          });
        }
        const toggle = await frame.evaluateHandle(() => {
          for (const row of document.querySelectorAll('li.navigator-card.expandable:not(:target)')) {
            const wrapper = row.nextElementSibling;
            const label = row.querySelector('.disclosure-chevron');
            const chevron = label && (label.querySelector('svg') || label);
            if (!wrapper || !chevron) continue;
            if (wrapper.getBoundingClientRect().height === 0 && chevron.getBoundingClientRect().height > 0) {
              row.setAttribute('data-nojs-check', '');
              return chevron;
            }
          }
          return null;
        });
        if (await toggle.evaluate((element) => element !== null)) {
          const wrapperHeight = () => frame.evaluate(() =>
            document.querySelector('[data-nojs-check]').nextElementSibling.getBoundingClientRect().height);
          await toggle.asElement().click();
          await tab.waitForTimeout(400);
          const expanded = (await wrapperHeight()) > 0;
          await toggle.asElement().click();
          await tab.waitForTimeout(400);
          checks.expandCollapse = expanded && (await wrapperHeight()) === 0;
        }
      }
    }
    results.push({ page: page.id, checks });
    await tab.close();
  }
  await context.close();
} finally {
  await browser.close();
  await server.close();
}

let failed = false;
for (const { page, checks } of results) {
  const line = Object.entries(checks).map(([name, ok]) => `${name}=${ok ? 'ok' : 'FAILED'}`).join(' ');
  if (Object.values(checks).includes(false)) failed = true;
  console.log(`${page.padEnd(24)} ${line}`);
}
if (args.json) {
  mkdirSync(dirname(resolve(args.json)), { recursive: true });
  writeFileSync(args.json, JSON.stringify(results, null, 1) + '\n');
}
process.exit(failed ? 1 : 0);
