// Shared helpers of the visual regression harness: argument parsing, temporary
// directories, compact storage of measurements, comparison against golden data and
// report formatting.
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/** Parses `--name value`, `--name=value` and bare `--flag` arguments into an object. */
export function parseArguments(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const argument = argv[i];
    if (!argument.startsWith('--')) continue;
    const [name, inline] = argument.slice(2).split(/=(.*)/s, 2);
    if (inline !== undefined) args[name] = inline;
    else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) args[name] = argv[++i];
    else args[name] = 'true';
  }
  return args;
}

/**
 * Returns a key that identifies a checkout without revealing its location: the 64-bit
 * FNV-1a hash of the UTF-8 encoded location as 16 lowercase hexadecimal digits (the
 * Swift tests derive their temporary directory names the same way).
 */
export function checkoutKey(location) {
  let hash = 0xcbf29ce484222325n;
  for (const byte of new TextEncoder().encode(location)) {
    hash ^= BigInt(byte);
    hash = (hash * 0x100000001b3n) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, '0');
}

/**
 * Returns a directory in the system temporary directory that belongs to one checkout,
 * so that harness runs of different checkouts on the same machine never share files.
 */
export function temporaryLocation(prefix, checkout) {
  return join(tmpdir(), `${prefix}-${checkoutKey(checkout)}`);
}

const ENTRY_FIELDS = ['found', 'visible', 'error'];
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/** Returns the differences of a role entry relative to the same role in the base variant. */
function compactEntry(base, entry) {
  const diff = {};
  for (const key of ENTRY_FIELDS) if (entry[key] !== base?.[key]) diff[key] = entry[key] ?? null;
  for (const key of ['style', 'box']) {
    if (!entry[key]) { if (base?.[key]) diff[key] = null; continue; }
    if (!base?.[key]) { diff[key] = entry[key]; continue; }
    const changed = {};
    for (const [name, value] of Object.entries(entry[key])) if (!same(value, base[key][name])) changed[name] = value;
    if (Object.keys(changed).length) diff[key] = changed;
  }
  return diff;
}

/** Restores a role entry from the base variant and its stored differences. */
function expandEntry(base, diff) {
  const entry = structuredClone(base ?? {});
  if (!diff) return entry;
  for (const key of ENTRY_FIELDS) {
    if (!(key in diff)) continue;
    if (diff[key] === null) delete entry[key]; else entry[key] = diff[key];
  }
  for (const key of ['style', 'box']) {
    if (!(key in diff)) continue;
    if (diff[key] === null) delete entry[key];
    else entry[key] = { ...(entry[key] ?? {}), ...diff[key] };
  }
  return entry;
}

/**
 * Stores measurements compactly: the first variant of each page as differences from the
 * first earlier page that measured the same role (in full when there is none), and every
 * other variant of a page as differences from that page's first variant.  This keeps golden files small, because
 * most roles look the same on every page, dark mode mostly changes colours and narrow
 * viewports mostly change spacing.
 */
export function compactMeasurement(results) {
  const pages = {};
  const reference = {};
  for (const [pageId, variants] of Object.entries(results)) {
    const keys = Object.keys(variants);
    const base = variants[keys[0]];
    const page = {};
    for (const key of keys) {
      const variant = variants[key];
      const relativeTo = key === keys[0] ? reference : base.roles;
      const roles = {};
      for (const [role, entry] of Object.entries(variant.roles)) {
        const diff = compactEntry(relativeTo[role], entry);
        if (key === keys[0] || Object.keys(diff).length) roles[role] = diff;
      }
      page[key] = { document: variant.document, roles };
    }
    for (const [role, entry] of Object.entries(base.roles)) if (!reference[role]?.style) reference[role] = entry;
    pages[pageId] = page;
  }
  return pages;
}

/** Restores the full measurements stored by `compactMeasurement`. */
export function expandMeasurement(pages) {
  const results = {};
  const reference = {};
  for (const [pageId, variants] of Object.entries(pages)) {
    const keys = Object.keys(variants);
    results[pageId] = {};
    let base = null;
    for (const key of keys) {
      const stored = variants[key];
      const relativeTo = key === keys[0] ? reference : base;
      // The first variant stores every role the page measures; later variants only
      // store the roles that differ from the first.
      const roles = {};
      const names = key === keys[0] ? Object.keys(stored.roles) : Object.keys(relativeTo);
      for (const role of names) roles[role] = expandEntry(relativeTo[role], stored.roles[role]);
      results[pageId][key] = { document: stored.document, roles };
      if (key === keys[0]) base = roles;
    }
    for (const [role, entry] of Object.entries(base)) if (!reference[role]?.style) reference[role] = entry;
  }
  return results;
}

