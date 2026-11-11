# Custom Themes

Customise the appearance of your documentation.

## Overview

A theme determines the complete look of the generated pages.  It consists of
up to three parts:

- **Settings** in the swift-docc-render `theme-settings.json` format.  They
  define CSS custom properties (colours, fonts, spacing) and feature switches,
  so theme settings files can be shared between swift-docc and DocCStatic.
- **Stylesheets** (`*.css`) that are layered after the base stylesheet and can
  change any rule.
- **Custom CSS** supplied when generating, layered last.

Every page has the same HTML structure, whatever the theme: element and class
names mirror those of swift-docc-render, so a theme changes the look through
CSS.  Where a difference cannot be expressed in CSS, a theme uses one of the
feature switches described in <doc:CustomThemes#Feature-Switches>.

## Using Built-in Themes

DocCStatic includes two built-in themes:

| Theme | Alias | Description |
|-------|-------|-------------|
| `default` | | The appearance of swift-docc-render |
| `docc-static-classic` | `classic` | The original swift-docc-static appearance |

Themes are selected by their exact name or alias; any other name is an error
that lists the available themes.

### Via Command Line

The `generate`, `render` and `preview` commands accept the same theme options:

```bash
# Use the default theme
docc-static generate --package-path ./MyPackage --output ./docs

# Use the classic theme
docc-static generate --package-path ./MyPackage --output ./docs --theme classic
```

### Via SPM Plugin

```bash
# Default theme
swift package generate-static-documentation

# Classic theme
swift package generate-static-documentation --theme classic
```

### Via Swift API

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: ThemeConfiguration(builtInTheme: .classic)
)
```

## Creating a Custom Theme

### Theme Settings Files

The simplest custom theme is a single `theme-settings.json` file:

```json
{
  "theme": {
    "color": {
      "fill": { "light": "#ffffff", "dark": "#1d1d1f" },
      "link": "#0066cc"
    },
    "typography": {
      "html-font": "system-ui, sans-serif"
    }
  }
}
```

Pass the file's path to `--theme`:

```bash
docc-static generate --package-path ./MyPackage --output ./docs \
    --theme ./my-theme.json
```

Every leaf of the `theme` section becomes a CSS custom property whose name joins
the keys with `-`, exactly as in swift-docc-render: `color.link` becomes
`--color-link`, `code.border-width` becomes `--code-border-width`.  A value can
be a single string (used in light and dark mode) or an object with `light` and
`dark` values.  The sections of the swift-docc-render specification (`aside`,
`badge`, `border-radius`, `button`, `code`, `color`, `icons`, `tutorial-step`,
`typography` and `device-frames`) are accepted, together with the DocCStatic
`spacing` section, whose keys become `--spacing-*` properties for margins,
paddings, font sizes and widths.

Unknown keys are reported as warnings rather than silently ignored, so a
misspelt key is easy to find.

### Theme Directories

A theme directory contains a `theme-settings.json` file and any number of
stylesheets.  The stylesheets are applied after the base stylesheet in the order
of their file names; a stylesheet whose name ends in `.dark.css` is only included
when dark mode styles are enabled.

```
MyTheme/
├── theme-settings.json
├── theme.css
└── theme.dark.css
```

```bash
docc-static generate --package-path ./MyPackage --output ./docs --theme ./MyTheme
```

The built-in themes are theme directories too: they live in the `Themes`
directory of the swift-docc-static package and are compiled into the binary.
Copying one is a good starting point for a custom theme.

### Custom CSS

Add a stylesheet on top of any theme, built-in or custom, with `--custom-css`:

```bash
docc-static generate --package-path ./MyPackage --output ./docs \
    --theme classic --custom-css ./tweaks.css
