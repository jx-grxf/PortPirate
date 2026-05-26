<div align="center">

# PortPirate

The macOS menu bar tool that tells you which AI agent started that local server.

[![CI](https://github.com/jx-grxf/PortPirate/actions/workflows/ci.yml/badge.svg)](https://github.com/jx-grxf/PortPirate/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jx-grxf/PortPirate?label=release)](https://github.com/jx-grxf/PortPirate/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-111111)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="Assets/AppIcon/AppIcon1024.png" alt="PortPirate app icon" width="112">

[Download](https://github.com/jx-grxf/PortPirate/releases/latest) · [Architecture](ARCHITECTURE.md) · [Release runbook](docs/release.md) · [Security](SECURITY.md) · [Decisions](docs/)

</div>

> [!TIP]
> Built for the exact moment when you ask "what the hell is running on port 3000?" and the answer turns out to be a `next dev` that Claude Code spun up two hours ago and forgot about.

## What PortPirate does that nothing else does

**Agent attribution.** Every listening port is labeled with the AI agent that started it — Claude, Cursor, Codex, opencode, Aider, and others. Detection runs on three signals (env vars, parent process chain, argv basename) with a confidence badge so you know whether it is proven or a guess. No competitor does this.

**Workspace stacks.** When three or four servers run inside the same git repo — frontend, API, worker, DB — PortPirate collapses them into a single stack card with the branch name, a `mixed branches` warning when they disagree, and a `Stop all` button. Worktrees group separately by path, so concurrent agent worktrees stay visually distinct.

**Editor helpers get out of the way.** VS Code / Cursor / Windsurf / Zed / JetBrains helper processes collapse into their own disclosure section so they stop drowning your actual dev servers.

Everything else (port discovery, collision diagnosis, graceful stop with revalidation, package-script profiles, launchd visibility, Sparkle updates) is in there too — but those are table stakes, not the reason to install.

## Showcase

<p align="center">
  <img src="docs/assets/portpirate-showcase.png" alt="PortPirate menu bar runtime panel" width="720">
</p>

## Install

1. Download the latest `PortPirate-<version>.dmg` from [GitHub Releases](https://github.com/jx-grxf/PortPirate/releases/latest).
2. Open the DMG and drag `PortPirate.app` into Applications.
3. Launch from Applications. PortPirate lives in the menu bar, not the Dock.
4. First launch on a preview build: right-click `PortPirate.app` → Open → confirm. Developer ID notarization is queued for the first paid release.

Requires macOS 14 or newer. No account, no cloud sync, no analytics, no backend.

## How attribution works

Three signals, in order of confidence:

1. **Environment** — known marker variables in the spawned process's env (`CLAUDECODE`, `CLAUDE_CODE_*`, `CURSOR_*`, `CODEX_*`, `OPENCODE_*`, `AIDER_*`, `GEMINI_CLI_*`, `COPILOT_*`, `AUGMENT_*`, `QWEN_CODE_*`). Strongest signal. Badge renders filled.
2. **Parent chain** — the process's PID chain still leads to a known agent executable. Reliable for direct shell-children; breaks when a service is reparented to launchd (brew services, docker daemon, `nohup`). Badge renders outlined.
3. **Argv basename** — the process's own `argv[0]` matches a known agent. Rare in practice. Badge renders dashed with a `~` prefix.

When none match but the parent is an interactive shell, the owner is **manual**. Otherwise **unknown**. PortPirate deliberately does not claim attribution for detached services it cannot prove — that gap is covered by the workspace-stack view, which correlates listeners by repo without asserting ownership.

See [ADR-001](docs/adr-001-agent-attribution.md) for the full decision model and the [per-agent audit log](docs/agent-env-audits/) for what is verified on which version.

## Safety

Process control is intentionally narrow:

- Graceful stop revalidates the listener, command, owner, and working directory before sending SIGTERM.
- Force kill is an explicit destructive action, gated behind a confirmation dialog.
- No `killall`. No broad workspace or git destruction.
- System-looking services (Apple, Docker, Homebrew, launchd) are flagged with an explanation before any action is suggested.
- Workspace scripts only run on user action and inherit a filtered environment by default.
- Env-variable inspection is whitelisted by prefix — there is no general dump of subprocess environments.

## Build from source

```bash
git clone https://github.com/jx-grxf/PortPirate.git
cd PortPirate
swift build
swift test
./script/build_and_run.sh
```

The scanner, parser, classifier, process-control, profile, and stack-grouping logic live in `PortPirateCore` so they are testable without launching the app. Tests: 50 and counting.

To build a local DMG:

```bash
PORTPIRATE_VERSION=0.2.2 ./script/package_dmg.sh
```

## Verifying agent detection on your machine

If you want to confirm how PortPirate sees a specific coding agent, run the audit script from inside that agent's shell session:

```bash
./script/audit_agent_env.sh
```

It prints the matching env vars currently exported in the shell and lists which agent CLIs are installed on `PATH`. Use the output to either confirm the detection rule fires for that agent or to file an audit note in [`docs/agent-env-audits/`](docs/agent-env-audits/).

## Release pipeline

GitHub Actions builds tagged releases: app bundle, DMG, Sparkle ZIP and appcast, signature verification, and (once Developer ID is configured) notarization + stapler validation. Full runbook in [docs/release.md](docs/release.md). Public release notes live in [RELEASE_NOTES.md](RELEASE_NOTES.md).

Distribution roadmap:

- Developer ID signing and notarization once Apple Developer enrollment lands.
- [Homebrew Cask](docs/distribution/homebrew.md) submission to the main `homebrew-cask` tap after the first notarized release.
- License switch from MIT to [FSL-1.1-MIT](docs/adr-003-licensing.md) in the same window.

## Roadmap

- **Smart actions** — per-service shutdown (docker stop / brew services stop / launchctl unload / graceful SIGINT→SIGTERM→SIGKILL) instead of one-size-fits-all kill.
- **Stale auto-sweep** — opt-in setting to clean up servers that have been idle past a threshold.
- **Workspace Stacks v2** — declared stacks via `portpirate.yml`, `docker-compose.yml` import, "Adopt running" on stack start, health-check polling, "Restart only failed".
- **Runtime browser polish** — topology view, per-service log tabs, "Open in editor".
- **Pricing tier** — passive stack grouping and agent attribution stay free; Stacks v2, Smart Actions, and auto-sweep belong to the paid tier.

## Tech stack

SwiftUI · macOS 14+ · `MenuBarExtra` · `@Observable` · pure-Swift discovery via `proc_pidinfo` + `KERN_PROCARGS2` (no subprocess shells for the hot path) · Swift Package Manager · GitHub Actions on macOS · Sparkle for updates.

## Contributing

Issues and focused pull requests welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md), keep changes scoped, run `swift test` before opening a PR. Security reports go through [SECURITY.md](SECURITY.md).

## License

MIT today. See [LICENSE](LICENSE). The next paid release will switch to FSL-1.1-MIT with two-year auto-conversion back to MIT — rationale in [ADR-003](docs/adr-003-licensing.md). Everything published under MIT stays available under MIT.
