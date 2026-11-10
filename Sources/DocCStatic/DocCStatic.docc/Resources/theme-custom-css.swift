import DocCStatic

let theme = ThemeConfiguration(
    builtInTheme: .default,
    customCSS: """
    /* Custom header styling */
    h1 {
        border-bottom: 2px solid var(--color-link);
        padding-bottom: 0.5rem;
    }

    /* Smooth hover transitions */
    .module-card {
        transition: transform 0.2s, box-shadow 0.2s;
    }

    .module-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
    """
)
