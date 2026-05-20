# MacDev 0.2.1 Preview

Preview build of MacDev, a native macOS menu bar utility for finding, diagnosing, and safely controlling local developer runtimes.

## Highlights

- Rebuilt the Settings window with a translucent, vibrant macOS look and a sidebar layout.
- Adopted Liquid Glass surfaces for Settings cards and menu bar panel rows on macOS 26, with a material fallback on earlier systems.

## Improved

- Replaced the grouped preference form with rounded glass cards, hover states, and a design system shared by the menu bar panel and Settings.
- Moved the menu bar sections to native disclosure groups so expanding Other listeners, Apple services, or Tools no longer jumps the scroll position.
- Reworked the port diagnosis field into a compact Spotlight-style search pill.
- Switched Settings toggles to proper macOS switches.

## Fixed

- Kept a constant Settings window width so switching panes no longer resizes the window.
- Removed the duplicate Sparkle update controls that appeared in both the Updates and About panes.
- Removed the redundant Menu bar first preference row.

## Known Limitations

- Preview build is ad-hoc signed but not Developer ID notarized.
- Gatekeeper may require right-click Open until notarized releases ship.
- Sparkle appcast signing requires release secrets and is only active in packaged release builds.

## Pull Requests

- [#6](https://github.com/jx-grxf/MacDev/pull/6) Translucent Settings redesign, Liquid Glass surfaces, and menu bar panel polish.
