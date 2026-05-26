<div align="center">

# PortPirate

macOS menu bar control for local dev ports. Maps every listener to its process, its repo, and — when it can prove it — the AI agent that started it. Then it lets you stop the right one safely.

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

## What it does

- **Discover** every listening TCP port on localhost and map it to the owning process, command line, working directory, and start time.
- **Attribute** the listener to the AI agent that started it (Claude Code, Cursor, Codex, Aider, opencode, Gemini CLI, Copilot, Augment, Windsurf, Qwen) when there is a signal to back it up — and show how confident the match is.
- **Group** listeners from the same git repo into a Workspace Stack card with branch, mixed-branches warning, and a Stop-all action. Worktrees group separately by path.
- **Diagnose** busy ports with explanations for the usual suspects (Vite fallback, Next defaults, AirPlay collisions).
- **Stop processes safely**: graceful SIGTERM with PID/port/command/owner/cwd revalidation before the signal fires, and a confirmation-gated Force Kill for the cases that need it.
- **Quiet the noise**: VS Code / Cursor / Windsurf / Zed / JetBrains helper processes collapse into their own disclosure section. Apple system services are off by default.
- **Run workspace scripts** from any folder. Reads `package.json` scripts when present, otherwise recognises Swift, Cargo, Go, Python, Ruby project markers.
- **Notify** on port collisions, expected-port disappearance, managed-script crashes, and scan failures — all opt-in.
- **Update** via Sparkle on a signed appcast with stable and beta channels.

The agent attribution and the workspace-stack view are what make PortPirate worth installing over `lsof | grep` and the half-dozen "kill the thing on port X" utilities. The rest is the boring infrastructure that has to exist for those two things to be useful.

## Showcase

<p align="center">
  <img src="docs/assets/portpirate-showcase.png" alt="PortPirate menu bar runtime panel" width="380">
</p>

## Install

1. Download the latest `PortPirate-<version>.dmg` from [GitHub Releases](https://github.com/jx-grxf/PortPirate/releases/latest).
2. Open the DMG and drag `PortPirate.app` into Applications.
3. Launch from Applications. PortPirate lives in the menu bar, not the Dock.
4. First launch on a preview build: right-click `PortPirate.app` → Open → confirm. Developer ID notarization is queued for the first paid release.

Requires macOS 14 or newer. No account, no cloud sync, no analytics, no backend.

## How attribution works

Three signals, in order of confidence:

1. **Environment** — known marker variables in the spawned process's env. Strongest signal, badge renders filled. Verified end-to-end on **Claude Code** (`CLAUDECODE=1`, `CLAUDE_CODE_*`, `AI_AGENT=claude-code_*`) and **Cursor** (`CURSOR_*`). Codex, opencode, Aider, Gemini, Copilot, Augment, and Qwen rules are in place but not yet verified on real sessions — see [`docs/agent-env-audits/`](docs/agent-env-audits/) for status.
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
xcrun swift build
xcrun swift test
./script/build_and_run.sh
```

The `xcrun` prefix targets the Xcode toolchain. Plain `swift build` may fail on machines using [`swiftly`](https://github.com/swiftlang/swiftly) if the project's pinned toolchain is not installed locally.

The scanner, parser, classifier, process-control, profile, and stack-grouping logic live in `PortPirateCore` so they are testable without launching the app.

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
