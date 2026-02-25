# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in asko, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Use [GitHub's private security advisory](https://github.com/msiric/asko/security/advisories/new) feature
3. Include steps to reproduce, impact assessment, and affected versions

We will respond within 48 hours and aim to release a fix within 7 days for critical issues.

## Security Model

See [docs/SECURITY.md](docs/SECURITY.md) for the full defense-in-depth security architecture including:

- Host-level hardening (UFW, Tailscale-only access)
- Docker container hardening (cap_drop ALL, no-new-privileges, resource limits)
- 4 isolated Docker networks (least-privilege communication)
- IronClaw WASM sandbox for AI agent tool execution
- n8n hardening (community packages disabled, public API disabled)
- Secret management (auto-generated, chmod 600, never committed)

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest main | Yes |
| older commits | No |

## Dependencies

asko uses pinned Docker image versions. Run `./scripts/update.sh` to safely update all services (creates a backup first).
