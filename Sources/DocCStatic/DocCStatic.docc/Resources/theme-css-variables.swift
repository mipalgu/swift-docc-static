import DocCStatic

let theme = ThemeConfiguration(
    accentColour: "#6366f1",
    includeDarkMode: true,
    customCSS: """
    :root {
        /* Override CSS variables not in theme-settings.json */
        --nav-height: 64px;
        --content-max-width: 1200px;
        --border-radius: 12px;
    }

    @media (prefers-color-scheme: dark) {
        :root {
            --nav-height: 64px;
        }
    }
    """
)
