# Troubleshooting

## Service Won't Start

```bash
# Check which services are running
docker compose ps

# Check logs for a specific service
docker compose logs ollama --tail 50
docker compose logs litellm --tail 50
docker compose logs open-webui --tail 50

# Restart a specific service
docker compose restart litellm
```

## "Cannot connect" / Services Unreachable

1. Check all services are running: `docker compose ps`
2. Check Caddy is routing correctly: `docker compose logs caddy --tail 20`
3. Check DNS resolution: can you reach `http://localhost:80`?
4. If using Tailscale, verify connection: `tailscale status`

## Ollama is Slow

- CPU inference is inherently slower than GPU. Expect 5-15 tok/s for 3-8B models.
- Check if the model is loaded: `docker compose exec ollama ollama ps`
- Check RAM usage: `docker stats asko-ollama`
- If RAM is exhausted, switch to a smaller model (phi3:3.8b or llama3.2:3b)

## LiteLLM Returns Errors

```bash
# Check LiteLLM health
curl http://localhost:4000/health

# Check if models are listed
curl -H "Authorization: Bearer YOUR_LITELLM_KEY" http://localhost:4000/v1/models

# Check LiteLLM logs
docker compose logs litellm --tail 50
```

Common issues:
- **"Model not found"**: The Ollama model hasn't been pulled yet. Run `docker compose exec ollama ollama pull phi3:3.8b`
- **"Connection refused to ollama:11434"**: Ollama hasn't started yet. Check `docker compose logs ollama`
- **Cloud model errors**: Verify API keys in `.env` are correct

## n8n Workflows Not Executing

1. Check n8n is running: `docker compose logs n8n --tail 30`
2. Verify workflows are active (not just imported but also activated)
3. Check n8n can reach LiteLLM: `docker compose exec n8n curl -sf http://litellm:4000/health`

## PostgreSQL Issues

```bash
# Check PostgreSQL is accepting connections
docker compose exec postgres pg_isready -U asko

# Check databases exist
docker compose exec postgres psql -U asko -l

# Check pgvector extension
docker compose exec postgres psql -U asko -d asko -c "SELECT extname FROM pg_extension;"
```

## WhatsApp (WAHA) Issues

- **QR code not showing**: Check WAHA logs: `docker compose logs waha --tail 30`
- **Messages not delivered**: Check n8n webhook workflow is active
- **Session expired**: WAHA may need re-pairing. Restart and scan QR again.

## Reset Everything

```bash
# Stop all services
docker compose down

# Remove all data (WARNING: destroys everything)
docker compose down -v

# Start fresh
./setup.sh
```

## Logs Location

All logs are available via Docker:

```bash
docker compose logs              # All services
docker compose logs -f           # Follow all logs in real-time
docker compose logs SERVICE      # Specific service
docker compose logs --since 1h   # Last hour only
```
