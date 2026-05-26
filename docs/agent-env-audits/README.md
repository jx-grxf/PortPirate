# Agent Environment Audits

PortPirate's env-based agent detection (see [ADR-001](../adr-001-agent-attribution.md)) only works if the agent actually exports its marker environment variables into spawned subprocesses. We have to verify this per agent on real machines instead of assuming.

## How to run an audit

1. Open a terminal **spawned by the agent** you want to audit (or run the agent's "shell" / "terminal" command, then run the audit script inside the resulting shell).
2. From the PortPirate repo root, run:

   ```bash
   ./script/audit_agent_env.sh
   ```

3. Copy the entire output into the corresponding file in this folder. Use [`_template.md`](_template.md) as the starting structure.
4. Open a PR with the new audit file. The audit ought to also drive a change in [`AgentDetector.swift`](../../Sources/PortPirateCore/Services/AgentDetector.swift): rules with no real-world env signal should be removed, and rules whose envs show up should be marked as verified in [ADR-001](../adr-001-agent-attribution.md).

## Status

| Agent | File | Env-based detection | Notes |
|---|---|---|---|
| Claude Code | [`claude-code.md`](claude-code.md) | ✅ Verified | `CLAUDECODE=1`, `CLAUDE_CODE_*`, `AI_AGENT=claude-code_*` |
| Cursor | [`cursor.md`](cursor.md) | ✅ Verified | `CURSOR_*` exports confirmed via stealth test |
| Codex CLI | _todo_ | ⬜ | Run `audit_agent_env.sh` inside a Codex session |
| Aider | _todo_ | ⬜ | |
| opencode | _todo_ | ⬜ | |
| Gemini CLI | _todo_ | ⬜ | |
| GitHub Copilot CLI | _todo_ | ⬜ | |
| Augment (auggie) | _todo_ | ⬜ | |
| Windsurf | _todo_ | ⬜ | |
| Qwen Code | _todo_ | ⬜ | |
