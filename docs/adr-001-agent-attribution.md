# ADR 001 — Agent Attribution

Status: Accepted
Date: 2026-05-26

## Context

Coding agents (Claude Code, Cursor, Codex, Aider, Gemini CLI, opencode, etc.) routinely spawn long-lived dev servers, leave zombies on common ports, and trigger `EADDRINUSE` storms. None of the existing port-killer tools tell the user *who* started the listener. That attribution is the central differentiator PortPirate is positioned around.

## Decision

Every discovered listener carries a `ProcessOwner` value resolved from three signals, in order of confidence:

1. **Environment variables** of the process (whitelisted prefixes: `CLAUDE_*`, `CURSOR_*`, `CODEX_*`, `OPENCODE_*`, `AIDER_*`, `GEMINI_CLI_*`, `COPILOT_*`, `AUGMENT_*`, `QWEN_CODE_*`, plus general `ANTHROPIC_*`, `OPENAI_*`, `npm_*`, `VSCODE_*`, `TERM_PROGRAM`). Session IDs are extracted from `<PREFIX>SESSION_ID` keys.
2. **`argv[0]` basename** of the process (not full command-line substring — substring matching produces false positives on paths like `/Users/claude/...`).
3. **Parent-executable basenames** walked through the PID chain (up to depth 32). VS Code and Code Insiders are deliberately *not* mapped to an AI-agent kind — they are editors, not agents. Copilot in VS Code surfaces only when its own process (`copilot`, `copilot-language-server`, etc.) appears in the chain, or when `COPILOT_*` env vars are set.

When none match but the parent is an interactive shell (`bash`, `zsh`, `fish`), the owner is `.manual`. Otherwise `.unknown`.

In parallel, a `GitContext` is resolved from the process's cwd via pure filesystem reads — no `git` subprocess. Worktrees are detected by `.git` being a file containing `gitdir: ...`; the actual git directory is followed to read `HEAD`.

`startedAt` comes from `proc_pidinfo(PROC_PIDTBSDINFO)`'s `pbi_start_tvsec`. Stale-detection uses `now - startedAt >= 30 min` as the v1 heuristic (running-for, not idle-since — true idle detection requires socket accept-time inspection, deferred).

## Components

| Layer | Type | Responsibility |
|---|---|---|
| `ProcessInspector` | actor | `proc_pidinfo`, `KERN_PROCARGS2`, parent-chain walk, env filtering |
| `AgentDetector` | struct | Classifies `ProcessContext` → `ProcessOwner` |
| `GitContextResolver` | struct | Resolves cwd → `GitContext?` via FS reads |
| `DiscoveryService` | actor | Orchestrates the three above; caches results per PID, invalidates when the PID disappears |
| `PortPirateProcess` | struct | Carries `owner`, `gitContext`, `startedAt` |

## Why not shell-out to `ps`/`git`?

- Cold-start of a subprocess per PID per refresh tick is the exact polling cost we are positioning against. `proc_pidinfo` is a syscall.
- `git` adds a multi-hundred-millisecond worst case (loading config, opening pack files). `.git/HEAD` reads are constant-time.

## Alternatives considered

- **Wrap each agent's CLI** to inject a marker env var (e.g. `PORTPIRATE_OWNER=claude`). Rejected: requires user setup per machine and per agent, would not work on processes already running, and undermines the "it just knows" pitch.
- **DTrace / Endpoint Security** for spawn-time attribution. Rejected for v1: requires entitlements and breaks the "drop-in app" install story. Possible follow-up for an enterprise tier.
- **Match by `argv` substring** (initial implementation). Replaced with basename match after false-positives on paths.

## UI surfaces

- A small capsule **OwnerBadge** in `ServerRowView` shows the agent name (color-tinted per kind). Tooltip carries kind, session ID, and cwd.
- The row's secondary line is enriched: when `gitContext` is present, it shows `repo · branch · worktree?` plus the relative age from `startedAt`.
- Two filter chips above the listener list: **AI agents** and **Stale >30m**. Chips only render when at least one matching server exists, to keep idle UI quiet. Filter state is session-scoped, not persisted.

## Privacy posture

Env-variable capture is whitelisted by prefix; no general dump. Snapshot data stays in-process. Nothing is sent off-device.

## Open follow-ups

- True idle-time detection via socket-accept timestamps (`netstat -nv` / `lsof -F`) for a sharper stale heuristic.
- Auto-sweep setting (opt-in) per agent or repo.
- "Owner" column in the Runtime Browser window (currently menu-bar only).
