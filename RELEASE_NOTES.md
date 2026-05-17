# MacDev 0.2.0 Preview

Preview build of MacDev, a native macOS menu bar utility for finding, diagnosing, and safely controlling local developer runtimes.

## Highlights

- Detects listening TCP ports and maps them to processes, commands, users, and working directories.
- Classifies common local runtimes such as Vite, Next.js, Astro, npm, pnpm, yarn, Bun, Docker, Homebrew, and AirPlay-like system ports.
- Refreshes the app icon from the new `.icon` source across the app bundle, README, and website asset.
- Adds native notification controls for port warnings, managed-process crashes, expected missing ports, and scan failures.
- Adds Sparkle update settings with stable and beta channel selection backed by GitHub Release appcasts.
- Opens localhost URLs and stops exact PIDs instead of using broad commands like `killall node`.
- Separates Apple/system services from local developer runtimes before showing destructive actions.
- Keeps the README top product-focused while making install, first launch, and trust-model sections clearer for normal users.

## Fixed

- Preserved the real `CommandTimeout` error when a process is terminated by the timeout path.
- Escalated stubborn timeout processes from SIGTERM to SIGKILL so tests and scans do not hang.
- Reset `lsof` parser process names when a new PID has no command field.
- Preserved existing user `PATH` entries when launching workspace scripts, so Volta, NVM, asdf, and custom toolchains continue to work.
- Ignored invalid package-script ports outside `1...65535`.
- Rebuilt the release DMG with `create-dmg` so Finder opens a polished installer window instead of a raw one-item disk image.
- Made the DMG script compatible with both local and GitHub Actions `create-dmg` CLIs.
- Fixed stale process stops so already-exited PIDs refresh cleanly instead of showing a hard failure.
- Revalidates PID, port, command, owner, and working directory before sending a stop signal.
- Blocks backend stop actions for non-primary runtimes such as Apple, system-looking, Docker, or Homebrew services.
- Limits port diagnosis to the valid `1...65535` range.
- Filters workspace script environments so common secret variables are not passed through by default.
- Embeds the Sparkle framework RPATH so packaged apps can load bundled update support correctly.

## Improved

- Reworked Settings into macOS-style preference tabs: General, Discovery, Actions, Notifications, Updates, and About.
- Reduced the menu bar panel toward quick status, diagnosis, and runtime actions.
- Added release workflow assets for DMG, Sparkle ZIP, signed appcast, and website rebuild triggering.
- Clarified package-script trust copy and separated user install flow from developer build flow.

## Known Limitations

- Preview build is ad-hoc signed but not Developer ID notarized.
- Gatekeeper may require right-click Open until notarized releases ship.
- Sparkle appcast signing requires release secrets and is only active in packaged release builds.

## Pull Requests

- [#4](https://github.com/jx-grxf/MacDev/pull/4) MacDev polish, notifications, Sparkle, trust copy, and security hardening.
