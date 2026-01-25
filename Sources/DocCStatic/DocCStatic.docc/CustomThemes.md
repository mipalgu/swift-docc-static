# Custom Themes

Customise the appearance of your documentation.

## Overview

DocCStatic generates documentation styled to match Apple's DocC appearance by default. You can customise the theme through built-in themes, custom theme files, or programmatic configuration.

Theme customisation is available through:
- **Built-in themes**: Pre-configured themes included with DocCStatic
- **Custom theme files**: JSON files following the swift-docc-render `theme-settings.json` format
- **Programmatic configuration**: Direct ``ThemeConfiguration`` customisation in Swift code

## Using Built-in Themes

DocCStatic includes two built-in themes:

| Theme | Description | Accent Colour |
|-------|-------------|---------------|
| `default` | Matches swift-docc-render's appearance | `#36f` |
| `classic` | Original swift-docc-static style with SF Pro fonts | `#0066cc` |

### Via Command Line

```bash
# Use the default theme (swift-docc compatible)
docc-static generate -i ./MyPackage -o ./docs

# Use the classic theme (SF Pro fonts, original swift-docc-static appearance)
docc-static generate --theme classic -i ./MyPackage -o ./docs
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
// Default theme (explicit)
let theme = ThemeConfiguration(builtInTheme: .default)

// Classic theme
let theme = ThemeConfiguration(builtInTheme: .classic)

let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: theme
)
```

## Creating a Custom Theme

Custom themes use the swift-docc-render `theme-settings.json` format, allowing themes to be shared between swift-docc and DocCStatic.

### Theme File Format

A theme settings file has the following structure:

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

Colour values can be either:
- A single string value (used for both light and dark modes)
- An object with `light` and `dark` keys for mode-specific values

### Creating a Theme File

1. Copy an existing theme as a starting point:
   ```bash
   cp Themes/default.theme-settings.json my-theme.theme-settings.json
   ```

2. Edit the colour and typography values in your theme file

3. Use your custom theme:
   ```bash
   # Via command line
   docc-static generate --theme-settings ./my-theme.theme-settings.json \
       -i ./MyPackage -o ./docs

   # Via SPM plugin
   swift package generate-static-documentation \
       --theme-settings ./my-theme.theme-settings.json
   ```

### Loading Custom Themes Programmatically

```swift
// Load from a theme-settings.json file
let themeData = try Data(contentsOf: themeFileURL)
let themeSettings = try ThemeSettingsParser.parse(themeData)
let theme = ThemeConfiguration(themeSettings: themeSettings, includeDarkMode: true)

let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: theme
)
```

## Available Theme Variables

### Colour Variables

| Variable | Description | Default (Light) | Default (Dark) |
|----------|-------------|-----------------|----------------|
| `fill` | Page background | `#fff` | `#000` |
| `fill-secondary` | Secondary background (code blocks, declarations) | `#f7f7f7` | `#161616` |
| `fill-tertiary` | Tertiary background | `#f0f0f0` | `#2a2a2a` |
| `figure-gray` | Primary text | `#000` | `#fff` |
| `figure-gray-secondary` | Secondary text | `#6e6e73` | `#a1a1a6` |
| `figure-gray-tertiary` | Tertiary text | `#b0b0b5` | `#6c6c70` |
| `link` | Link and accent colour | `#36f` | `#36f` |
| `fill-gray` | Border colour | `#d2d2d7` | `#424245` |
| `fill-gray-secondary` | Secondary border | `#b0b0b5` | `#5a5a5d` |
| `fill-gray-tertiary` | Tertiary border | `#e0e0e5` | `#3a3a3d` |
| `fill-gray-quaternary` | Active/selected navigator background | `#f0f0f0` | `#424242` |
| `navigator-item-hover` | Navigator item hover background | `rgba(51, 102, 255, 0.05)` | `rgba(0, 102, 255, 0.5)` |
| `fill-blue` | Blue fill | `#36f` | `#36f` |
| `documentation-intro-fill` | Hero section background | `transparent` | `transparent` |
| `heading-link` | Heading anchor link colour | `inherit` | `inherit` |
| `tutorials-teal` | Tutorial colour | `#000` | `#fff` |
| `article-body-background` | Article background | `#fff` | `#161616` |

### Syntax Highlighting Variables

