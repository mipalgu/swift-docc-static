#!/usr/bin/env node
// Measures the semantic roles of a rendered documentation site.
//
// Usage:
//   node measure.mjs --site <directory> --side static|main|vue --out <file.json>
//                    [--pages id,id] [--viewports 1440x900,390x844] [--schemes light,dark]
//                    [--probe]
//
// The site is served over HTTP from a free local port for the duration of the run.
// Every page in pages.json is loaded once per viewport and colour scheme in a fresh
// browser context, the in-page function in measure.js is evaluated, and the results are
// written to one JSON file.  With --probe, a table of match counts per role and page is
// printed instead, which helps when editing roles.json.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compactMeasurement, parseArguments, stringifyMeasurement } from './lib/common.mjs';
import { measureSite } from './lib/measure-site.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = parseArguments(process.argv.slice(2));
const roles = JSON.parse(readFileSync(join(here, 'roles.json'), 'utf8'));

const side = args.side;
if (!['static', 'main', 'vue'].includes(side) || !args.site) {
  console.error('usage: measure.mjs --site <directory> --side static|main|vue --out <file.json>');
  process.exit(2);
}

const results = await measureSite(args.site, side, {
  pages: args.pages, viewports: args.viewports, schemes: args.schemes,
});
if (args.probe !== undefined) {
  const ids = Object.keys(results);
  console.log(['role'.padEnd(34), ...ids.map((id) => id.slice(0, 9).padStart(10))].join(''));
  for (const role of Object.keys(roles).sort()) {
    const cells = ids.map((id) => {
      const entry = results[id][Object.keys(results[id])[0]].roles[role];
      if (!entry) return '-'.padStart(10);
      return `${entry.found}${entry.visible ? '' : entry.found ? 'h' : ''}`.padStart(10);
    });
    console.log([role.padEnd(34), ...cells].join(''));
  }
} else {
  const output = stringifyMeasurement({ side, pages: compactMeasurement(results) });
  if (args.out) {
    mkdirSync(dirname(resolve(args.out)), { recursive: true });
    writeFileSync(args.out, output);
  } else {
    process.stdout.write(output);
  }
}
