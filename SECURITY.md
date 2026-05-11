# Security Policy

## Supported Versions

MacDev is currently a preview project. Security fixes target the latest `main` branch and the latest GitHub Release.

## Reporting a Vulnerability

Please do not open public issues for vulnerabilities that could expose user process data, unsafe process-control behavior, or release integrity problems.

Report privately through GitHub Security Advisories when available, or contact the maintainer through the GitHub profile linked from this repository.

Include:

- macOS version
- MacDev version or commit SHA
- clear reproduction steps
- expected impact
- whether the issue requires a malicious local project, a local process, or a downloaded release asset

## Security Model

MacDev is designed as a local-only macOS utility:

- no analytics
- no backend service
- no account system
- no upload of process lists, paths, or workspace data

Process actions should remain precise and explainable. Broad commands such as `killall node` are intentionally outside the product model.
