# asko — Complete Session Log

## What We Built

### Repository: https://github.com/msiric/asko
- 20+ commits, 148 BATS tests, 62% agent-readiness score (100% security)
- MIT licensed, open source

### Infrastructure Stack (Docker Compose)
- **PostgreSQL** (pgvector) — shared database, tuned for 300 MAU
- **Ollama** — local LLM inference (qwen2.5:7b + nomic-embed-text)
- **LiteLLM** — model routing proxy (local-first, cloud fallback)
- **SearXNG** — private web search (wired into Open WebUI)
- **Open WebUI** — browser-based AI chat with web search + Document RAG
- **n8n** — workflow automation
- **Caddy** — reverse proxy
- **WAHA** — WhatsApp bridge (optional profile)
- **LinguaCafe** — language learning (optional profile)

### Agent Layer (Host-installed)
- **IronClaw v0.12.0** — WASM-sandboxed AI agent with Telegram channel
- Connected to Ollama directly (bypassing LiteLLM for speed)
- PostgreSQL for persistent memory
- Tailscale Funnel for Telegram webhooks

### Operational Scripts
- setup.sh (interactive wizard), backup.sh, restore.sh, update.sh
- health-check.sh, pull-models.sh, import-workflows.sh
- Makefile with 20 targets
- Daily backup cron at 3:00 AM

---

## What's Working

| Feature | Status |
|---------|--------|
| Open WebUI chat (local LLM) | Fast, 2-3 seconds |
| Open WebUI web search (SearXNG) | Working |
| Open WebUI Document RAG | Working |
| Tailscale remote access | Connected (100.119.192.53) |
| n8n workflow engine | Running, accessible at :5678 |
| IronClaw agent (Telegram) | Working but VERY slow (2+ min per response) |
| LinguaCafe (Italian) | Working (stopped by default) |
| Daily backups | Cron scheduled |
| All Docker services | Healthy, auto-restart |

---

## Critical Issue: IronClaw Performance on CPU

### The Problem
IronClaw sends ~24 built-in tool schemas (~2000+ prompt tokens) with every LLM request. On CPU-only hardware (Ryzen 7 6800U), prompt processing is ~30-40 tok/s. This means:
- 2000 prompt tokens ÷ 37 tok/s = ~55 seconds just for prompt evaluation
- Plus model loading, generation, network overhead = 75-150 seconds total

### Why Open WebUI is Fast
Open WebUI sends a simple system prompt (~50 tokens) with no tools. Same model responds in 2-3 seconds.

### Why OpenClaw Users Don't Have This Problem
- They use Mac Mini M4 Pro with 48GB unified memory (35-55 tok/s GPU-accelerated)
- They use 32B models that handle tool schemas more efficiently
- They use cloud APIs (Claude, GPT) for the agent layer
- OpenClaw's recommended setup: `qwen3-coder:32b` as primary model

### The Solution
**Use a cloud API (Anthropic Claude or OpenAI GPT) for IronClaw's agent reasoning.** Keep local Ollama models for Open WebUI chat. This is what most production OpenClaw/IronClaw deployments do.

### How to Implement
In `~/.ironclaw/.env`:
```bash
LLM_BACKEND=anthropic
ANTHROPIC_API_KEY=sk-ant-your-key-here
```
Or:
```bash
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:4000/v1  # Through LiteLLM
LLM_API_KEY=your-litellm-key
LLM_MODEL=cloud-smart  # Routes to Claude via LiteLLM
```

---

## Deployment Issues Found (25+ findings)

Full list in `docs/DEPLOYMENT-ISSUES.md`. Top issues:

### Must Fix Before Public Release
1. **Docker image tags didn't exist** — shipped fake tags, all had to be updated on first deploy
2. **IronClaw doesn't publish Docker images** — had to install on host instead
3. **Healthchecks used `curl` which isn't in newer container images** — fixed with python3/wget/ollama alternatives
4. **LiteLLM `/health` requires auth in v1.81+** — fixed with `/health/liveliness`
5. **Open WebUI `ENABLE_SIGNUP=false` blocks first admin creation** — needs signup enabled initially
6. **setup.sh doesn't recover from partial failures** — forces full reset
7. **SearXNG web search not auto-configured in Open WebUI admin** — user must manually set in UI
8. **n8n secure cookie blocks HTTP access** — fixed with `N8N_SECURE_COOKIE=false`
9. **MySQL/Redis need Linux capabilities** — `cap_drop: ALL` too aggressive for databases
10. **WAHA dashboard is paid-only** — API access works but no web UI
11. **IronClaw onboard wizard fails to save to PostgreSQL** — `ironclaw config set` workaround
12. **IronClaw won't run as systemd service** — exits immediately without TTY
13. **Qwen3 thinking mode makes responses 9 minutes** — must use non-thinking models
14. **IronClaw tool schema overflows small model context** — 24 tools too many for 3B-7B models on CPU

