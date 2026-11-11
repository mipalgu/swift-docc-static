#!/usr/bin/env node
// Checks that a generated site works with JavaScript disabled.
//
// Usage:
//   node Tests/VisualRegression/nojs.mjs --site <directory> [--json <file>]
//
// Every page in pages.json is loaded at the first configured viewport with JavaScript
// disabled.  For each page the check records whether the content renders (the page
// title is visible) and, for documentation pages, whether the embedded sidebar loads,
// whether the current page's row is the highlighted target row and is visible below
// the title of its module, and whether a collapsed row can be expanded and collapsed
// again by clicking its chevron.
// On documentation pages with breadcrumbs, the check also records whether the
// breadcrumbs follow the width of the content area like swift-docc-render: closing the
// navigator at the first viewport shows as many of them as the widest viewport (whose
// content area is as wide), and never fewer than with the navigator open.
// On every page with a colour scheme toggle, the check also chooses Light while the
// system appearance is dark (and Dark while it is light), scrolling to the toggle as a
// reader would, and records whether the page then shows the same colours as when that
// scheme is chosen under a matching system appearance.
// The results are printed, and written as JSON with --json; the exit status is 1 if a
// check fails.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArguments } from './lib/common.mjs';
import { launchBrowser } from './lib/playwright.mjs';
import { serve } from './lib/server.mjs';
import { waitForSettledPage } from './lib/settle.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = parseArguments(process.argv.slice(2));
if (!args.site) {
  console.error('usage: nojs.mjs --site <directory> [--json <file>]');
  process.exit(2);
}
const config = JSON.parse(readFileSync(join(here, 'harness.json'), 'utf8'));
const pages = JSON.parse(readFileSync(join(here, 'pages.json'), 'utf8')).filter((page) => page.static);
const [width, height] = config.variants[0].split('/')[0].split('x').map(Number);
const titleSelector = 'main h1, .tutorial-hero h1, .overview-hero h1, .index-header h1';
const schemeSelectors = ['body', 'nav', '.nav__background', '.nav__background::after', 'main', 'h1', '.hero',
  '.code-listing', '.footer'];
const toggleLabel = (scheme) => `.color-scheme-toggle label:has(input[value="${scheme}"])`;

// Returns the colours of the first element matching each of the scheme selectors.
async function sampleColours(tab) {
  return tab.evaluate((selectors) => selectors.map((selector) => {
    const [elementSelector, pseudo] = selector.split(/(?=::)/);
    const element = document.querySelector(elementSelector);
    if (!element) return null;
    const style = getComputedStyle(element, pseudo);
    return [style.color, style.backgroundColor, style.borderTopColor];
  }), schemeSelectors);
}

// Returns the number of breadcrumbs shown on a tab.
function visibleBreadcrumbs(tab) {
  return tab.evaluate(() => [...document.querySelectorAll('.hierarchy > .hierarchy-item, .hierarchy > .hierarchy-collapsed-items')]
    .filter((item) => item.getClientRects().length > 0).length);
}

// Returns the number of breadcrumbs a page shows at the widest viewport.
async function breadcrumbsAtWidestViewport(url) {
  const [widest, tallest] = config.variants.map((variant) => variant.split('/')[0].split('x').map(Number))
    .sort((a, b) => b[0] - a[0])[0];
  const context = await browser.newContext({ viewport: { width: widest, height: tallest }, javaScriptEnabled: false });
  try {
    const tab = await context.newPage();
    await tab.goto(url, { waitUntil: 'load' });
    await waitForSettledPage(tab);
    return await visibleBreadcrumbs(tab);
  } finally {
    await context.close();
  }
}

// Loads a page in a context of the given system appearance, chooses a scheme with the
// toggle and returns the colours (or undefined without a toggle).
async function coloursOf(url, systemScheme, choice) {
  const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled: false,
    colorScheme: systemScheme, reducedMotion: 'reduce' });
  try {
    const tab = await context.newPage();
    await tab.goto(url, { waitUntil: 'load' });
    await waitForSettledPage(tab);
    const label = tab.locator(toggleLabel(choice));
    if ((await label.count()) === 0 || !(await label.first().isVisible())) return undefined;
    await label.first().click();
    await waitForSettledPage(tab);
    return await sampleColours(tab);
  } finally {
    await context.close();
  }
}