/** Whether a difference in `property` is irrelevant given both computed styles. */
function ignorable(property, expected, actual) {
  const sideOf = /^border(Top|Right|Bottom|Left)(Color|Style)$/.exec(property);
  if (sideOf) {
    const invisible = (style) => style[`border${sideOf[1]}Width`] === '0px' || style[`border${sideOf[1]}Style`] === 'none';
    return invisible(expected) && invisible(actual);
  }
  if (property === 'textDecorationColor') return expected.textDecorationLine === 'none' && actual.textDecorationLine === 'none';
  if (/^transition(Property|TimingFunction|Delay)$/.test(property)) {
    const still = (style) => style.transitionDuration.split(',').every((duration) => parseFloat(duration) === 0);
    return still(expected) && still(actual);
  }
  return false;
}

/**
 * Compares measurements of the current output with golden measurements.
 *
 * @param {object} golden expanded golden measurements
 * @param {object} actual expanded measurements of the current output
 * @param {object} roles the role map
 * @param {object} config the harness configuration
 * @returns {Array<{role, property, expected, actual, page, viewport, scheme}>} the mismatches
 */
export function compareMeasurements(golden, actual, roles, config) {
  const mismatches = [];
  const record = (page, variant, role, property, expected, actual) => {
    const [viewport, scheme] = variant.split('/');
    mismatches.push({ role, property, expected: String(expected), actual: String(actual), page, viewport, scheme });
  };
  for (const [page, variants] of Object.entries(golden)) {
    for (const [variant, expected] of Object.entries(variants)) {
      const current = actual[page]?.[variant];
      if (!current) { record(page, variant, 'page', 'presence', 'measured', 'missing'); continue; }
      if (expected.document.htmlFontSize !== current.document.htmlFontSize) {
        record(page, variant, 'document', 'htmlFontSize', expected.document.htmlFontSize, current.document.htmlFontSize);
      }
      for (const [role, reference] of Object.entries(expected.roles)) {
        const measured = current.roles[role];
        if (!measured || !roles[role]) continue;
        const shownExpected = Boolean(reference.style && reference.visible);
        const shownActual = Boolean(measured.style && measured.visible);
        if (shownExpected !== shownActual) {
          record(page, variant, role, 'presence', shownExpected ? 'shown' : 'absent', shownActual ? 'shown' : 'absent');
          continue;
        }
        if (!shownExpected) continue;
        for (const property of config.properties) {
          const want = reference.style[property];
          const got = measured.style[property];
          if (want === undefined || want === got || ignorable(property, reference.style, measured.style)) continue;
          record(page, variant, role, property, want, got);
        }
        if (roles[role].geometry && reference.box && measured.box) {
          for (const key of ['x', 'width']) {
            if (Math.abs(reference.box[key] - measured.box[key]) > config.geometryTolerance) {
              record(page, variant, role, `box.${key}`, reference.box[key], measured.box[key]);
            }
          }
        }
      }
    }
  }
  return mismatches;
}

/** The known issue key of a mismatch: the role and property it concerns. */
export const issueKey = (mismatch) => `${mismatch.role}.${mismatch.property}`;

/** The condition fields an accepted deviation may restrict itself with. */
export const DEVIATION_CONDITIONS = ['pages', 'viewports', 'schemes'];

/**
 * Whether an accepted deviation covers a mismatch.
 *
 * A deviation names a role (`"*"` for every role) and a property (`"*"` for every
 * property) and
 * may restrict itself to some pages (page identifiers), viewports (such as
 * `"390x844"`) and colour schemes (`"light"`, `"dark"`); a mismatch is covered when
 * it matches the role, the property and every condition the deviation states.
 *
 * @param {object} mismatch a mismatch as returned by `compareMeasurements`
 * @param {object} deviation an entry of `accepted-deviations/<theme>.json`
 * @returns {boolean} whether the deviation covers the mismatch
 */
