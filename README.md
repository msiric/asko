# asko

Security-first, self-hosted AI assistant stack. One command to deploy.

## What is asko?

asko packages a complete AI assistant stack into a single `docker compose` deployment: local LLM inference (Ollama), a unified model router with cloud fallback (LiteLLM), a browser-based chat UI (Open WebUI), a WASM-sandboxed AI agent (IronClaw), and workflow automation with WhatsApp bridging (n8n). Everything runs on your hardware, behind Tailscale, with zero exposed ports.

## Quick Start

```bash
git clone https://github.com/mariosiric/asko.git
cd asko
./setup.sh
```

## Architecture

```
Family (Split)  <->  Tailscale VPN  <->  Beelink (Prague)  <->  Girlfriend (Prague)

+-- asko_proxy ----------------------------------------+
|  Caddy (:80/:443) -> Open WebUI, n8n, IronClaw, LiteLLM  |
+------------------------------------------------------+
+-- asko_backend --------------------------------------+
|  LiteLLM -> Ollama, PostgreSQL (pgvector), Redis     |
+------------------------------------------------------+
+-- asko_agents ---------------------------------------+
|  IronClaw -> LiteLLM                                 |
+------------------------------------------------------+
+-- asko_automation -----------------------------------+
|  n8n -> LiteLLM, PostgreSQL, Redis                   |
+------------------------------------------------------+
```

## Hardware Requirements

- **CPU**: x86_64, 4+ cores (8+ recommended)
- **RAM**: 16GB minimum, 32GB recommended
- **Disk**: 50GB+ free (models take 5-20GB each)
- **OS**: Ubuntu Server 24.04

## Services

| Service | Purpose |
|---------|---------|
| **Ollama** | Local LLM inference (CPU) |
| **LiteLLM** | Model routing proxy — local-first, cloud fallback |
| **Open WebUI** | Browser-based chat (multi-user) |
| **IronClaw** | WASM-sandboxed AI agent (Telegram, Signal) |
| **n8n** | Workflow automation + WhatsApp bridge |
| **PostgreSQL** | Database (with pgvector for embeddings) |
| **Redis** | Session cache |
| **Caddy** | Reverse proxy |

## Security

- Zero ports exposed to the internet — Tailscale-only access
- WASM sandbox for all AI agent tool execution (IronClaw)
- Docker hardening: `cap_drop: ALL`, `no-new-privileges`, resource limits
- 4 isolated Docker networks (least-privilege communication)
- Auto-generated secrets, `.env` chmod 600
- n8n hardened: community packages disabled, public API disabled

See [docs/SECURITY.md](docs/SECURITY.md) for the full security model.

## License

MIT
