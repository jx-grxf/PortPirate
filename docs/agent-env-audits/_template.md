# Agent Audit — <Agent Name>

- **Agent version:** <fill in, e.g. 1.2.3>
- **Audited on:** <YYYY-MM-DD>
- **Machine:** <macOS version, arch>

## Audit output

Paste the full output of `./script/audit_agent_env.sh` here, fenced:

```
<paste here>
```

## Verdict

- **Env-based detection works?** ✅ / ❌
- **Parent-chain detection works?** Likely ✅ as long as the agent's tool/CLI is still in the PID chain when the dev server starts.
- **Argv detection works?** N/A for indirect spawns (server is `python3`, `node`, etc.).

## Markers observed

List the env keys this agent actually exports that PortPirate would key on:

- `EXAMPLE_KEY=...`

## Recommended changes

- [ ] Update `AgentDetector.swift` env rules: add / remove / rename prefix(es).
- [ ] Update env-whitelist in `ProcessInspector.swift`.
- [ ] Update verified list in `docs/adr-001-agent-attribution.md`.
- [ ] Update status table in `docs/agent-env-audits/README.md`.

## Notes

Free text — surprises, gotchas, version differences, etc.
