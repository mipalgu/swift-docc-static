#!/usr/bin/env node
// Checks that the "On This Page" column highlights the section in view like
// swift-docc-render, with JavaScript disabled.
//
// Usage:
//   node Tests/VisualRegression/onthispage.mjs --site <directory> [--json <file>] [--javascript]
//
// Every documentation page in pages.json whose "On This Page" column lists sections is
// loaded in a window wide enough to show the column and left to settle (no transition
// running, the layout no longer changing).  The page is scrolled to the top,
// to the bottom, and to just before and just after the point where each section heading
// reaches the line 30% down the window.  At each position the check compares the
// highlighted items (the links shown in the text colour), once the page reflects the
// position and the colour transitions have finished, with the item swift-docc-render
// marks: the first item at the top, the last item at the bottom, and otherwise the last
// item whose heading lies above that line.  A heading that moves after the positions
// were chosen fails the check.  It also checks that the highlight colour
// changes with the 0.15s ease-in transition of swift-docc-render.  The results are
// printed, and written as JSON with --json; the exit status is 1 if a check fails.
// --javascript runs the check with JavaScript enabled instead.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArguments } from './lib/common.mjs';
import { launchBrowser } from './lib/playwright.mjs';
import { serve } from './lib/server.mjs';
import { scrollAndSettle, waitForSettledPage } from './lib/settle.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = parseArguments(process.argv.slice(2));
if (!args.site) {
  console.error('usage: onthispage.mjs --site <directory> [--json <file>] [--javascript]');
  process.exit(2);
}
const pages = JSON.parse(readFileSync(join(here, 'pages.json'), 'utf8'))
  .filter((page) => page.static && page.kind === 'documentation');
const viewport = { width: 1920, height: 1080 };

// Returns the scroll positions to check and the item swift-docc-render marks at each.
function positionsInPage() {
  const links = [...document.querySelectorAll('.OnThisPageNav li > a')];
  const anchors = links.map((link) => document.getElementById(decodeURIComponent(link.hash.slice(1))));
  const maximum = document.documentElement.scrollHeight - innerHeight;
  const line = innerHeight * 0.3;
  const tops = anchors.map((anchor) => (anchor ? anchor.getBoundingClientRect().top + scrollY : Infinity));
  const candidates = new Set([0, maximum, Math.round(maximum / 2)]);
  for (const top of tops.slice(1)) {
    for (const offset of [-8, 8]) {
      const position = Math.round(top - line + offset);
      if (position > 0 && position < maximum) candidates.add(position);
    }
  }
  return [...candidates].sort((a, b) => a - b).map((position) => {
    let expected;
    if (position <= 0) expected = 0;
    else if (position >= maximum) expected = links.length - 1;
    else {
      expected = 0;
      tops.forEach((top, index) => { if (top < position + line) expected = index; });
    }
    return { position, expected, tops };
  });
}

// Returns the top of each item's section heading in page coordinates.
function headingTopsInPage() {
  return [...document.querySelectorAll('.OnThisPageNav li > a')].map((link) => {
    const anchor = document.getElementById(decodeURIComponent(link.hash.slice(1)));
    return anchor ? anchor.getBoundingClientRect().top + scrollY : Infinity;
  });
}

// Returns the indices of the highlighted items and the colour transition of the links.
function highlightedInPage() {
  const nav = document.querySelector('.OnThisPageNav');
  const probe = document.createElement('span');
  probe.style.color = 'var(--color-text)';
  nav.append(probe);
  const active = getComputedStyle(probe).color;
  probe.remove();
  const links = [...nav.querySelectorAll('li > a')];
  const style = getComputedStyle(links[0]);
  return {
    highlighted: links.flatMap((link, index) => (getComputedStyle(link).color === active ? [index] : [])),
    transition: `${style.transitionProperty} ${style.transitionDuration} ${style.transitionTimingFunction}`,
  };
}

const server = await serve(resolve(args.site));
const browser = await launchBrowser();
const results = [];
try {
  const context = await browser.newContext({ viewport, javaScriptEnabled: args.javascript === 'true' });
  for (const page of pages) {
    const tab = await context.newPage();
    await tab.goto(server.base + page.static, { waitUntil: 'load' });
    await waitForSettledPage(tab);
    const visible = await tab.evaluate(() => {
      const nav = document.querySelector('.OnThisPageNav');
      return Boolean(nav) && nav.getBoundingClientRect().width > 0;
    });
    if (!visible) {
      await tab.close();
      continue;
    }
    const checks = { positions: true, transition: true };
    const failures = [];
    for (const { position, expected, tops } of await tab.evaluate(positionsInPage)) {
      await scrollAndSettle(tab, position);
      const moved = (await tab.evaluate(headingTopsInPage)).findIndex((top, index) => Math.abs(top - tops[index]) > 0.5);
      if (moved !== -1) {
        checks.positions = false;
        failures.push(`at ${position}px: the heading of item ${moved} moved after the positions were chosen`);
      }
      const { highlighted, transition } = await tab.evaluate(highlightedInPage);
      if (highlighted.length !== 1 || highlighted[0] !== expected) {
        checks.positions = false;
        failures.push(`at ${position}px: expected item ${expected}, highlighted [${highlighted}]`);
      }
      if (transition !== 'color 0.15s ease-in') {
        checks.transition = false;
        failures.push(`transition ${transition}`);
      }
    }
    results.push({ page: page.id, checks, failures });
    await tab.close();
  }
  await context.close();
} finally {
  await browser.close();
  await server.close();
}

let failed = false;
for (const { page, checks, failures } of results) {
  const line = Object.entries(checks).map(([name, ok]) => `${name}=${ok ? 'ok' : 'FAILED'}`).join(' ');
  if (Object.values(checks).includes(false)) failed = true;
  console.log(`${page.padEnd(24)} ${line}`);
  for (const failure of failures) console.log(`  ${failure}`);
}
if (args.json) {
  mkdirSync(dirname(resolve(args.json)), { recursive: true });
  writeFileSync(args.json, JSON.stringify(results, null, 1) + '\n');
}
process.exit(failed ? 1 : 0);
