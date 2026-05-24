# PortPirate 0.2.2

PortPirate is a native macOS menu bar utility for finding, diagnosing, and safely controlling local developer runtimes.

## Fixed

- Use a monotonic integer `CFBundleVersion` build number so Sparkle reliably detects new stable releases. Earlier builds set `CFBundleVersion` to the marketing version string, which made prerelease versions such as 0.2.1-beta.1 sort ahead of the 0.2.1 stable release and suppressed the update prompt.

## Known Limitations

- This build is ad-hoc signed but not Developer ID notarized.
- Gatekeeper may require right-click Open until notarized releases ship.
- Sparkle appcast signing requires release secrets and is only active in packaged release builds.

## Pull Requests

- [#7](https://github.com/jx-grxf/PortPirate/pull/7) Fix Sparkle update detection with a monotonic build number.
