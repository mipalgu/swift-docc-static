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
3. the accent colour, when a configuration sets one without theme settings;
4. the custom properties defined by the theme settings;
5. the theme's stylesheets;
6. the custom CSS.

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
which the reader can also choose with the appearance selector.  Disable dark
mode styles with `--disable-dark-mode`, or in Swift:

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

## See Also

- ``ThemeConfiguration``
- ``ThemeSettings``
- ``ThemeSettingsParser``
- ``StylesheetLayer``
- <doc:Configuration>
