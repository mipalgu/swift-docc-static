# Visual Regression Harness

This directory holds the browser-based regression harness for the built-in themes.
It renders the fixture package in `Tests/Fixtures/SidebarFixture`, measures the
computed styles of semantic *roles* (page title, abstract, declaration box, sidebar
row at a given depth, topic item, inline code, each aside kind, and so on) in a
browser, and compares them with golden data recorded from a reference renderer:

| Theme                 | Reference renderer                                        |
|-----------------------|-----------------------------------------------------------|
| `default`             | swift-docc-render (`docc convert` plus `docc merge`)      |
| `docc-static-classic` | the swift-docc-static generator of the `main` branch      |

## Requirements

- Node.js (any current release).
- `playwright-core`.  It is looked up in the `PLAYWRIGHT_CORE_PATH` environment
  variable, then through the normal Node module resolution, then next to the
  `playwright-cli` command if that is on the `PATH`.
- Google Chrome.  Set `VISUAL_REGRESSION_BROWSER_CHANNEL` to use another Playwright
  browser channel, or to an empty string for Playwright's own Chromium build.

When these are missing, the browser tests in `VisualRegressionTests.swift` are
skipped, so the package still builds and tests on machines (and continuous
integration runners on Linux or Windows) without a browser.  Setting
`DOCC_STATIC_SKIP_BROWSER_TESTS=1` skips them explicitly.

## Printing the Mismatch Table of a Theme

```bash
node Tests/VisualRegression/run.mjs --theme docc-static-classic --scratch-path <build directory>
node Tests/VisualRegression/run.mjs --theme default --scratch-path <build directory>
```

