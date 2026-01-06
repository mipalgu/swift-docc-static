# CI/CD Integration

Automate documentation generation with continuous integration.

## Overview

Automating documentation generation ensures your documentation stays current
with your code. This guide covers integration with popular CI/CD platforms.

## GitHub Actions

### Basic Workflow

Create `.github/workflows/documentation.yml`:

```yaml
name: Documentation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-docs:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install docc-static
        run: |
          brew tap mipalgu/tap
          brew install swift-docc-static

      - name: Generate Documentation
        run: |
          docc-static generate \
            --output ./docs \
            --verbose

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: documentation
          path: docs/
```

### Deploy to GitHub Pages

Extend the workflow to deploy automatically:

```yaml
name: Documentation

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install docc-static
        run: |
          brew tap mipalgu/tap
          brew install swift-docc-static

      - name: Generate Documentation
        run: docc-static generate --output ./docs

      - name: Setup Pages
        uses: actions/configure-pages@v4

      - name: Upload Pages Artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: docs/

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

### Using the SPM Plugin

If you prefer using the Swift package plugin:

```yaml
- name: Generate Documentation
  run: |
    swift package --scratch-path /tmp/build \
      generate-static-documentation \
      --output ./docs
```

## GitLab CI/CD

Create `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - deploy

build-docs:
  stage: build
  image: swift:latest
  before_script:
    - git clone https://github.com/mipalgu/swift-docc-static.git /tmp/docc-static
    - cd /tmp/docc-static && swift build -c release
    - export PATH="/tmp/docc-static/.build/release:$PATH"
  script:
    - cd $CI_PROJECT_DIR
    - docc-static generate --output public
  artifacts:
    paths:
      - public/
  only:
    - main

pages:
  stage: deploy
  dependencies:
    - build-docs
  script:
    - echo "Deploying to GitLab Pages"
  artifacts:
    paths:
      - public/
  only:
    - main
```

## Azure Pipelines

Create `azure-pipelines.yml`:

```yaml
trigger:
  - main

pool:
  vmImage: 'macos-latest'

steps:
  - script: |
      brew tap mipalgu/tap
      brew install swift-docc-static
    displayName: 'Install docc-static'

  - script: |
      docc-static generate --output $(Build.ArtifactStagingDirectory)/docs
    displayName: 'Generate Documentation'

  - publish: $(Build.ArtifactStagingDirectory)/docs
    artifact: documentation
    displayName: 'Publish Documentation'
```

## CircleCI

Create `.circleci/config.yml`:

```yaml
version: 2.1

jobs:
  build-docs:
    macos:
      xcode: "15.0"
    steps:
      - checkout
      - run:
          name: Install docc-static
          command: |
            brew tap mipalgu/tap
            brew install swift-docc-static
      - run:
          name: Generate Documentation
          command: docc-static generate --output ./docs
      - store_artifacts:
          path: docs
          destination: documentation

workflows:
  documentation:
    jobs:
      - build-docs
```

## Netlify

Create `netlify.toml`:

```toml
[build]
  command = "swift package --scratch-path /tmp/build generate-static-documentation --output public"
  publish = "public"

[build.environment]
  SWIFT_VERSION = "5.10"
```

Note: Netlify's default image may not have Swift. Consider using a custom build image
or triggering deployment from GitHub Actions.

## Best Practices

### Cache Dependencies

Speed up builds by caching Swift packages:

**GitHub Actions:**
```yaml
- uses: actions/cache@v4
  with:
    path: .build
    key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}
```

**GitLab CI:**
```yaml
cache:
  paths:
    - .build/
```

### Validate Documentation

Add a validation step to catch broken links:

```yaml
- name: Validate Links
  run: |
    # Use a link checker like lychee
    lychee --offline ./docs
```

### Generate on Tags

Only regenerate documentation on releases:

```yaml
on:
  push:
    tags:
      - 'v*'
```

### Conditional Deployment

Deploy only when documentation files change:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'Sources/**/*.swift'
      - 'Sources/**/*.md'
      - 'Sources/**/*.docc/**'
```

### Parallel Builds

If you have multiple packages, build documentation in parallel:

```yaml
jobs:
  build:
    strategy:
      matrix:
        package: [CoreLib, HelperLib, MainApp]
    steps:
      - name: Generate Docs
        run: |
          cd ${{ matrix.package }}
          docc-static generate --output ../docs/${{ matrix.package }}
```

## Troubleshooting

### Swift Version Issues

Ensure your CI environment has a compatible Swift version:

```yaml
- name: Check Swift Version
  run: swift --version
```

### Memory Issues

For large packages, increase available memory or use a scratch path:

```yaml
- name: Generate Documentation
  run: |
    docc-static generate \
      --scratch-path /tmp/docc-build \
      --output ./docs
```

### Build Timeouts

Documentation generation can be slow. Increase timeout limits:

```yaml
- name: Generate Documentation
  timeout-minutes: 30
  run: docc-static generate --output ./docs
```

## See Also

- <doc:GettingStarted> - Installation and basic usage
- <doc:ServerDeployment> - Deployment options
- <doc:LocalUsage> - Local development workflows
