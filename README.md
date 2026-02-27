# asko

Security-first, self-hosted AI assistant stack. One command to deploy.

## What is asko?

asko packages a complete AI assistant stack into a single `docker compose` deployment: local LLM inference (Ollama), a unified model router with cloud fallback (LiteLLM), a browser-based chat UI (Open WebUI), private web search (SearXNG), and workflow automation with WhatsApp bridging (n8n). Everything runs on your hardware, behind Tailscale, with zero exposed ports. Optionally, install [IronClaw](https://github.com/nearai/ironclaw) on the host for a WASM-sandboxed AI agent with Telegram support.

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
                    └──┬──────────────┬────────┬──────────┘
                       │              │        │
               ┌───────┴─┐      ┌────┴───┐ ┌──┴─────┐
               │Open WebUI│      │  n8n   │ │LiteLLM │
               │  (chat)  │      │(flows) │ │(router)│
               └────┬─────┘      └───┬────┘ └┬──┬───┘
                    │                 │       │  │
            [asko_backend]       [asko_automation]
                    │                 │       │  │
               ┌────┴────┐      ┌────┴───┐   │  │
               │ Ollama   │      │Postgres│◄──┘  │
               │ (LLMs)   │      │(pgvec) │      │
               └──────────┘      └────────┘      │
               ┌──────────┐                      │
               │ SearXNG  │  [asko_backend]      │
               │ (search) │                      │
               └──────────┘                      │
```

4 isolated Docker networks enforce least-privilege communication. Only Caddy exposes host ports. See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

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
| **Open WebUI** | Browser-based chat (multi-user, first user becomes admin) |
| **n8n** | Workflow automation + WhatsApp bridge |
| **SearXNG** | Private web search (enables AI web search in chat) |
| **WAHA** | WhatsApp Web API bridge (opt-in: `--profile whatsapp`) |
| **LinguaCafe** | Language learning (opt-in: `--profile linguacafe`) |
| **PostgreSQL** | Database with pgvector for embeddings |
| **Caddy** | Reverse proxy |

> **IronClaw** (optional): Install on the host for a WASM-sandboxed AI agent with Telegram support. See [docs/SESSION-LOG.md](docs/SESSION-LOG.md) for setup instructions.

## Security

- Zero ports exposed to the internet — Tailscale-only access
- Docker hardening: `cap_drop: ALL`, `no-new-privileges`, resource limits on every container
- 4 isolated Docker networks (least-privilege communication)
- Auto-generated secrets, `.env` chmod 600
- n8n hardened: community packages disabled, public API disabled, env access blocked

See [docs/SECURITY.md](docs/SECURITY.md) for the full security model.

## Models

asko defaults to local-first inference with cloud fallback:

| Model | Type | Speed (CPU) |
|-------|------|-------------|
| qwen2.5:7b | Local (default) | ~8-12 tok/s |
| nomic-embed-text | Local (embeddings) | N/A |
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
