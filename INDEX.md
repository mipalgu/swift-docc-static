# Generating DocC Pages in pure HTML/CSS

The [swift-docc-static](https://github.com/mipalgu/swift-docc-static) package
enables generating pure HTML/CSS documentation from Swift packages
that works locally as `file://` URLs and can be hosted on any static web server.

The generated pages render without requiring JavaScript on the server or in the browser.
The pages do offer filter and search functionality, though, if JavaScript is enabled.

## Quick Start

Install using [Homebrew](https://brew.sh):
```bash
brew tap mipalgu/tap
brew install swift-docc-static
```

Then generate documentation for your Swift package:
```bash
docc-static generate --package-path /path/to/package --output ./docs
open docs/index.html
```

## Documentation

The package provides a [Swift Package Manager (SPM)](https://swift.org/package-manager)
plugin, a command-line utility, and a library for integration into other projects.
You can find detailled documentation by clicking on the links below.
