# Model Guide

## Recommended Local Models

Your hardware determines which models run well. asko defaults to CPU-only inference.

### 32GB RAM (Recommended Config)

| Model | Size | RAM Usage | Speed (CPU) | Best For |
|-------|------|-----------|-------------|----------|
| **phi3:3.8b** (default) | ~2.5 GB | ~5 GB | ~10-15 tok/s | Fast general assistant |
| **llama3.1:8b** | ~4.5 GB | ~8 GB | ~5-8 tok/s | Balanced quality/speed |
| **qwen2.5:7b** | ~4.5 GB | ~8 GB | ~5-8 tok/s | Multilingual (Croatian, Czech) |
| **mistral:7b** | ~4 GB | ~7 GB | ~5-10 tok/s | Strong instruction following |
| **nomic-embed-text** | ~275 MB | ~1 GB | N/A | Embeddings for RAG |

### 16GB RAM

Stick to 3-4B models:

| Model | Size | RAM Usage | Speed (CPU) |
|-------|------|-----------|-------------|
| **phi3:3.8b** | ~2.5 GB | ~5 GB | ~10-15 tok/s |
| **llama3.2:3b** | ~2 GB | ~4 GB | ~15-20 tok/s |

### 8GB RAM

Only the smallest models:

| Model | Size | RAM Usage | Speed (CPU) |
|-------|------|-----------|-------------|
| **llama3.2:1b** | ~1.3 GB | ~3 GB | ~20-30 tok/s |
| **phi3:mini** | ~2.5 GB | ~5 GB | ~8-12 tok/s |

## Pulling Models

```bash
# Pull the default model
docker compose exec ollama ollama pull phi3:3.8b

# Pull additional models
docker compose exec ollama ollama pull llama3.1:8b
docker compose exec ollama ollama pull qwen2.5:7b
docker compose exec ollama ollama pull nomic-embed-text

# List installed models
docker compose exec ollama ollama list
```

Or use the helper script:

```bash
./scripts/pull-models.sh
```

## Cloud Models

Cloud models are available when you provide API keys in `.env`:

| Model | Provider | Cost | Quality |
|-------|----------|------|---------|
| `cloud-fast` | OpenAI GPT-4o Mini | ~$0.15/M tokens | Good |
| `cloud-smart` | Claude Sonnet 4 | ~$3/M tokens | Excellent |
| `cloud-opus` | Claude Opus | ~$15/M tokens | Best available |

LiteLLM automatically falls back to cloud models when local models fail or time out.

## Switching Models

### In Open WebUI

Use the model dropdown at the top of the chat to select any available model.

### In IronClaw

Change the default model in `.env`:

```bash
IRONCLAW_LLM_MODEL=local-large
```

Then restart: `docker compose restart ironclaw`

### In n8n Workflows

Each AI node in n8n can specify its model. Edit the workflow and change the `model` parameter.

## Performance Tips

- **Keep one model loaded**: Ollama unloads models after 5 minutes of inactivity. The first request after idle has a cold-start delay.
- **Use the right model for the task**: phi3:3.8b for simple questions, llama3.1:8b for complex reasoning, cloud models for quality-critical tasks.
- **Monitor RAM**: `docker stats asko-ollama` shows real-time memory usage.
