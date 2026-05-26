# ADR 002 — Workspace Stacks

Status: Accepted (v1 scope only)
Date: 2026-05-26
Related: [ADR-001 Agent Attribution](adr-001-agent-attribution.md)

## Context

A modern web app is rarely one process. The typical local setup runs three to six listeners — Postgres, Redis, an API, a frontend, a worker, sometimes Mailhog. Every existing port tool, ours included, has shown those as a flat list of port numbers with no indication that they belong together. The consequences repeat:

- The user does not know which ports to kill together when cleaning up.
- Restarting an app means hunting each service individually.
- A crash leaves it unclear whether a single component went down or the whole stack.
- Restarting a stack collides with a service that is already running (brew-services Postgres surviving a reboot).

Agent attribution (ADR-001) solved "who started this" for shell-child processes. It deliberately does not claim ownership of detached services (brew, docker, launchd). Workspace Stacks fill that gap with correlation — without making attribution claims — by grouping listeners that share a git repository on disk.

## Decision (v1)

Group listeners passively by their `gitContext.worktreePath ?? gitContext.repoRoot`. A group becomes a `WorkspaceStack` when it contains two or more listeners; single-listener repos remain flat to avoid pointless cards.

The menu-bar panel renders one `StackCardView` per stack at the top of the local-runtimes section, followed by ungrouped listeners. Each card shows:

- Aggregate status dot (warning if any child has a warning).
- Stack name (repo or worktree directory basename).
- Subtitle: service count, current branch (or "mixed branches" if children disagree), "worktree" marker.
- "Stop all" header button — calls `AppState.stopStack`, which iterates `ProcessController.stop` over each primary-runtime member sequentially. Confirmation dialog reuses the existing `confirmForceKill` preference.

Filters (AI agents / Stale >30m, from ADR-001) apply before grouping, so a stack only contains servers that match the active filter.

## Why passive (no config) for v1

`gitContext` is already populated by `DiscoveryService` for every listener whose cwd is inside a git repo. That covers >80% of real dev workloads without asking the user to write a YAML file. The signal is precise: filesystem-resolved repo root, no heuristics. The Stack appears the moment a second server starts inside the same checkout — no setup, no migration, no surprises.

The declared-stack version (`portpirate.yml`, docker-compose import, Procfile, "Adopt running", health checks, dependency order) is real work and documented as v2+. It must not block the v1 release.

## Worktree handling

When a listener's `gitContext.isWorktree == true`, grouping uses `worktreePath` instead of `repoRoot`. This is correct because a worktree is a logically separate working copy with its own branch state, even though it shares object storage with the main repo. Two worktrees from the same repo become two stacks. The card shows a "worktree" marker in the subtitle.

## Why a 2-service minimum

A single listener inside a repo is not a stack — it is just a server. Wrapping it in a card adds visual weight without information. Threshold is configurable via `StackGrouper.group(_:minimumServices:)` and defaults to 2.

## Why "Stop all" sequential, not parallel

Service shutdown order matters when there are real dependencies (kill the API before the DB it talks to, ideally). v1 has no dependency graph, so the safest default is sequential in port order — predictable, slightly slower, no risk of half-killed children blocking the kill of their parent. Smart Actions (USP 2, separate scope) will add proper dependency-aware shutdown.

## What v1 does NOT do

- No "Start missing" — needs the declared-stack model.
- No "Adopt running" — same reason.
- No health checks.
- No log tab per service in the menu bar (Runtime Browser is the right surface).
- No topology view.
- No `portpirate.yml`, no docker-compose import, no Procfile import.

All of the above are valid scope for v2+.

## Components

| Layer | Change |
|---|---|
| `WorkspaceStack` (new model) | `id`, `name`, `repoRoot`, `branch`, `hasMixedBranches`, `isWorktree`, `servers`, `status` |
| `StackGrouper` (new service) | Pure function `group(_:minimumServices:) -> GroupedServers` |
| `AppState` | `groupedDeveloperServers`, `developerStacks`, `ungroupedDeveloperServers`, `stopStack(_:)` |
| `StackCardView` (new view) | DisclosureGroup with header, sub-rows reuse existing `ServerRowView` |
| `MenuBarPanelView.serverSection` | Renders stacks first, then ungrouped listeners |

## Open follow-ups

- v2: `portpirate.yml` schema + loader, "Start missing", "Adopt running" with `(expected_port, expected_kind, cwd_prefix)` matching.
- v2: docker-compose `services:` import (read-only, optional).
- v3: health-check polling, "Restart only failed".
- v3: log-tab per service in Runtime Browser using `os_log` predicate streams for adopted procs.
- v4: topology view, mixed-branch warning surface in Runtime Browser, shared-service flag.

## Pricing-tier note (informational)

Passive stack grouping should be free — it is part of the core "PortPirate understands your machine" pitch. Declared stacks, Adopt-running, and health-checks belong in the paid tier alongside Smart Actions and stale auto-sweep.
