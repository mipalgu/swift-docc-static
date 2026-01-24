import DocCStatic

// Disable dark mode for a light-only theme
let theme = ThemeConfiguration(
    accentColour: "#6366f1",
    includeDarkMode: false  // Documentation will always use light mode
)

let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: theme
)