const server = await serve(resolve(args.site));
const browser = await launchBrowser();
const results = [];
try {
  const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled: false });
  for (const page of pages) {
    const tab = await context.newPage();
    await tab.goto(server.base + page.static, { waitUntil: 'load' });
    await waitForSettledPage(tab);
    const checks = {};
    checks.content = await tab.evaluate((selector) => {
      const title = document.querySelector(selector);
      if (!title) return false;
      const box = title.getBoundingClientRect();
      return box.width > 0 && box.height > 0 && title.textContent.trim().length > 0;
    }, titleSelector);
    if (page.kind === 'documentation') {
      const frame = tab.frames().find((candidate) => candidate !== tab.mainFrame() && /sidebar\.html/.test(candidate.url()));
      checks.sidebar = Boolean(frame) && (await frame.evaluate(() => document.querySelectorAll('.navigator-card-item').length > 0));
      if (frame) {
        const hasOwnRow = await frame.evaluate(() => Boolean(document.querySelector('.navigator-card-item:target, .module-header:target, .technology-title:target')));
        if (hasOwnRow) {
          checks.currentRow = await frame.evaluate(() => {
            const row = document.querySelector('.navigator-card-item:target, .module-header:target, .technology-title:target');
            const box = row.getBoundingClientRect();
            // A row is highlighted through its head, a module through its title link
            const highlighted = [row, row.querySelector(':scope > .head-wrapper, :scope > .technology-title')].filter(Boolean).some((element) => {
              const background = getComputedStyle(element).backgroundColor;
              return background !== 'rgba(0, 0, 0, 0)' && background !== 'transparent';
            });
            return box.height > 0 && highlighted;
          });
          // Like swift-docc-render, the navigator shows the title of the current
          // module and the current row, neither hidden behind the other
          checks.moduleTitle = await frame.evaluate(() => {
            const row = document.querySelector('.navigator-card-item:target, .module-header:target, .technology-title:target');
            const scroller = row.closest('.scroller');
            const title = (row.closest('.module-section') || document).querySelector('.technology-title');
            if (!scroller || !title) return false;
            const area = scroller.getBoundingClientRect();
            const rowBox = row.getBoundingClientRect();
            const titleBox = title.getBoundingClientRect();
            const inside = (box) => box.height > 0 && box.top >= area.top - 1 && box.bottom <= area.bottom + 1;
            return inside(rowBox) && inside(titleBox) && (row.contains(title) || rowBox.top >= titleBox.bottom - 1);
          });
        }
        const toggle = await frame.evaluateHandle(() => {
          for (const row of document.querySelectorAll('li.navigator-card-item.expandable:not(:target)')) {
            const wrapper = row.nextElementSibling;
            const label = row.querySelector('.tree-toggle');
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
          await waitForSettledPage(tab);
          const expanded = (await wrapperHeight()) > 0;
          await toggle.asElement().click();
          await waitForSettledPage(tab);
          checks.expandCollapse = expanded && (await wrapperHeight()) === 0;
        }
      }
    }
    const url = server.base + page.static;
    if (page.kind === 'documentation' && (await tab.locator('.hierarchy').count()) > 0) {
      const withNavigator = await visibleBreadcrumbs(tab);
      await tab.locator('.documentation-nav .sidenav-toggle').first().click();
      await waitForSettledPage(tab);
      const withoutNavigator = await visibleBreadcrumbs(tab);
      checks.breadcrumbs = withoutNavigator >= withNavigator
        && withoutNavigator === (await breadcrumbsAtWidestViewport(url));
    }
    await tab.close();
    for (const [system, choice] of [['dark', 'light'], ['light', 'dark']]) {
      const chosen = await coloursOf(url, system, choice);
      if (chosen === undefined) continue;
      const reference = await coloursOf(url, choice, choice);
      checks[`${choice}Choice`] = JSON.stringify(chosen) === JSON.stringify(reference);
    }
    results.push({ page: page.id, checks });
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
