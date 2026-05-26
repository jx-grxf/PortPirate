# Agent Audit — Claude Code

- **Agent version:** 2.1.150
- **Audited on:** 2026-05-26
- **Machine:** macOS 26.5.0 (Darwin 25.5.0), arm64

## Audit output

Excerpt from `./script/audit_agent_env.sh` (env section only, full output captured live):

```
Matching env vars in this shell:
  AI_AGENT=claude-code_2-1-150_agent
  CLAUDE_CODE_ENTRYPOINT=cli
  CLAUDE_CODE_EXECPATH=/Users/<user>/.local/share/claude/versions/2.1.150
  CLAUDE_CODE_SESSION_ID=<uuid>
  CLAUDE_EFFORT=medium
  CLAUDE_PLUGIN_DATA=/Users/<user>/.claude/plugins/data/<plugin>
  CLAUDECODE=1
  TERM_PROGRAM=Apple_Terminal
  TERM_PROGRAM_VERSION=470.2
```

## Verdict

- **Env-based detection works?** ✅
- **Parent-chain detection works?** ✅ (parent chain reaches `claude` for shell-child processes)
- **Argv detection works?** N/A for indirect spawns

## Markers observed

- `CLAUDECODE=1` — strongest single marker
- `CLAUDE_CODE_SESSION_ID` — provides session ID for the tooltip
- `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_EXECPATH` — supplementary
- `AI_AGENT=claude-code_*` — generic AI marker

## Recommended changes

All rules currently in `AgentDetector.swift` are correct for Claude Code. No changes needed.

## Notes

Confirmed end-to-end: a Python `http.server` started inside a Claude-spawned shell shows up in PortPirate with a filled (env-source) Claude badge without any priming or wrapping.
