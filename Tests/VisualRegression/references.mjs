#!/usr/bin/env node
// Regenerates the golden reference data of a built-in theme.
//
// Usage:
//   node Tests/VisualRegression/references.mjs --theme default [--docc <executable>]
//   node Tests/VisualRegression/references.mjs --theme docc-static-classic \
//        --main-docc-static <executable built from the main branch>
//   node Tests/VisualRegression/references.mjs --theme <name> --site <directory>
//   (common options: [--work <directory>] [--keep])
//
// Each theme is compared with a reference renderer (see "references" in harness.json):
//  - `default` with swift-docc-render: every module of the fixture package is converted
//    with `docc convert --transform-for-static-hosting` and the archives are combined
//    with `docc merge`; the result is measured once its JavaScript has rendered.
//  - `docc-static-classic` with the swift-docc-static generator of the main branch.
// The fixture's symbol graphs are built once with `swift build -emit-symbol-graph`.  The
// main branch generator cannot render a symbol graph that only extends another module
// on its own, so extension graphs (`Module@Other.symbols.json`) are left out for it.
//
// With --site, an already rendered reference site is measured instead.  The golden data
// is written to golden/<theme>.json.
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compactMeasurement, parseArguments, stringifyMeasurement, temporaryLocation } from './lib/common.mjs';
import { measureSite } from './lib/measure-site.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(here, '..', '..');
const args = parseArguments(process.argv.slice(2));
const config = JSON.parse(readFileSync(join(here, 'harness.json'), 'utf8'));
const theme = args.theme;
const side = config.references[theme];
if (!side) {
  console.error(`usage: references.mjs --theme ${Object.keys(config.references).join('|')} ...`);
  process.exit(2);
}

/** Runs a command, failing loudly. */
function run(command, commandArgs) {
  const result = spawnSync(command, commandArgs, { stdio: ['ignore', 'ignore', 'inherit'] });
  if (result.status !== 0) {
    console.error(`Command failed: ${command} ${commandArgs.join(' ')}`);
    process.exit(1);
  }
}

/** Returns the path of the docc executable. */
function doccExecutable() {
  if (args.docc) return args.docc;
  const xcrun = spawnSync('xcrun', ['--find', 'docc'], { encoding: 'utf8' });
  return xcrun.status === 0 ? xcrun.stdout.trim() : 'docc';
}

/** Copies the fixture package and builds its symbol graphs; returns the work locations. */
function prepare(work) {
  const fixture = join(work, 'package');
  const graphs = join(work, 'symbol-graphs');
  for (const directory of [fixture, graphs]) rmSync(directory, { recursive: true, force: true });
  mkdirSync(graphs, { recursive: true });
  cpSync(join(packageRoot, 'Tests', 'Fixtures', 'SidebarFixture'), fixture, { recursive: true });
  run('swift', ['build', '--package-path', fixture, '--scratch-path', join(work, 'build'),
    '-Xswiftc', '-emit-symbol-graph', '-Xswiftc', '-emit-symbol-graph-dir', '-Xswiftc', graphs]);
  return { fixture, graphs };
}

/** Renders the fixture with swift-docc-render (static hosting) into `work/site`. */
function renderWithDocC(work) {
  const { fixture, graphs } = prepare(work);
  const docc = doccExecutable();
  const site = join(work, 'site');
  rmSync(site, { recursive: true, force: true });
  const archives = [];
  const sources = join(fixture, 'Sources');
  for (const module of readdirSync(sources).sort()) {
    const catalogue = readdirSync(join(sources, module)).find((name) => name.endsWith('.docc'));
    const moduleGraphs = join(work, `symbol-graphs-${module}`);
    rmSync(moduleGraphs, { recursive: true, force: true });
    mkdirSync(moduleGraphs, { recursive: true });
    for (const graph of readdirSync(graphs)) {
      if (graph === `${module}.symbols.json` || graph.startsWith(`${module}@`)) {
        cpSync(join(graphs, graph), join(moduleGraphs, graph));
      }
    }
    const archive = join(work, `${module}.doccarchive`);
    rmSync(archive, { recursive: true, force: true });
    run(docc, ['convert', ...(catalogue ? [join(sources, module, catalogue)] : []),
      '--additional-symbol-graph-dir', moduleGraphs,
      '--fallback-display-name', module, '--fallback-bundle-identifier', module,
      '--output-path', archive, '--transform-for-static-hosting']);
    archives.push(archive);
  }
  run(docc, ['merge', ...archives, '--output-path', site]);
  return site;
}

/** Renders the fixture with the main branch generator into `work/site`. */
function renderWithMain(work) {
  if (!args['main-docc-static']) {
    console.error('--main-docc-static <executable built from the main branch> is required');
    process.exit(2);
  }
  const { fixture, graphs } = prepare(work);
  const mainGraphs = join(work, 'symbol-graphs-main');
  rmSync(mainGraphs, { recursive: true, force: true });
  mkdirSync(mainGraphs, { recursive: true });
  for (const graph of readdirSync(graphs)) if (!graph.includes('@')) cpSync(join(graphs, graph), join(mainGraphs, graph));
  const site = join(work, 'site');
  rmSync(site, { recursive: true, force: true });
  run(args['main-docc-static'], ['generate', '--package-path', fixture, '--symbol-graph-dir', mainGraphs, '--output', site]);
  return site;
}

const work = resolve(args.work || join(temporaryLocation('docc-static-visual-regression-references', packageRoot), theme));
mkdirSync(work, { recursive: true });
const site = args.site ? resolve(args.site) : side === 'vue' ? renderWithDocC(work) : renderWithMain(work);
if (!existsSync(site)) {
  console.error(`No reference site at ${site}`);
  process.exit(1);
}
console.error(`Measuring the ${side} reference for '${theme}'...`);
const results = await measureSite(site, side);
const goldenFile = join(here, 'golden', `${theme}.json`);
mkdirSync(dirname(goldenFile), { recursive: true });
writeFileSync(goldenFile, stringifyMeasurement({ side, pages: compactMeasurement(results) }));
if (!args.keep && !args.work) rmSync(work, { recursive: true, force: true });
console.error(`Wrote ${goldenFile}`);
