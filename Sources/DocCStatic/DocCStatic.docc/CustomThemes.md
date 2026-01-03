# Custom Themes

Customise the appearance of your documentation.

## Overview

DocCStatic generates documentation styled to match Apple's DocC appearance by default. You can customise the theme through ``ThemeConfiguration`` to match your project's branding or personal preferences.

## Default Theme

The default theme (``ThemeConfiguration/default``) provides:

- **Accent colour**: `#0066cc` (Apple's standard link blue)
- **Dark mode**: Automatically adapts to system preferences
- **Typography**: SF Pro and SF Mono fonts (with system fallbacks)
- **Syntax highlighting**: Swift-specific colours for keywords, types, and literals

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

When dark mode is enabled, these CSS variables change automatically:

| Variable | Light Mode | Dark Mode |
|----------|-----------|-----------|
| `--docc-bg` | `#ffffff` | `#1d1d1f` |
| `--docc-fg` | `#1d1d1f` | `#f5f5f7` |
| `--docc-bg-secondary` | `#f5f5f7` | `#2c2c2e` |
| `--docc-border` | `#d2d2d7` | `#424245` |

## Custom CSS

Append additional CSS to the generated stylesheet:

```swift
let theme = ThemeConfiguration(
    accentColour: "#0066cc",
    includeDarkMode: true,
    customCSS: """
    /* Custom header styling */
    h1 {
        border-bottom: 2px solid var(--docc-accent);
        padding-bottom: 0.5rem;
    }

    /* Custom module card hover effect */
    .module-card:hover {
        transform: translateY(-2px);
    }
    """
)
```

### Available CSS Variables

Use these CSS custom properties for consistency:

```css
/* Colours */
var(--docc-bg)              /* Background */
var(--docc-bg-secondary)    /* Secondary background */
var(--docc-fg)              /* Foreground text */
var(--docc-fg-secondary)    /* Secondary text */
var(--docc-accent)          /* Accent colour */
var(--docc-border)          /* Border colour */

/* Typography */
var(--typeface-body)        /* Body text font */
var(--typeface-mono)        /* Monospace font */
var(--typeface-headline)    /* Heading font */

/* Syntax colours */
var(--swift-keyword)        /* Swift keywords */
var(--swift-type)           /* Type names */
var(--swift-string)         /* String literals */
var(--swift-number)         /* Numeric literals */
var(--swift-comment)        /* Comments */
```

### Overriding Variables

Override CSS variables in your custom CSS:

```swift
let theme = ThemeConfiguration(
    accentColour: "#0066cc",
    includeDarkMode: true,
    customCSS: """
    :root {
        --typeface-body: 'Inter', sans-serif;
        --typeface-mono: 'Fira Code', monospace;
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

### Symbol Cards

```css
.symbol-card {
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
        --typeface-body: 'Inter', -apple-system, sans-serif;
    }

    /* Rounded corners throughout */
    .declaration,
    .symbol-card,
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
- <doc:Configuration>
