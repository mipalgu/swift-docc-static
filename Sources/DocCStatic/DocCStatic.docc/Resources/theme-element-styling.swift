import DocCStatic

let theme = ThemeConfiguration(
    accentColour: "#6366f1",
    includeDarkMode: true,
    customCSS: """
    /* Declaration blocks */
    .declaration {
        border-radius: 12px;
        border-left-width: 4px;
    }

    /* Topic cards */
    .topic-link-container {
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    }

    /* Code blocks */
    pre {
        border-radius: 8px;
    }

    /* Asides */
    .aside {
        border-radius: 8px;
    }
    """
)
