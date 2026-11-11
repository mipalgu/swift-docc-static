#!/usr/bin/env node
// Checks that pages do not animate while they load.
//
// Usage:
//   node Tests/VisualRegression/loading.mjs --site <directory> [--json <file>] [--runs <n>]
//
// Every page in pages.json is loaded --runs times (default 4) with JavaScript disabled
// and as often with JavaScript enabled, each time once with the stylesheets answered
// at once and once with them answered 40ms late.  A browser may style and lay out a
// page before its stylesheets arrive (for example when the embedded navigation sidebar
// lays out first), so a late stylesheet makes that case happen on every load instead of
// in some loads only.  The check records, through the browser's animation events, every
// transition and animation that starts while the page loads and settles, and fails if
// one runs on a document timeline: only scroll-driven animations, which follow the
// scroll position, may start.  The results are printed, and written as JSON with
// --json; the exit status is 1 if a page animates.
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
  console.error('usage: loading.mjs --site <directory> [--json <file>] [--runs <n>]');
  process.exit(2);
}
const config = JSON.parse(readFileSync(join(here, 'harness.json'), 'utf8'));
const pages = JSON.parse(readFileSync(join(here, 'pages.json'), 'utf8')).filter((page) => page.static);
const runs = Number(args.runs ?? 4);
const lateMilliseconds = 40;
const viewports = [...new Set(config.variants.map((variant) => variant.split('/')[0]))]
  .map((size) => size.split('x').map(Number));

// Describes the element an animation runs on, such as `pre.source` or
// `span.chevron (sidebar.html)`.
async function describeNode(session, backendNodeId) {
  if (!backendNodeId) return 'an unknown element';
  try {
    const { node } = await session.send('DOM.describeNode', { backendNodeId });
    const attributes = node.attributes ?? [];
    const index = attributes.indexOf('class');
    const classes = index >= 0 ? attributes[index + 1].trim().split(/\s+/).filter(Boolean) : [];
    const name = [node.localName || node.nodeName.toLowerCase(), ...classes].join('.');
    return node.pseudoType ? `${name}::${node.pseudoType}` : name;
  } catch {
    return 'an element that went away';
  }
}

// The stylesheets of the current load arrive this late.
let stylesheetDelay = 0;
const server = await serve(resolve(args.site), 0, { delay: (path) => (path.endsWith('.css') ? stylesheetDelay : 0) });
const browser = await launchBrowser();
const results = [];
try {
  for (const page of pages) {
    const animations = new Map();
    let loads = 0;
    for (let run = 0; run < runs; run++) {
      for (const javaScriptEnabled of [false, true]) {
        for (const delay of [0, lateMilliseconds]) {
          const [width, height] = viewports[(loads++) % viewports.length];
          stylesheetDelay = delay;
          const context = await browser.newContext({ viewport: { width, height }, javaScriptEnabled });
          try {
            const tab = await context.newPage();
            const session = await context.newCDPSession(tab);
            session.on('Animation.animationStarted', async ({ animation }) => {
              if (animation.viewOrScrollTimeline) return;
              const target = await describeNode(session, animation.source?.backendNodeId);
              const name = `${animation.type} ${animation.name || '(unnamed)'} on ${target}`;
              const entry = animations.get(name) ?? { count: 0, conditions: new Set() };
              entry.count += 1;
              entry.conditions.add(`${width}x${height}, JavaScript ${javaScriptEnabled ? 'on' : 'off'}, stylesheets ${delay}ms late`);
              animations.set(name, entry);
            });
            await session.send('Animation.enable');
            await tab.goto(server.base + page.static, { waitUntil: 'load' });
            await waitForSettledPage(tab);
          } finally {
            await context.close();
          }
        }
      }
    }
    results.push({
      page: page.id,
      loads,
      animations: [...animations].map(([name, { count, conditions }]) => ({ name, count, conditions: [...conditions] })),
    });
  }
} finally {
  await browser.close();
  await server.close();
}

let failed = false;
for (const { page, loads, animations } of results) {
  if (animations.length) failed = true;
  const summary = animations.length
    ? animations.map(({ name, count, conditions }) => `${name} (${count}x, first: ${conditions[0]})`).join('; ')
    : 'ok';
  console.log(`${page.padEnd(24)} ${loads} loads: ${summary}`);
}
if (args.json) {
  mkdirSync(dirname(resolve(args.json)), { recursive: true });
  writeFileSync(args.json, JSON.stringify(results, null, 1) + '\n');
}
process.exit(failed ? 1 : 0);