export function deviationCovers(mismatch, deviation) {
  if (deviation.role !== '*' && deviation.role !== mismatch.role) return false;
  if (deviation.property !== '*' && deviation.property !== mismatch.property) return false;
  const values = { pages: mismatch.page, viewports: mismatch.viewport, schemes: mismatch.scheme };
  return DEVIATION_CONDITIONS.every((field) => !deviation[field] || deviation[field].includes(values[field]));
}

/**
 * Separates the mismatches that accepted deviations cover from the others.
 *
 * @param {Array<object>} mismatches the mismatches of a run
 * @param {Array<object>} deviations the theme's accepted deviations
 * @returns {{accepted: Array<object>, remaining: Array<object>, unused: Array<object>}} the
 *   covered mismatches (each with the index of its deviation), the uncovered ones, and the
 *   deviations that cover no mismatch
 */
export function partitionMismatches(mismatches, deviations) {
  const accepted = [];
  const remaining = [];
  const used = new Set();
  for (const mismatch of mismatches) {
    const index = deviations.findIndex((deviation) => deviationCovers(mismatch, deviation));
    if (index === -1) {
      remaining.push(mismatch);
    } else {
      used.add(index);
      accepted.push({ ...mismatch, deviation: index });
    }
  }
  return { accepted, remaining, unused: deviations.filter((_, index) => !used.has(index)) };
}

/** A one-line description of an accepted deviation: role, property and conditions. */
export function describeDeviation(deviation) {
  const conditions = DEVIATION_CONDITIONS.filter((field) => deviation[field])
    .map((field) => `${field}: ${deviation[field].join(',')}`);
  return `${deviation.role}.${deviation.property}${conditions.length ? ` (${conditions.join('; ')})` : ''}`;
}

/**
 * Formats mismatches as a plain text table, one line per role and property with the
 * number of occurrences and the first example, or one line per mismatch with `all`.
 */
export function formatTable(mismatches, { all = false, known = new Set() } = {}) {
  const columns = ['role', 'property', 'expected', 'actual', 'page', 'viewport', 'scheme'];
  let rows;
  if (all) {
    rows = mismatches.map((m) => [m.role, m.property, m.expected, m.actual, m.page, m.viewport, m.scheme]);
  } else {
    const groups = new Map();
    for (const m of mismatches) {
      const key = issueKey(m);
      if (!groups.has(key)) groups.set(key, { first: m, count: 0 });
      groups.get(key).count++;
    }
    columns.push('count', 'known');
    rows = [...groups.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([key, { first: m, count }]) =>
      [m.role, m.property, m.expected, m.actual, m.page, m.viewport, m.scheme, String(count), known.has(key) ? 'yes' : 'NO']);
  }
  const clip = (text) => (text.length > 48 ? text.slice(0, 45) + '...' : text);
  const table = [columns, ...rows.map((row) => row.map(clip))];
  const widths = columns.map((_, i) => Math.max(...table.map((row) => row[i].length)));
  return table.map((row) => row.map((cell, i) => cell.padEnd(widths[i])).join('  ').trimEnd()).join('\n');
}

/**
 * Serialises measurements as JSON with one role per line, so that golden files stay
 * readable and their diffs show which roles changed.
 */
export function stringifyMeasurement(output) {
  const lines = ['{', `  "side": ${JSON.stringify(output.side)},`, '  "pages": {'];
  const pageIds = Object.keys(output.pages);
  pageIds.forEach((pageId, pageIndex) => {
    lines.push(`    ${JSON.stringify(pageId)}: {`);
    const variants = Object.entries(output.pages[pageId]);
    variants.forEach(([variant, data], variantIndex) => {
      lines.push(`      ${JSON.stringify(variant)}: {`);
      lines.push(`        "document": ${JSON.stringify(data.document)},`);
      const roles = Object.entries(data.roles);
      if (roles.length === 0) {
        lines.push('        "roles": {}');
      } else {
        lines.push('        "roles": {');
        roles.forEach(([role, entry], roleIndex) => {
          lines.push(`          ${JSON.stringify(role)}: ${JSON.stringify(entry)}${roleIndex < roles.length - 1 ? ',' : ''}`);
        });
        lines.push('        }');
      }
      lines.push(`      }${variantIndex < variants.length - 1 ? ',' : ''}`);
    });
    lines.push(`    }${pageIndex < pageIds.length - 1 ? ',' : ''}`);
  });
  lines.push('  }', '}', '');
  return lines.join('\n');
}
