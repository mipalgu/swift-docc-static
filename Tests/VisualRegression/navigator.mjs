#!/usr/bin/env node
// Checks where the navigator scrolls the current page's row, like swift-docc-render.
//
// Usage:
//   node Tests/VisualRegression/navigator.mjs --site <directory> [--json <file>]
//
// Every documentation page in pages.json is loaded in a tall and in a short window,
// with JavaScript disabled and enabled.  swift-docc-render leaves the list scrolled
// to the top when the current row is fully visible there (above the list's bottom
// padding; without JavaScript, above the room the stylesheet reserves for a row with
// `--navigator-target-reserve`), and otherwise scrolls the row to the top of the list, below the title of
// its module.  The check records, for each load:
// - `firstScreen`: a row that fits in the first screenful leaves the list unscrolled;
// - `visible`: a row that does not fit is scrolled fully into view, below the title of
//   its module (with JavaScript disabled, where the browser places it);
// - `top`: with JavaScript enabled, such a row is at the top of the list, right below
//   the title of its module, or as close to it as the end of the list allows.
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
  console.error('usage: navigator.mjs --site <directory> [--json <file>]');
  process.exit(2);
}
const pages = JSON.parse(readFileSync(join(here, 'pages.json'), 'utf8'))
  .filter((page) => page.static && page.kind === 'documentation');
const windows = [{ width: 1440, height: 900 }, { width: 1440, height: 500 }];

// Measures the current row in the navigator: its offset in the list, its height, the
// list's height and scroll position, and the bottom of the title above the row.
function measureRow() {
  const row = document.querySelector('.navigator-card-item:target, .module-header:target, .technology-title:target');
  if (!row) return null;
  const scroller = row.closest('.scroller');
  if (!scroller) return null;
  const area = scroller.getBoundingClientRect();
  const box = row.getBoundingClientRect();
  const section = row.closest('.module-section');
  const header = section ? section.querySelector('.module-header') : null;
  const title = header && !header.contains(row) && !row.contains(header) ? header.getBoundingClientRect().bottom - area.top : 0;
  return {
    scrollTop: scroller.scrollTop,
    offset: box.top - area.top + scroller.scrollTop,
    position: box.top - area.top,
    height: box.height,
    listHeight: scroller.clientHeight,
    maximumScrollTop: scroller.scrollHeight - scroller.clientHeight,
    bottomPadding: parseFloat(getComputedStyle(scroller).paddingBottom) || 0,
    reserve: parseFloat(getComputedStyle(row).getPropertyValue('--navigator-target-reserve')) || 0,
    title,
  };
}

const server = await serve(resolve(args.site));
const browser = await launchBrowser();
const results = [];
try {
  for (const page of pages) {
    const checks = {};
    const details = [];
    for (const { width, height } of windows) {
      for (const javaScriptEnabled of [false, true]) {
        const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled });
        try {
          const tab = await context.newPage();
          await tab.goto(server.base + page.static, { waitUntil: 'load' });
          await waitForSettledPage(tab);
          const frame = tab.frames().find((candidate) => candidate !== tab.mainFrame() && /sidebar\.html/.test(candidate.url()));
          const row = frame ? await frame.evaluate(measureRow) : null;
          if (!row) continue;
          const condition = `${width}x${height} JavaScript ${javaScriptEnabled ? 'on' : 'off'}`;
          details.push({ condition, ...row });
          // Without JavaScript the stylesheet cannot tell a row's height and reserves
          // room for the tallest row it expects at the bottom of the first screenful
          const reserved = javaScriptEnabled ? row.height : Math.max(row.height, row.reserve);
          const fits = row.offset + reserved < row.listHeight - row.bottomPadding;
          const and = (name, value) => { checks[name] = (checks[name] ?? true) && value; };
          if (fits) {
            and('firstScreen', row.scrollTop === 0);
          } else {
            and('visible', row.position >= row.title - 1 && row.position + row.height <= row.listHeight + 1);
            // At the end of the list the row stays as close to the top as it can
            const atEnd = Math.abs(row.scrollTop - row.maximumScrollTop) <= 1;
            if (javaScriptEnabled) and('top', Math.abs(row.position - row.title) <= 1 || (atEnd && row.position > row.title));
          }
        } finally {
          await context.close();
        }
      }
    }
    results.push({ page: page.id, checks, details });
  }
} finally {
  await browser.close();
  await server.close();
}

let failed = false;
for (const { page, checks, details } of results) {
  const line = Object.entries(checks).map(([name, ok]) => `${name}=${ok ? 'ok' : 'FAILED'}`).join(' ');
  if (Object.values(checks).includes(false)) {
    failed = true;
    console.log(`${page.padEnd(24)} ${line}\n${details.map((d) => `    ${JSON.stringify(d)}`).join('\n')}`);
  } else {
    console.log(`${page.padEnd(24)} ${line}`);
  }
}
if (args.json) {
  mkdirSync(dirname(resolve(args.json)), { recursive: true });
  writeFileSync(args.json, JSON.stringify(results, null, 1) + '\n');
}
process.exit(failed ? 1 : 0);
