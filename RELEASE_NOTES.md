# MacDev 0.1.0 Preview

First public preview of MacDev, a native macOS menu bar utility for finding and fixing local developer runtimes.

## Highlights

- Detects listening TCP ports and maps them to processes, commands, users, and working directories.
- Classifies common local runtimes such as Vite, Next.js, Astro, npm, pnpm, yarn, Bun, Docker, Homebrew, and AirPlay-like system ports.
- Adds a menu bar diagnosis flow for busy ports.
- Opens localhost URLs and stops exact PIDs instead of using broad commands like `killall node`.
- Separates Apple/system services from local developer runtimes.
- Adds workspace profiles from `package.json` scripts.
- Ships as a native SwiftUI macOS app with no telemetry or backend service.

## Fixed

- Fixed stale process stops so already-exited PIDs refresh cleanly instead of showing a hard failure.
- Fixed Settings and Runtime Browser focus from a no-Dock menu bar app.
- Fixed launchd parsing for real `launchctl print gui/$UID` service table output.
- Improved scanner responsiveness with command timeouts and batched CWD lookup.

## Improved

- Added a dedicated Settings window layout instead of oversized icon tabs.
- Added a project icon and Bundle metadata.
- Added SwiftPM CI for build and tests.

## Known Limitations

- Preview build is unsigned and not notarized.
- DMG is for preview distribution only.
- Notifications and full workspace orchestration are planned but not complete.
