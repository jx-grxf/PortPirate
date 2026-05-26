# Agent Audit — Cursor

- **Agent version:** _todo: fill in exact version after re-running audit inside Cursor_
- **Audited on:** 2026-05-26
- **Machine:** macOS 26.5.0 (Darwin 25.5.0), arm64

## Audit output

Full `./script/audit_agent_env.sh` output should be pasted here next time the audit is run inside Cursor. The detection was confirmed indirectly via a stealth test (see Notes below).

```
<paste full audit script output here>
```

## Verdict

- **Env-based detection works?** ✅ — confirmed end-to-end via stealth test
- **Parent-chain detection works?** ✅ as long as Cursor's agent process is still in the PID chain
- **Argv detection works?** N/A for indirect spawns

## Markers observed

- `CURSOR_*` family — at least one `CURSOR_*` env key is exported into subprocess environments. Exact set not yet captured; rerun the audit script inside Cursor and paste the output above.

## Recommended changes

- [ ] Re-run `./script/audit_agent_env.sh` inside a Cursor agent shell and fill in the audit output and exact version above.
- [ ] If the audit reveals a Cursor-specific session ID key, add it to the session-ID lookup in `AgentDetector.ownerFromEnvironment`.

## Notes

Verification method (2026-05-26 stealth test):

1. Cursor was given a benign task with no mention of PortPirate, attribution, or agent detection: spin up a local HTTP preview server on port 4244 in a temp folder.
2. Cursor spawned `python3 -m http.server 4244` (in a wrapper script). The listener appeared in PortPirate's panel with a **filled** Cursor badge — confirming env-source detection (otherwise the badge would be outlined or absent).
3. The stack card in the same panel showed mixed `Claude` + `Cursor` badges side by side on listeners inside the PortPirate repo, demonstrating the multi-agent attribution flow works as designed.

The exact env-key list still needs to be captured to harden the detector and to allow extraction of a Cursor session ID for the tooltip.
