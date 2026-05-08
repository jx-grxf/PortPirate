<div align="center">

# MacDev

Native macOS menubar control center for local developer runtimes.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-111111)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![Status](https://img.shields.io/badge/status-preview-6b7280)
![License](https://img.shields.io/badge/license-MIT-blue)
![CI](https://github.com/jx-grxf/MacDev/actions/workflows/ci.yml/badge.svg)

<img src="Assets/AppIcon/AppIcon1024.png" alt="MacDev app icon" width="104">

</div>

## Showcase

MacDev lives in the menu bar and answers the question every developer hits eventually:

> What is running on localhost, and why is this port busy?

The first preview focuses on the real control surface: a menu bar panel, a dedicated runtime browser, and native Settings for discovery rules.

## Contents

- [Highlights](#highlights)
- [Why This Exists](#why-this-exists)
- [Current Workflow](#current-workflow)
- [Tech Stack](#tech-stack)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Roadmap](#roadmap)
- [License](#license)

## Highlights

| Feature | Description |
| --- | --- |
| Menubar-first | Shows active local dev runtimes without becoming another full-time window. |
| Port discovery | Maps listening TCP ports to process IDs, commands, owners, and likely runtimes. |
| Diagnosis | Explains common causes like busy ports, Vite port fallback, Next defaults, and AirPlay conflicts. |
| Safe actions | Opens URLs, stops exact PIDs gracefully, and requires confirmation before force killing. |
| Workspace profiles | Reads `package.json` scripts and chooses npm, pnpm, yarn, or bun from lockfiles. |
| Native settings | Uses a dedicated macOS Settings scene for preferences and discovery rules. |

## What Works Today

- Detect listening TCP ports using macOS-native command line tools.
- Map ports to process IDs, commands, users, and working directories.
- Classify common local runtimes such as Vite, Next.js, Astro, Nuxt, Bun, pnpm, yarn, npm, Docker, Homebrew, and AirPlay-like system ports.
- Diagnose a specific busy port from the menu bar.
- Open localhost URLs and stop exact PIDs.
- Read `package.json` scripts from saved workspace folders.
- Show launchd user agents read-only.

## Safety

MacDev is local-only. It does not collect analytics, upload process data, or use a backend service.

Process control is intentionally precise:

- No `killall node`.
- No destructive git or workspace actions.
- Normal stop sends SIGTERM to the exact PID.
- Force kill is an explicit destructive action with confirmation.
- System-looking services such as AirPlay, Docker, and Homebrew are explained before suggesting action.

## Why This Exists

Local development on macOS gets messy fast: `npm run dev` exits, a server keeps running, port 3000 is busy, Vite silently moves to another port, or AirPlay owns port 5000. MacDev makes those local runtimes visible and actionable from one native menubar surface.

## Current Workflow

1. Open MacDev from the menu bar.
2. Scan active listening ports and detected runtimes.
3. Open a localhost URL, diagnose a busy port, or stop a specific process.
4. Add workspace folders and run package scripts from saved profiles.

## Tech Stack

| Layer | Choice |
| --- | --- |
| App | SwiftUI, macOS 14+ |
| UI shell | `MenuBarExtra`, `Settings`, optional runtime window |
| State | Observation (`@Observable`) |
| Runtime discovery | `lsof`, `ps`, `launchctl` |
| Project model | Swift Package Manager, Xcode-openable |
| Tests | Swift Testing via XCTest |

## Requirements

- macOS 14 or newer
- Xcode 15+ or Apple Swift toolchain
- Command line tools with `swift`, `lsof`, `ps`, and `launchctl`
- `hdiutil` and `codesign` for local preview packaging

## Quick Start

```bash
./script/build_and_run.sh
```

The script builds MacDev, stages `dist/MacDev.app`, and launches the app bundle.

To create a local preview DMG:

```bash
MACDEV_VERSION=0.1.0 ./script/package_dmg.sh
```

## Usage

- Click the menu bar icon to see current localhost runtimes.
- Use the port field to diagnose a busy port.
- Add project folders in Settings to discover scripts.
- Start scripts from workspace profiles.
- Use graceful stop first; force kill is guarded by confirmation.

## Development

```bash
swift test
./script/build_and_run.sh --verify
```

The core scanner and parser logic lives in `MacDevCore` so it can be tested without launching the app.

Tagged releases are built by GitHub Actions. Push `v<version>` and the release workflow builds a release-mode app bundle, creates a DMG, verifies the signature and image, then attaches the DMG to the GitHub Release.

## Roadmap

- Screenshots and demo clips
- Developer ID signed and notarized preview releases
- Homebrew Cask
- Sparkle updates
- Collision and crash notification history
- Advanced workspace orchestration
- Exportable team profiles

## License

MIT
