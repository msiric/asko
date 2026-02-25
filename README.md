# asko

Security-first, self-hosted AI assistant stack. One command to deploy.

## What is asko?

asko packages a complete AI assistant stack into a single `docker compose` deployment: local LLM inference (Ollama), a unified model router with cloud fallback (LiteLLM), a browser-based chat UI (Open WebUI), a WASM-sandboxed AI agent (IronClaw), and workflow automation with WhatsApp bridging (n8n). Everything runs on your hardware, behind Tailscale, with zero exposed ports.

## Quick Start

```bash
git clone https://github.com/msiric/asko.git
cd asko
./setup.sh
```

The setup wizard detects your hardware, generates secure credentials, pulls Docker images, and starts the stack.

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Tailscale VPN                │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────┴──────────────────────┐
                    │  Caddy (:80/:443)   [asko_proxy]    │
                    └──┬────────┬────────┬────────┬───────┘
                       │        │        │        │
               ┌───────┴─┐ ┌───┴────┐ ┌─┴──────┐ ┌┴───────┐
               │Open WebUI│ │IronClaw│ │  n8n   │ │LiteLLM │
               │  (chat)  │ │(agent) │ │(flows) │ │(router)│
               └────┬─────┘ └───┬────┘ └───┬────┘ └┬──┬───┘
                    │            │          │       │  │
            [asko_backend] [asko_agents]  [asko_automation]
                    │            │          │       │  │
               ┌────┴────┐      │     ┌────┴───┐   │  │
               │ Ollama   │◄─────┘     │Postgres│◄──┘  │
               │ (LLMs)   │           │(pgvec) │      │
               └──────────┘           └────────┘      │
                                      ┌────────┐      │
                                      │ Redis  │◄─────┘
                                      └────────┘
```

4 isolated Docker networks enforce least-privilege communication. Only Caddy exposes host ports. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Hardware Requirements

| | Minimum | Recommended |
|---|---------|-------------|
| **CPU** | x86_64, 4 cores | 8+ cores |
| **RAM** | 16 GB | 32 GB |
| **Disk** | 50 GB free | 100 GB+ |
| **OS** | Ubuntu Server 24.04 | Ubuntu Server 24.04 |

## Services

| Service | Purpose |
|---------|---------|
| **Ollama** | Local LLM inference (CPU) |
| **LiteLLM** | Model routing proxy — local-first, cloud fallback |
| **Open WebUI** | Browser-based chat (multi-user) |
| **IronClaw** | WASM-sandboxed AI agent (Telegram, Signal) |
| **n8n** | Workflow automation + WhatsApp bridge |
| **WAHA** | WhatsApp Web API bridge |
| **PostgreSQL** | Database with pgvector for embeddings |
| **Redis** | Session cache |
| **Caddy** | Reverse proxy |

## Security

- Zero ports exposed to the internet — Tailscale-only access
- WASM sandbox for all AI agent tool execution (IronClaw)
- Docker hardening: `cap_drop: ALL`, `no-new-privileges`, resource limits on every container
- 4 isolated Docker networks (least-privilege communication)
- Auto-generated secrets, `.env` chmod 600
- n8n hardened: community packages disabled, public API disabled, env access blocked

See [docs/SECURITY.md](docs/SECURITY.md) for the full security model.

## Models

asko defaults to local-first inference with cloud fallback:

| Model | Type | Speed (CPU) |
|-------|------|-------------|
| phi3:3.8b | Local (default) | ~10-15 tok/s |
| llama3.1:8b | Local (large) | ~5-8 tok/s |
| Claude Sonnet/Opus | Cloud fallback | Fast (API) |
| GPT-4o Mini | Cloud fallback | Fast (API) |

Cloud models require API keys in `.env`. See [docs/MODELS.md](docs/MODELS.md).

## Remote Access

All access is via [Tailscale](https://tailscale.com) (WireGuard VPN). See [docs/TAILSCALE.md](docs/TAILSCALE.md) for setup.

## Adding Family Members

See [docs/FAMILY-ACCESS.md](docs/FAMILY-ACCESS.md) for onboarding family to Open WebUI, Telegram, and WhatsApp.

## Maintenance

```bash
make health            # Check all services
make backup            # Backup databases + configs
make update            # Backup, pull updates, rolling restart
make restore DIR=...   # Restore from backup
make pull-models       # Download Ollama models
make logs              # Follow all service logs
```

## Testing

```bash
make test              # Run all tests
make test-unit         # Unit tests only
make test-compose      # Compose validation
make lint-all          # Run all linters
```

Requires [BATS](https://github.com/bats-core/bats-core) and GNU Make. Run `make help` for all commands.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

[MIT](LICENSE)
