#!/usr/bin/env node
// Prints the current mismatch table of a theme against its golden reference data.
//
// Usage:
//   node Tests/VisualRegression/run.mjs --theme <name> [--site <directory>]
//        [--scratch-path <directory>] [--docc-static <executable>]
//        [--pages id,id] [--all] [--json <file>] [--prune-known]
//
// Without --site, the fixture package is rendered first: docc-static is built with
// `swift run` (or the executable given with --docc-static is used) and the fixture in
// Tests/Fixtures/SidebarFixture is generated with the theme into a temporary directory.
// The rendered site is then measured in a browser and compared with
// golden/<theme>.json.  The table lists one line per role and property with the number
// of occurrences, the first example and whether the pair is on the theme's known-issue
// list (known-issues/<theme>.json); --all lists every occurrence instead.
//
// Mismatches covered by the theme's accepted deviations (accepted-deviations/<theme>.json)
// are reported separately and are neither known issues nor unexpected.  The exit status
// is 0 when every other mismatch is a known issue, every known issue still occurs and
// every accepted deviation still covers a mismatch, and 1 otherwise.  --json writes the mismatches as JSON (used by the Swift tests).
// --prune-known removes the pairs that no longer occur from the known-issue list; the
// list is never extended automatically, so it can only shrink.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compareMeasurements, describeDeviation, expandMeasurement, formatTable, issueKey, parseArguments, partitionMismatches, temporaryLocation } from './lib/common.mjs';
import { measureSite } from './lib/measure-site.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(here, '..', '..');
const args = parseArguments(process.argv.slice(2));
const theme = args.theme;
if (!theme) {
  console.error('usage: run.mjs --theme <name> [--site <directory>] [--all] [--json <file>]');
  process.exit(2);
}
const goldenFile = join(here, 'golden', `${theme}.json`);
if (!existsSync(goldenFile)) {
  console.error(`No golden data for theme '${theme}' (${goldenFile}).`);
  process.exit(2);
}

/** Renders the fixture package with the theme and returns the site directory. */
function renderFixture() {
  const work = join(temporaryLocation('docc-static-visual-regression', packageRoot), theme);
  const fixture = join(work, 'package');
  const site = join(work, 'site');
  rmSync(fixture, { recursive: true, force: true });
  rmSync(site, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  cpSync(join(packageRoot, 'Tests', 'Fixtures', 'SidebarFixture'), fixture, { recursive: true });
  const generate = ['generate', '--package-path', fixture, '--output', site,
    '--scratch-path', join(work, 'fixture-build'), '--theme', theme];
  const [command, commandArgs] = args['docc-static']
    ? [args['docc-static'], generate]
    : ['swift', ['run', '--package-path', packageRoot,
        '--scratch-path', args['scratch-path'] || temporaryLocation('docc-static-visual-regression-build', packageRoot),
        'docc-static', ...generate]];
  console.error(`Rendering the fixture with theme '${theme}'...`);
  const run = spawnSync(command, commandArgs, { stdio: ['ignore', 'ignore', 'inherit'] });
  if (run.status !== 0) {
    console.error('Rendering the fixture failed.');
    process.exit(2);
  }
  return site;
}

const site = args.site ? resolve(args.site) : renderFixture();
const config = JSON.parse(readFileSync(join(here, 'harness.json'), 'utf8'));
const roles = JSON.parse(readFileSync(join(here, 'roles.json'), 'utf8'));
const knownFile = join(here, 'known-issues', `${theme}.json`);
const known = new Set(existsSync(knownFile) ? JSON.parse(readFileSync(knownFile, 'utf8')).mismatches ?? [] : []);
const deviationsFile = join(here, 'accepted-deviations', `${theme}.json`);
const deviations = existsSync(deviationsFile) ? JSON.parse(readFileSync(deviationsFile, 'utf8')).deviations ?? [] : [];

let golden = expandMeasurement(JSON.parse(readFileSync(goldenFile, 'utf8')).pages);
if (args.pages) {
  const wanted = new Set(args.pages.split(','));
  golden = Object.fromEntries(Object.entries(golden).filter(([id]) => wanted.has(id)));
}
console.error(`Measuring ${site}...`);
const actual = await measureSite(site, 'static', { pages: args.pages });
const { accepted, remaining: mismatches, unused } = partitionMismatches(compareMeasurements(golden, actual, roles, config), deviations);
const unusedDeviations = args.pages ? [] : unused;

if (args.json) {
  mkdirSync(dirname(resolve(args.json)), { recursive: true });
  writeFileSync(args.json, JSON.stringify({
    theme, mismatches, accepted, unusedDeviations: unusedDeviations.map(describeDeviation),
  }, null, 1) + '\n');
}

if (deviations.length) {
  const counts = deviations.map((_, index) => accepted.filter((mismatch) => mismatch.deviation === index).length);
  console.log(`Accepted deviations (accepted-deviations/${theme}.json):`);
  deviations.forEach((deviation, index) => {
    console.log(`  ${describeDeviation(deviation)}: ${counts[index]} mismatches - ${deviation.reason}`);
  });
  console.log('');
}

const keys = new Set(mismatches.map(issueKey));
const unexpected = [...keys].filter((key) => !known.has(key)).sort();
const fixed = args.pages ? [] : [...known].filter((key) => !keys.has(key)).sort();
if (mismatches.length) console.log(formatTable(mismatches, { all: args.all !== undefined, known }));
console.log(`\n${theme}: ${mismatches.length} mismatches in ${keys.size} role/property pairs; ` +
  `${known.size} known issues, ${unexpected.length} unexpected, ${fixed.length} no longer occurring; ` +
  `${accepted.length} mismatches covered by ${deviations.length} accepted deviations.`);
if (unexpected.length) console.log(`Unexpected (not in known-issues/${theme}.json):\n  ${unexpected.join('\n  ')}`);
if (fixed.length) console.log(`Fixed (remove from known-issues/${theme}.json):\n  ${fixed.join('\n  ')}`);
if (unusedDeviations.length) {
  console.log(`Accepted deviations that cover no mismatch (remove from accepted-deviations/${theme}.json):\n  ` +
    unusedDeviations.map(describeDeviation).join('\n  '));
}
if (args['prune-known'] !== undefined && fixed.length) {
  const list = JSON.parse(readFileSync(knownFile, 'utf8'));
  list.mismatches = list.mismatches.filter((key) => keys.has(key));
  writeFileSync(knownFile, JSON.stringify(list, null, 1) + '\n');
  console.log(`Removed ${fixed.length} fixed pairs from known-issues/${theme}.json.`);
  process.exit(unexpected.length ? 1 : 0);
}
process.exit(unexpected.length || fixed.length || unusedDeviations.length ? 1 : 0);