```

### Stylesheet Layers

The generated `css/main.css` consists of the following layers, each starting
with a comment such as `/* docc-static layer: theme/theme */`, and each layer
can override the layers before it:

1. the base stylesheet shared by all themes, whose visual values are read
   from custom properties with the swift-docc-render values as fallbacks;
2. the rules for the embedded navigation sidebar;
3. the rules that apply the colour scheme chosen in the page footer;
4. the accent colour, when a configuration sets one without theme settings;
5. the custom properties defined by the theme settings;
6. the theme's stylesheets;
7. the custom CSS.

### Light and Dark Appearance

The colour palette, and every colour a theme settings file defines, is set on
the `body` element.  A colour with different light and dark values becomes a
`light-dark()` pair, so the page follows the reader's system appearance, or the
Light, Dark or Auto choice in the page footer.  That choice works without
JavaScript; with JavaScript it is also remembered across pages and applied to
the navigation sidebar.  A theme stylesheet that needs a different value in the
dark appearance can use `light-dark()` itself, for example
`--color-fill: light-dark(#fff, #111);`.

## Feature Switches

The `features` section of a theme settings file turns parts of the page on or
off.  DocCStatic accepts the switches of swift-docc-render:

| Switch | Effect in DocCStatic |
|--------|----------------------|
| `docs.onThisPageNavigator.disable` | Leaves the "On This Page" column out of every page |
| `docs.quickNavigation.enable` | Accepted without effect; the sidebar filter provides search |
| `docs.i18n.enable` | Accepted without effect |

```json
{
  "theme": {},
  "features": {
    "docs": {
      "onThisPageNavigator": { "disable": true }
    }
  }
}
```

The "On This Page" column is a switch rather than CSS because leaving it out
also removes it from every page's markup, reading order and keyboard navigation.

The column highlights the section in view as the reader scrolls, without
JavaScript in browsers with scroll-driven animations.  A theme styles the
highlighted item through the colour of `.OnThisPageNav .base-link`
(`--color-text` for the highlighted item, `--color-figure-gray-secondary` for the
others).

## Optional Elements

Some information that swift-docc-render does not show is part of every page, so
that a theme can show it with CSS alone.  The base stylesheet hides these elements:

| Element | Content |
|---------|---------|
| `.nav-title .header-icon` | An empty element before the text of the navigation bar title, for an icon |
| `.link-block .topic-kind-badge` | An empty element in every topic link; its `data-topic-type` attribute names the kind of the topic (such as `struct`, `method` or `article`) and its `data-topic-letters` attribute the letters of the kind's icon (such as `S` or `Pr`), for example for `content: attr(data-topic-letters)` |
| `.link-block .topic-title` | The plain title of a topic that shows its declaration, such as `init(x:y:)` |
| `.card .module-stats` | The number of symbols of a module on the landing page |
| `.topic-list .topic-abstract` | The abstract of a tutorial or article in a chapter of a tutorials overview |
| `.topictitle .eyebrow-kind` | After the eyebrow, the shorter name of the page's kind that the original swift-docc-static pages showed, such as *Method* where the eyebrow reads *Instance Method* |
| `.nav-title-content .nav-overview-title` | In a tutorial's navigation bar, the title of the tutorials overview |
| `.hero .overview-introduction` | In a tutorials overview, the fixed introduction the original swift-docc-static pages showed |
| `.navigator-card-item.is-group > .disclosure-checkbox`, `.is-group .tree-toggle` | The checkbox and chevron of a group heading in the navigator; checking the checkbox collapses the group's rows, which follow the heading in a `.nav-group-wrapper` |

The background of a tutorial's introduction (`.tutorial-hero .bg`) shows the light
variant of its image, like swift-docc-render.  Where the image has a dark variant,
the element also sets `--tutorial-hero-background-dark` to it, as a `url()`, for
themes that show the dark variant on the dark introduction.

The line breaks that place each parameter of a declaration on a line of its own
are marked too: every break is a `.declaration-break` element, and a break after
an opening or before a closing parenthesis is also a `.declaration-parenthesis-break`
element.  A theme that shows declarations on a single line can collapse the breaks
with `white-space: normal` and hide those beside parentheses.

A theme's settings are defined on the root element as well as on the body
element, so `--spacing-html-font-size` sets the root font size that `rem` values
are based on.

The breadcrumbs and the "On This Page" column follow the width of the content area
beside the navigator, like swift-docc-render.  Documentation pages compute that
width from the viewport and the navigator width (`--spacing-sidebar-width`) as
`--content-area-width`, together with comparisons that rules can read through
container style queries: `--content-area-wide` (wider than 1050px, where the "On
This Page" column appears), `--content-area-over-1000`, `--content-area-over-1200`
and `--content-area-small` (narrower than 735px), each `1` or `0`.  For example:

```css
@container style(--content-area-wide: 1) {
    .documentation-hero .abstract { max-width: 640px; }
}
```

Avoid size container queries (`container-type: inline-size`) on the page: a browser
may style a page once before its stylesheet arrives, and then animates every
transition inside a size container from that unstyled state as the page loads.

## Theming in Swift

```swift
// A built-in theme with additional CSS
let theme = ThemeConfiguration(
    builtInTheme: .classic,
    customCSS: try ThemeConfiguration.loadCustomCSS(from: "tweaks.css")
)

// A theme name, settings file or theme directory, resolved like --theme
let custom = try ThemeConfiguration.resolveTheme("MyTheme")

// Settings and stylesheets assembled in code
let settings = try ThemeSettingsParser.parse(contentsOf: settingsURL)
let assembled = ThemeConfiguration(
    themeSettings: settings,
    stylesheets: [ThemeSettings.Stylesheet(name: "theme", css: ".documentation-hero { border-radius: 12px; }")]
)
```

### Accent Colour

Without theme settings, a configuration can set just the accent colour used for
links and highlights:

```swift
let theme = ThemeConfiguration(accentColour: "#ff5500", includeDarkMode: true)
```

## Dark Mode

By default, the documentation follows the reader's light or dark preference,
which the reader can also choose with the colour scheme toggle in the page
footer.  Disable dark mode styles, which also hides the toggle, with
`--disable-dark-mode`, or in Swift:

```swift
let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: false)
```

## Common Variables

Some of the variables that themes commonly set:

| Variable | Description |
|----------|-------------|
| `--color-fill` | Page background |
| `--color-fill-secondary` | Secondary background (code listings, declarations) |
| `--color-figure-gray` | Primary text |
| `--color-figure-gray-secondary` | Secondary text |
| `--color-link` | Links and accents |
| `--color-documentation-intro-fill` | Background of the page header |
| `--color-syntax-keywords` | Swift keywords in code |
| `--typography-html-font` | Body text font |
| `--typography-html-font-mono` | Code font |
| `--spacing-html-font-size` | Root font size that `rem` values are based on |
| `--spacing-sidebar-width` | Width of the navigation sidebar |

The built-in themes' `theme-settings.json` files list many more.

## Tutorial Pages

Tutorial pages and the tutorials overview use swift-docc-render's colour variables,
such as `--color-step-background`, `--color-step-focused`,
`--color-tutorial-hero-background`, `--color-tutorial-assessments-background`,
`--color-call-to-action-background`, `--color-button-background` and the
`--color-tutorials-overview-*` and `--color-nav-*` families, together with
`--border-radius`, `--button-border-radius`, `--code-border-radius` and
`--tutorial-step-border-radius`.  A few further variables adjust their layout:

| Variable | Description |
|----------|-------------|
| `--tutorial-content-width` | Width of the content column on wide screens (`-medium` and `-small` variants for narrower screens) |
| `--tutorial-section-spacing` | Space below a section introduction and around the assessments |
| `--tutorial-step-spacing` | Space between two steps |
| `--tutorial-step-border-width` | Width of the bar that marks the step in view |
| `--tutorial-code-number-color` | Colour of line numbers in code listings |

The step in view, the code or media shown next to the steps, the section shown in
the navigation bar, the menus and the quizzes all work without JavaScript.  In
browsers without scroll driven animations, every step shows its own code or media
below it, as on narrow screens.

## See Also

- ``ThemeConfiguration``
- ``ThemeSettings``
- ``ThemeSettingsParser``
- ``StylesheetLayer``
- <doc:Configuration>