### Fixed During Deployment
- Ollama: 0.6 → 0.17.1
- Open WebUI: v0.6.6 → v0.8.5
- LiteLLM: main-v1.63.2 → main-v1.81.12-stable
- n8n healthcheck: localhost → 127.0.0.1
- Caddy: added :80 listener, fixed healthcheck
- LinguaCafe: hostname mismatch, NLP volume path, PYTHONPATH
- WAHA: tag fix, API key requirement, healthcheck accepts 401
- PostgreSQL/LiteLLM/Ollama: exposed to localhost for IronClaw host access

---

## IronClaw Configuration (Current State)

### Files
- Binary: `~/.cargo/bin/ironclaw` (v0.12.0)
- Config: `~/.ironclaw/.env`
- Channels: `~/.ironclaw/channels/telegram.wasm`, `whatsapp.wasm`
- Tools: (external WASM tools removed to reduce prompt size)
- Systemd: `/etc/systemd/system/ironclaw.service` (not working — exits without TTY)

### Current .env
```bash
DATABASE_BACKEND=postgres
DATABASE_URL=postgres://asko:<password>@localhost:5432/ironclaw
LLM_BACKEND=ollama
LLM_BASE_URL=http://localhost:11434
LLM_API_KEY=<litellm-key>
LLM_MODEL=qwen2.5:7b
OLLAMA_MODEL=qwen2.5:7b
OLLAMA_BASE_URL=http://localhost:11434
AGENT_NAME=asko
GATEWAY_ENABLED=true
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=3001
TELEGRAM_BOT_TOKEN=<redacted>
HEARTBEAT_ENABLED=true
SECRETS_MASTER_KEY=<redacted>
RUST_LOG=ironclaw=info
REPL_ENABLED=false
```

### Running IronClaw
```bash
export OLLAMA_MODEL=qwen2.5:7b
ironclaw --no-onboard
```
Must run in a TTY (SSH session or tmux). Systemd service doesn't work.

### Tailscale Funnel (for Telegram)
```bash
sudo tailscale funnel --bg 5678
```
Exposes n8n at `https://asko.tail8a810a.ts.net/`

---

## Next Steps (Priority Order)

### Immediate
1. **Switch IronClaw to Anthropic API** — add API key, change LLM_BACKEND to anthropic
2. **Re-enable IronClaw WASM tools** — Gmail, Google Calendar, GitHub (now that cloud model handles tools fast)
3. **Fix IronClaw systemd service** — research the TTY exit issue, possibly use tmux wrapper
4. **Set up Tailscale Funnel as systemd service** — survives reboots
5. **Update LiteLLM config** — add qwen2.5:7b as local-default, remove deprecated request_timeout

### This Week
6. **Fix all deployment issues in setup.sh** — image tag verification, retry/resume, first-admin flow
7. **Onboard girlfriend** — Tailscale + Open WebUI account
8. **Test IronClaw memory** — "Remember my name is Mario", verify persistent memory works
9. **Set up morning briefing** — n8n cron workflow with weather

### Before Public Release
10. **Have 2-3 friends test ./setup.sh** on different hardware
11. **Fix the 25 deployment issues** systematically
12. **Update all documentation** to match current architecture (IronClaw on host, not Docker)
13. **Update tests** — many are broken by architecture changes
14. **Update ARCHITECTURE.md, SECURITY.md, README** — remove IronClaw from compose, add host install docs

---

## Roadmap Ideas

### Short-term
- Morning briefing workflow (weather + calendar + news → Telegram)
- Flight price monitor (Prague ↔ Split)
- RSS news digest (Croatian + Czech feeds)
- Email triage (Gmail integration via IronClaw)
- Voice message transcription via Whisper

### Medium-term
- Family member onboarding (girlfriend, parents in Split)
- Shared grocery list via Telegram group
- Recipe suggestions from ingredients
- Document Q&A for family documents (insurance, lease, tax)
- IronClaw WhatsApp support (when P1 feature lands)

### Long-term
- Connect Prague and Split home labs via Tailscale
- Cross-site automations (n8n in Prague → Home Assistant in Split)
- Voice assistant (Whisper + Piper) for Prague apartment
- Photo organization via Immich AI features
- Custom IronClaw skills for family-specific workflows

---

## Hardware Notes

### Beelink SER5 MAX
- Ryzen 7 6800U, 27GB usable RAM, 468GB NVMe
- Ubuntu Server 24.04 with HWE kernel 6.17
- WiFi: MediaTek MT7922 (requires HWE kernel + NetworkManager)
- Tailscale connected: 100.119.192.53
- SSH: `ssh asko@10.0.0.41` (key-based, passwordless sudo)

### Performance Reality
- **Open WebUI (simple chat)**: 2-3 seconds — excellent
- **Open WebUI (web search)**: 5-10 seconds — good
- **IronClaw (24 tools, local model)**: 60-150 seconds — unusable
- **IronClaw (cloud API)**: Expected 2-5 seconds — not yet tested
- **Ollama direct (no tools)**: 2-8 seconds — fast
- **Ollama with 1 tool**: ~4-8 seconds — acceptable
- **Ollama with 24 tools**: 55-150 seconds — too slow for CPU

### Models Installed
- `qwen2.5:7b` (4.7 GB) — primary model
- `nomic-embed-text` (274 MB) — embeddings for RAG
