# CLAUDE.md — AI Agent Context for asko

## What is asko?

A security-first, self-hosted AI assistant stack deployed via Docker Compose. One command (`./setup.sh`) provisions 8 services: Ollama (local LLMs), LiteLLM (model router), Open WebUI (chat UI), IronClaw (WASM-sandboxed agent), n8n (workflow automation), WAHA (WhatsApp bridge), PostgreSQL (with pgvector), and Caddy (reverse proxy).

## Project Structure

```
docker-compose.yml          — All services, 4 isolated networks, security hardening
setup.sh                    — Interactive wizard (preflight checks → config → deploy)
.env.example                — Template for all environment variables
config/                     — Service config templates (rendered by setup.sh)
scripts/                    — Operational scripts (backup, restore, update, health-check)
  common.sh                 — Shared utilities sourced by all scripts
workflows/n8n/              — Pre-built n8n workflow templates
tests/                      — BATS test suite (unit, template, compose, security, integration)
docs/                       — Security model, architecture, guides
```

## Key Conventions

- **Shell scripts**: Bash, `set -euo pipefail`, source `scripts/common.sh` for shared code
- **Config templates**: `*.template` files rendered by `setup.sh` via `envsubst`. LiteLLM config is copied verbatim (uses its own `os.environ/` syntax)
- **Docker hardening**: Every service has `cap_drop: ALL`, `no-new-privileges`, memory limits, healthchecks, and log rotation
- **Network isolation**: 4 Docker networks (proxy, backend, agents, automation) enforce least-privilege
- **Secrets**: Auto-generated alphanumeric strings via `python3 secrets` module, `.env` chmod 600
- **Testing**: BATS framework, TDD workflow, tests organized by category in `tests/`
- **Image tags**: Always pinned to specific versions, never `:latest` or floating

## How to Run Tests

```bash
./tests/run-all.sh           # All tests
./tests/run-all.sh unit      # Unit tests only
./tests/run-all.sh compose   # Docker Compose validation
```

Requires: `bats-core`, `python3` with `pyyaml`, Docker

## How to Validate Changes

After modifying `docker-compose.yml` or config templates:

```bash
cp .env.example .env && docker compose config --quiet    # Compose syntax
bats tests/compose/                                       # Security + network checks
bats tests/templates/                                     # Template rendering
```

## Important Patterns

- `setup.sh` supports `--source-only` to expose functions for unit testing without executing `main()`
- `scripts/common.sh` uses `BASH_SOURCE[1]` to resolve paths relative to the calling script
- WAHA is behind Docker Compose `profiles: ["whatsapp"]` — only starts with `--profile whatsapp`
- All services talk to LLMs through LiteLLM at `http://litellm:4000/v1`, never directly to Ollama

## Do NOT

- Use `:latest` or floating Docker image tags
- Expose any port to the host except Caddy's 80/443
- Add services without healthchecks, resource limits, and `cap_drop: ALL`
- Put data services (Postgres, Ollama) on `asko_proxy` network
- Store secrets in template files or committed configs
- Add Redis or other services without actual consumer wiring (YAGNI)
