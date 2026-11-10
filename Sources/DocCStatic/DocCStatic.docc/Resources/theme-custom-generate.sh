# Generate documentation with your custom theme directory
docc-static generate --theme ./MyTheme \
    --package-path ./MyPackage --output ./docs

# Add a stylesheet on top of any theme
docc-static generate --theme ./MyTheme --custom-css ./tweaks.css \
    --package-path ./MyPackage --output ./docs
