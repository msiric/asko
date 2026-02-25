# Architecture

## Overview

asko is a Docker Compose stack of 9 always-on services + 5 optional (profiled) services, communicating over 5 isolated networks.

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
               │ (LLMs)   │           │(pgvec) │       │
               └──────────┘           └────────┘       │
               ┌──────────┐                            │
               │ SearXNG  │  [asko_backend]            │
               │ (search) │                            │
               └──────────┘                            │
```

## Services

### Always-on

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| **Caddy** | `caddy:2.9-alpine` | Reverse proxy, only service exposing host ports | 80, 443 |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:v0.6.6` | Browser-based AI chat with multi-user RBAC, web search, Document RAG | 8080 (internal) |
| **IronClaw** | `ghcr.io/nearai/ironclaw:v0.11.1` | WASM-sandboxed AI agent for Telegram/Signal | 3000 (internal) |
| **LiteLLM** | `ghcr.io/berriai/litellm:main-v1.63.2` | Unified LLM proxy — local-first, cloud fallback | 4000 (internal) |
| **SearXNG** | `searxng/searxng:latest` | Private web search (JSON API for Open WebUI and n8n) | 8080 (internal) |
| **Ollama** | `ollama/ollama:0.6` | Local LLM inference (CPU) | 11434 (internal) |
| **n8n** | `n8nio/n8n:1.76.1` | Workflow automation + WhatsApp bridge | 5678 (internal) |
| **PostgreSQL** | `pgvector/pgvector:pg16` | Database with vector search (5 databases) | 5432 (internal) |

### Optional (profiles)

| Service | Profile | Image | Purpose |
|---------|---------|-------|---------|
| **WAHA** | `whatsapp` | `devlikeapro/waha:2024.12` | WhatsApp Web API bridge |
| **LinguaCafe** | `linguacafe` | `ghcr.io/simjanos-dev/linguacafe-webserver:v0.14.1` | Language learning (Czech, Croatian, English) |
| **LinguaCafe DB** | `linguacafe` | `mysql:8.0` | MySQL for LinguaCafe |
| **LinguaCafe Redis** | `linguacafe` | `redis:7.2-alpine` | Cache for LinguaCafe |
| **LinguaCafe NLP** | `linguacafe` | `ghcr.io/simjanos-dev/linguacafe-python-service:v0.14.1` | NLP tokenizer |

## Network Isolation

| Service | asko_proxy | asko_backend | asko_agents | asko_automation | asko_linguacafe |
|---------|:---:|:---:|:---:|:---:|:---:|
| Caddy | yes | - | - | - | - |
| Open WebUI | yes | yes | - | - | - |
| IronClaw | yes | yes | yes | - | - |
| LiteLLM | yes | yes | yes | yes | - |
| SearXNG | - | yes | - | - | - |
| Ollama | - | yes | - | - | - |
| PostgreSQL | - | yes | - | yes | - |
| n8n | yes | - | - | yes | - |
| WAHA | - | - | - | yes | - |
| LinguaCafe * | - | - | - | - | yes |

\* All 4 LinguaCafe services are isolated on `asko_linguacafe` with no cross-talk to the main stack.

## Data Flow

### Chat (Open WebUI)

```
User browser → Caddy → Open WebUI → LiteLLM → Ollama (local)
                                              → Claude/GPT (cloud fallback)
```

### Web Search (Open WebUI + SearXNG)

```
User toggles "Search the web" → Open WebUI → SearXNG → external search engines
                                           → LiteLLM → AI summarizes results
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
