import DocCStatic

let theme = ThemeConfiguration(
    builtInTheme: .default,
    customCSS: """
    /* Declaration blocks */
    .declaration-group {
        border-radius: 12px;
    }

    /* Topic items */
    .link-block.topic {
        border-radius: 12px;
    }

    /* Code listings */
    .code-listing {
        border-radius: 8px;
    }

    /* Asides */
    .aside {
        border-radius: 8px;
    }
    """
)
