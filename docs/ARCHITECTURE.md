# Architecture

## Overview

asko is a Docker Compose stack of 9 services communicating over 4 isolated networks.

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
               │ Ollama   │      │     │Postgres│   │  │
               │ (LLMs)   │◄─────┘     │(pgvec) │◄──┘  │
               └──────────┘             └────────┘      │
                                        ┌────────┐      │
                                        │ Redis  │◄─────┘
                                        └────────┘
                                        ┌────────┐
                                        │ WAHA   │ [asko_automation]
                                        │(WhatsApp)│
                                        └────────┘
```

## Services

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| **Caddy** | `caddy:2.9-alpine` | Reverse proxy, only service exposing host ports | 80, 443 |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:main` | Browser-based AI chat with multi-user RBAC | 8080 (internal) |
| **IronClaw** | `ghcr.io/nearai/ironclaw:latest` | WASM-sandboxed AI agent for Telegram/Signal | 3000 (internal) |
| **LiteLLM** | `ghcr.io/berriai/litellm:main-stable` | Unified LLM proxy — local-first, cloud fallback | 4000 (internal) |
| **Ollama** | `ollama/ollama:0.6` | Local LLM inference (CPU) | 11434 (internal) |
| **n8n** | `n8nio/n8n:latest` | Workflow automation + WhatsApp bridge | 5678 (internal) |
| **WAHA** | `devlikeapro/waha:latest` | WhatsApp Web API bridge | 3000 (internal) |
| **PostgreSQL** | `pgvector/pgvector:pg16` | Database with vector search | 5432 (internal) |
| **Redis** | `redis:7.4-alpine` | Session cache | 6379 (internal) |

## Network Isolation

| Service | asko_proxy | asko_backend | asko_agents | asko_automation |
|---------|:---:|:---:|:---:|:---:|
| Caddy | yes | - | - | - |
| Open WebUI | yes | yes | - | - |
| IronClaw | yes | - | yes | - |
| LiteLLM | yes | yes | yes | yes |
| Ollama | - | yes | - | - |
| PostgreSQL | - | yes | - | yes |
| Redis | - | yes | - | yes |
| n8n | yes | - | - | yes |
| WAHA | - | - | - | yes |

## Data Flow

### Chat (Open WebUI)

```
User browser → Caddy → Open WebUI → LiteLLM → Ollama (local)
                                              → Claude/GPT (cloud fallback)
```

### Telegram (IronClaw)

```
Telegram API → IronClaw → LiteLLM → Ollama/Cloud
```

### WhatsApp (n8n + WAHA)

```
WhatsApp → WAHA → n8n webhook → n8n AI Agent → LiteLLM → Ollama/Cloud
                                                       → n8n response → WAHA → WhatsApp
```

## LLM Routing

LiteLLM acts as the single gateway for all inference. All services connect to `http://litellm:4000/v1`.

```
local-default (phi3:3.8b)  ──┐
local-large (llama3.1:8b)  ──┤
cloud-smart (Claude Sonnet)──┼── LiteLLM ── fallback chain
cloud-opus (Claude Opus)   ──┤
cloud-fast (GPT-4o Mini)   ──┘
```

Fallback: `local-default → local-large → cloud-fast → cloud-smart`
