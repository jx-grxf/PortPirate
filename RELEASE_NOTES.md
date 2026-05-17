# MacDev 0.1.4 Preview

Preview build of MacDev, a native macOS menu bar utility for finding and fixing local developer runtimes.

## Highlights

- Detects listening TCP ports and maps them to processes, commands, users, and working directories.
- Classifies common local runtimes such as Vite, Next.js, Astro, npm, pnpm, yarn, Bun, Docker, Homebrew, and AirPlay-like system ports.
- Adds a more scannable Runtime Browser with search, clearer empty states, and visible refresh state.
- Adds a rounded GitHub and portfolio showcase screenshot for the real menu bar panel.
- Opens localhost URLs and stops exact PIDs instead of using broad commands like `killall node`.
- Separates Apple/system services from local developer runtimes.
- Adds workspace profiles from `package.json` scripts.
- Ships as a native SwiftUI macOS app with no telemetry or backend service.

## Fixed

- Preserved the real `CommandTimeout` error when a process is terminated by the timeout path.
- Escalated stubborn timeout processes from SIGTERM to SIGKILL so tests and scans do not hang.
- Reset `lsof` parser process names when a new PID has no command field.
- Preserved existing user `PATH` entries when launching workspace scripts, so Volta, NVM, asdf, and custom toolchains continue to work.
- Ignored invalid package-script ports outside `1...65535`.
- Rebuilt the release DMG with `create-dmg` so Finder opens a polished installer window instead of a raw one-item disk image.
- Made the DMG script compatible with both local and GitHub Actions `create-dmg` CLIs.
- Fixed stale process stops so already-exited PIDs refresh cleanly instead of showing a hard failure.
- Fixed Settings and Runtime Browser focus from a no-Dock menu bar app.
- Fixed launchd parsing for real `launchctl print gui/$UID` service table output.
- Improved scanner responsiveness with command timeouts and batched CWD lookup.

## Improved

- Added GitHub issue forms, PR template, Dependabot, SECURITY, CONTRIBUTING, and a public audit note.
- Hardened GitHub Actions with job permissions, concurrency, and timeouts.
- Added linked CI/release badges and GitHub Markdown alert blocks in the README.
- Improved long command/path display in the runtime inspector.
- Made the menu bar warning indicator visibly yellow.

## Known Limitations

- Preview build is unsigned and not notarized.
- DMG is for preview distribution only.
- Sparkle appcast signing requires release secrets and is only active in packaged release builds.

## Pull Requests

- [#2](https://github.com/jx-grxf/MacDev/pull/2) Public deep-dive polish.
- [#3](https://github.com/jx-grxf/MacDev/pull/3) Website release refresh hook.