This builds `docc-static` with `swift run` (in the given scratch path, or a
directory in the system's temporary directory), renders the fixture with the theme,
measures it and prints one line per role and property that differs from the golden
data: the expected and actual computed value, where it first occurs (page, viewport,
colour scheme), how often it occurs, and whether it is on the theme's known-issue
list.  Further options:

- `--site <directory>` measures an already generated site instead of rendering one;
- `--docc-static <executable>` renders with a prebuilt executable;
- `--pages structure,article` restricts the run to some pages (see `pages.json`);
- `--all` lists every occurrence instead of one line per role and property;
- `--json <file>` writes the mismatches as JSON;
- `--prune-known` removes pairs that no longer occur from the known-issue list.

Mismatches covered by an accepted deviation (see below) are listed separately.  The
exit status is 0 when the remaining mismatches are exactly the known issues and
every accepted deviation still covers a mismatch.

The Swift tests also render the fixture's `FixtureCore` module on its own, whose
navigator shows a single module's title like swift-docc-render, and check it with
`run.mjs` (for `default`), `navigator.mjs` and `loading.mjs`.

The temporary directories of the harness and of the Swift tests (the fixture's build
cache and rendered sites) carry a key derived from the checkout's location in their
names, so test runs of different checkouts on the same machine never share them,
while repeated runs of one checkout reuse the warm build cache.

## Known Issues

`known-issues/<theme>.json` lists, per theme:

- `mismatches`: role and property pairs (`role.property`) that currently differ from
  the golden data;
- `unusedProperties`: custom properties the theme settings or theme stylesheets
  define but no rule reads;
- `undefinedProperties`: custom properties a rule reads without a fallback value
  although nothing defines them.

The Swift tests record listed issues as known issues, fail on any issue that is not
listed, and fail on any listed issue that no longer occurs.  The lists can therefore
only shrink: after fixing a mismatch, remove its pair (or run with `--prune-known`).
Do not add entries to make a test pass; fix the cause instead.

## Accepted Deviations

`accepted-deviations/<theme>.json` lists the differences from the golden data that
a theme keeps on purpose, mostly where the reference renderer is broken (for
example, an unreadable colour, or a narrow layout that hides the content).  Each
entry in `deviations` names:

- `role`: a role from `roles.json`, or `*` for every role, optionally limited by
  `roles`, a list of roles from `roles.json`;
- `property`: a measured property, `presence`, `box.x`, `box.width`, `box.height`, `text`, or `*` for
  every property;
- optionally `pages` (page identifiers from `pages.json`), `viewports` (such as
  `390x844`) and `schemes` (`light`, `dark`), which restrict the entry to those
  measurements;
- `reason`: a sentence stating why the theme differs.

A mismatch that an entry covers is reported in a separate section of the table and
is neither a known issue nor unexpected.  An entry that covers no mismatch fails
the tests, like a known issue that no longer occurs, and the Swift tests check that
every entry names a known role, property, page, viewport and scheme and gives a
reason.  Each entry is a claim about the reference, so keep the list short and the
conditions narrow; unlike known issues, deviations are not expected to go away.

## Regenerating the Golden Data

Golden data only needs regenerating when the fixture package, `roles.json`,
`pages.json` or the measured properties in `harness.json` change.  Measurements of
fonts depend on the fonts installed on the machine, so always regenerate both
references and compare on the same machine.

For the `default` theme (requires `docc`, found with `xcrun` on macOS or on the `PATH`):

```bash
node Tests/VisualRegression/references.mjs --theme default
```

For the `docc-static-classic` theme, first build `docc-static` from the `main` branch
in a separate worktree, then pass the executable:

```bash
git worktree add <main checkout> main
swift build -c release --package-path <main checkout> --scratch-path <main build directory>
node Tests/VisualRegression/references.mjs --theme docc-static-classic \
    --main-docc-static <main build directory>/release/docc-static
```

Both commands copy the fixture package to a temporary directory, build its symbol
graphs, render it with the reference renderer, measure the result and write
`golden/<theme>.json`.  The `main` branch generator cannot render a symbol graph that
only extends another module, so `Module@Other.symbols.json` graphs are left out of
its input.  `--work <directory>` keeps the intermediate files; `--site <directory>`
measures an already rendered reference site.

## Files

- `harness.json`: references per theme, the measured variants (1440x900 and 390x844
  in light and dark, and 1920x1080 in light, where the "On This Page" column appears),
  the shortest settle times, ready selectors, the geometry tolerance and the computed
  style properties that are recorded and compared.  Every check waits for the page to
  settle (fonts and images loaded, no transition running, the layout no longer
  changing) before it measures, and after each scroll or click.
- `pages.json`: the measured pages with their path in each renderer's output.
- `roles.json`: the semantic roles with one selector per DOM (`static` for
  swift-docc-static, `main` for the main branch output, `vue` for swift-docc-render).
  A selector may reach into the embedded sidebar with ` >>> ` (frame selector, then
  selector inside the frame).  `kinds` limits a role to page kinds, `pick:
  "in-viewport"` measures the first match visible in the viewport, `geometry:
  true` also compares the horizontal position and width (within the tolerance), `height:
  true` the height, `text: true` the text the element shows, `properties` limits the compared computed style properties
  (for a role whose elements differ in structure between the renderers), `pages` limits
  the role to some pages,
  and `pseudo` (for example `"::before"`) measures that pseudo-element of the match.
- `measure.js`: the function evaluated in the page.
- `measure.mjs`: measures a site (`--probe` prints how many elements each role
  matches on each page, which helps when editing `roles.json`).
- `run.mjs`, `references.mjs`, `nojs.mjs`, `onthispage.mjs`, `loading.mjs`, `navigator.mjs`,
  `check.mjs`: see
  above; `nojs.mjs` checks that every page type renders its content, the sidebar (with the
  current row highlighted and in view below the title of its module), working expand and
  collapse, breadcrumbs that follow the width of the content area when the navigator
  closes, and a Light or Dark choice in the footer
  that overrides the system appearance, all with JavaScript disabled; `loading.mjs` loads
  every page repeatedly, with and without JavaScript and with stylesheets that arrive at
  once or late, and fails if a transition or a time-based animation starts while it
  loads (scroll-driven animations may start); `navigator.mjs` loads the documentation
  pages in a tall and a short window, with and without JavaScript, and checks that the
  navigator stays at the top when the current row is visible there and otherwise shows
  the row (with JavaScript, at the top of the list below its module's title, like
  swift-docc-render); `onthispage.mjs`
  scrolls the documentation pages and checks that the "On This Page" column highlights
  the item swift-docc-render highlights at each position, with JavaScript disabled
  (or enabled with `--javascript`).
- `lib/`: the static file server, browser launcher, waits for a settled page, and
  comparison and storage helpers.
- `known-issues/` and `accepted-deviations/`: the lists described above, one file per
  theme.
- `golden/`: golden data, stored compactly (each page's first variant as differences
  from the first earlier page with the same role, other variants as differences from
  the page's first variant).