| Variable | Description | Default (Light) | Default (Dark) |
|----------|-------------|-----------------|----------------|
| `syntax-keywords` | Swift keywords | `#ad3da4` | `#ff7ab2` |
| `syntax-param-internal-name` | Parameter names | `#5d6c79` | `#a7b0b9` |
| `syntax-other-type-names` | Type names | `#703daa` | `#dabaff` |
| `syntax-other-preprocessor` | Preprocessor | `#78492a` | `#ffa14f` |
| `syntax-other-constants` | Constants | `#4b21b0` | `#a79df7` |
| `syntax-strings` | String literals | `#d12f1b` | `#ff8170` |
| `syntax-numbers` | Numeric literals | `#1c00cf` | `#d9c97c` |
| `syntax-plain` | Plain text | `#000` | `#fff` |
| `syntax-comments` | Comments | `#5d6c79` | `#7f8c98` |

### Typography Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `html-font` | Body text font | System font stack |
| `html-font-mono` | Monospace font | Menlo, monospace |

### Spacing Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `sidebar-width` | Width of the navigation sidebar | `400px` (default), `320px` (classic) |

## Customising the Accent Colour

Change the primary accent colour used for links and highlights:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: ThemeConfiguration(
        accentColour: "#ff5500",  // Orange accent
        includeDarkMode: true
    )
)
```

The accent colour is used for:
- Link text
- Declaration highlights
- Symbol card borders
- Interactive element focus states

### Choosing Colours

Consider accessibility when selecting an accent colour:
- Ensure sufficient contrast against both light and dark backgrounds
- Test with colour vision deficiency simulators
- Avoid colours that blend with syntax highlighting

## Dark Mode Support

By default, the documentation respects the user's system preference for light or dark mode. Disable dark mode if your custom styling doesn't support it:

```swift
let theme = ThemeConfiguration(
    accentColour: "#007aff",
    includeDarkMode: false  // Always light mode
)
```

### Dark Mode Colour Variables

When dark mode is enabled, colours with separate light/dark values change automatically based on the `prefers-color-scheme` media query or the `data-color-scheme` attribute on the body element.

## Custom CSS

Append additional CSS to the generated stylesheet:

```swift
let theme = ThemeConfiguration(
    accentColour: "#36f",
    includeDarkMode: true,
    customCSS: """
    /* Custom header styling */
    h1 {
        border-bottom: 2px solid var(--color-link);
        padding-bottom: 0.5rem;
    }

    /* Custom module card hover effect */
    .module-card:hover {
        transform: translateY(-2px);
    }
    """
)
```

### CSS Variable Naming

CSS variables are prefixed based on their category:
- `--color-*` for colour variables (e.g., `--color-fill`, `--color-link`)
- `--typography-*` for typography variables (e.g., `--typography-html-font`)
- `--spacing-*` for spacing and layout variables (e.g., `--spacing-sidebar-width`)

### Overriding Variables

Override CSS variables in your custom CSS:

```swift
let theme = ThemeConfiguration(
    accentColour: "#36f",
    includeDarkMode: true,
    customCSS: """
    :root {
        --typography-html-font: 'Inter', -apple-system, sans-serif;
        --typography-html-font-mono: 'Fira Code', monospace;
    }
    """
)
```

## Styling Specific Elements

### Declaration Blocks

```css
.declaration {
    background: linear-gradient(135deg, #f5f5f7, #e0e0e5);
    border-left-width: 4px;
}
```

### Topic Links (Symbol Cards)

```css
.topic-link-container {
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}
```

### Asides (Notes, Warnings)

```css
.aside.note {
    background: #e8f4fd;
    border-left-color: #2196f3;
}

.aside.warning {
    background: #fff8e1;
    border-left-color: #ffc107;
}
```

### Search Results

```css
.search-result-item {
    transition: background 0.2s;
}

.result-type-symbol {
    background: #e3f2fd;
    color: #1565c0;
}
```

## Full Theme Example

A complete custom theme:

```swift
let theme = ThemeConfiguration(
    accentColour: "#6366f1",  // Indigo
    includeDarkMode: true,
    customCSS: """
    /* Custom font */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap');

    :root {
        --typography-html-font: 'Inter', -apple-system, sans-serif;
    }

    /* Rounded corners throughout */
    .declaration,
    .topic-link-container,
    .module-card,
    .aside,
    pre {
        border-radius: 12px;
    }

    /* Subtle shadows */
    .module-card {
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
    }

    .module-card:hover {
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }

    /* Custom header */
    .index-header h1 {
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }
    """
)

let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: theme
)
```

## See Also

- ``ThemeConfiguration``
- ``ThemeSettings``
- ``ThemeSettingsParser``
- <doc:Configuration>
