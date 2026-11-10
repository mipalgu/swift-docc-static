import DocCStatic

let theme = ThemeConfiguration(
    builtInTheme: .default,
    customCSS: """
    :root {
        /* Override custom properties that the theme settings do not set */
        --spacing-sidebar-width: 320px;
        --spacing-html-font-size: 16px;
    }
    """
)
