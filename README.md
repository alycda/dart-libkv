# dart-libkv

## Quickstart
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/alycda/ditto-takehome)

No installation required - everything is pre-configured.

## Prerequisites

### Required
- **Dart SDK** - [Installation instructions](https://dart.dev/get-dart)

### Development Environments

You have several options for the best development experience:

#### Option 2: VS Code with Dev Containers (Local)
If you have Docker installed:

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open this repository in VS Code
3. Click "Reopen in Container" when prompted

All dependencies will be automatically installed.

#### Option 3: Nix (For Nix Users)
If you use Nix with direnv:
```bash
direnv allow
```

The development environment will load automatically.

See https://determinate.systems/blog/nix-direnv/ and https://github.com/nix-community/nix-direnv

#### Option 4: Manual Setup
Install Dart SDK manually and run:
```bash
dart pub get
```