# First Deployment Issues Log

Issues encountered during the first real deployment on a Beelink SER5 MAX (Ryzen 7 6800U, 32GB, Ubuntu Server 24.04). Every item here is friction a user would hit when running `./setup.sh`.

## Critical (setup.sh fails or stack doesn't start)

### 1. Docker image tags didn't exist
**Symptom**: `docker compose pull` fails with "denied" for multiple images.
**Root cause**: We pinned version tags that don't exist on the registries. The tags were chosen during development without verifying against actual Docker Hub/GHCR tags.
- `ollama/ollama:0.6` → doesn't exist (actual: `0.17.1`)
- `ghcr.io/open-webui/open-webui:v0.6.6` → doesn't exist (actual: `v0.8.5`)
- `ghcr.io/berriai/litellm:main-v1.63.2` → doesn't exist (actual: `main-v1.81.12-stable`)
- `ghcr.io/nearai/ironclaw:v0.11.1` → no Docker images published at all

**Fix applied**: Updated all tags to real releases. Removed IronClaw from compose (install on host instead).
**Remaining work**: Add a CI job that periodically verifies all image tags are pullable. Consider a `make verify-images` target.

### 2. IronClaw doesn't publish Docker images
**Symptom**: `docker compose pull` fails for ironclaw with "denied".
**Root cause**: IronClaw is distributed as a CLI binary (shell script installer, brew, npm), not as a Docker image. Our entire compose service definition was based on a non-existent image.
**Fix applied**: Removed IronClaw service from compose. Added comment pointing to host installation.
**Remaining work**: Either create our own Dockerfile for IronClaw, or redesign the agent layer to run IronClaw on the host alongside the Docker stack. Update ARCHITECTURE.md, CLAUDE.md, tests, and all docs that reference IronClaw as a container.

### 3. Healthchecks use `curl` which isn't in the containers
**Symptom**: Services start successfully but healthchecks fail forever, showing as "unhealthy". Downstream services that `depends_on: condition: service_healthy` never start.
**Root cause**: Newer versions of Ollama and LiteLLM images stripped `curl` from the container. Our healthchecks all used `curl -sf`.
**Fix applied**:
- LiteLLM: use `python3 urllib` (python is in the image)
- Ollama: use `ollama list` CLI command
- n8n: use `wget` (available in n8n image)
**Remaining work**: Audit ALL healthchecks to ensure they use tools that are guaranteed to be in the container. Add a test that validates this.

### 4. LiteLLM `/health` endpoint requires auth in newer versions
**Symptom**: LiteLLM healthcheck returns 401 Unauthorized.
**Root cause**: The `/health` endpoint in LiteLLM v1.81+ requires the master key. The unauthenticated endpoint is `/health/liveliness`.
**Fix applied**: Changed healthcheck to use `/health/liveliness`.
**Remaining work**: None — fixed.

### 5. LiteLLM start_period too short for first-run DB migrations
**Symptom**: LiteLLM takes 30-60 seconds on first run to complete Prisma migrations. Healthcheck starts at 15s, fails, and Docker marks it unhealthy before it's ready. Downstream services fail to start.
**Fix applied**: Increased `start_period` to 60s and `retries` to 5.
**Remaining work**: None — fixed.

### 6. n8n healthcheck uses `localhost` but n8n binds to `127.0.0.1`
**Symptom**: n8n healthcheck fails even though n8n is running.
**Root cause**: n8n listens on `127.0.0.1:5678`, not `0.0.0.0:5678`. Docker's `localhost` inside the container resolves differently.
**Fix applied**: Changed healthcheck to use `127.0.0.1` explicitly.
**Remaining work**: None — fixed.

### 7. Caddy only listens on :443, not :80
**Symptom**: Caddy starts but healthcheck on port 80 fails. Users can't access `http://10.0.0.x`.
**Root cause**: Caddyfile uses domain-based hostnames (`chat.asko.local`) which Caddy interprets as HTTPS by default, even with `auto_https off`. No `:80` listener was configured.
**Fix applied**: Added explicit `:80` catch-all block and `http://` prefix on domain entries.
**Remaining work**: None — fixed.

### 8. Open WebUI signup disabled blocks first admin creation
**Symptom**: User sees "Get started with Open WebUI" form but clicking "Create Admin Account" returns "You do not have permission to access this resource."
**Root cause**: `ENABLE_SIGNUP: "false"` in compose prevents ALL signups, including the first admin. Open WebUI requires signup to be enabled for the first user.
**Fix needed**: Either set `ENABLE_SIGNUP: "true"` initially and disable after first user is created via post-setup automation, or use the `WEBUI_ADMIN_EMAIL` / `WEBUI_ADMIN_PASSWORD` env vars if supported. The current post-setup automation tried to create the admin via API but it ran during setup.sh which failed at the pull stage — so it never executed.

## High (significant friction, user can work around)

### 9. WiFi driver not loaded on Ubuntu Server 24.04
**Symptom**: No WiFi interface visible after fresh Ubuntu Server install on Beelink SER5 MAX.
**Root cause**: MediaTek MT7922 WiFi chip requires the `mt7921e` kernel module which isn't loaded by default. The base kernel (6.8) doesn't support it well — requires the HWE kernel (6.17).
**Fix needed**: Document this in a hardware compatibility guide. Not a code fix — it's an OS/driver issue.

### 10. `setup.sh` doesn't recover from partial failures
**Symptom**: If `docker compose pull` fails partway through (e.g., bad image tag), setup.sh exits. On re-run, it detects `.env` exists and asks to reset. User must choose "Reset" which regenerates ALL secrets unnecessarily — the old secrets were fine, only the images were wrong.
**Fix needed**: The idempotency flow should have a third option: "Retry from where it left off" — skip env generation and template rendering, go straight to `docker compose pull` and continue.

### 11. `request_timeout` config key deprecated in LiteLLM v1.81+
**Symptom**: Warning in LiteLLM logs: "Key 'request_timeout' is not a valid argument for Router.__init__(). Ignoring this key."
**Root cause**: LiteLLM changed the config schema between the version we developed against and the actual release.
**Fix needed**: Update `config/litellm/config.yaml.template` to remove or rename `request_timeout`.

## Medium (confusing but not blocking)

### 12. Keyboard layout issues on Ubuntu Server console
**Symptom**: `|` and `>` characters don't work on Croatian keyboard layout.
**Root cause**: Ubuntu Server minimal install doesn't configure keyboard layout properly. Needs `dpkg-reconfigure keyboard-configuration`.
**Fix needed**: Document in setup guide. Not a code fix.

### 13. No internet on fresh Ubuntu Server (no WiFi, no DHCP on USB tether)
**Symptom**: Fresh Ubuntu install has no network connectivity. `dhclient` not available. `systemd-networkd` not running. `nmcli` not installed.
**Root cause**: Ubuntu Server 24.04 minimal install ships with NetworkManager but it's not configured for any interfaces.
**Fix needed**: Document the WiFi/network setup steps prominently. Consider adding a `scripts/setup-network.sh` helper.

### 14. Open WebUI Web Search Engine defaults to `ollama_cloud`, not `searxng`
**Symptom**: Web search toggle exists in admin settings but is set to `ollama_cloud` by default. Users get hallucinated responses instead of actual search results.
**Root cause**: The `RAG_WEB_SEARCH_ENGINE=searxng` env var is set in compose but Open WebUI v0.8.5 may not respect it on first run, defaulting to `ollama_cloud` in the admin UI. The user must manually go to Admin → Settings → Web Search and change the dropdown to `searxng` and enter the query URL.
**Fix needed**: Investigate whether Open WebUI respects the env var on fresh install or if the admin UI setting takes precedence. If UI overrides env, the post-setup automation should configure this via the Open WebUI API after admin creation.

### 15. WAHA image tag `2024.12` doesn't exist
**Symptom**: `docker compose --profile whatsapp up -d` fails with "not found" for `devlikeapro/waha:2024.12`.
**Root cause**: Same as issue #1 — tag was chosen during development without verification. Actual latest is `2026.2.2`.
**Fix applied**: Updated to `devlikeapro/waha:2026.2.2`.
**Remaining work**: Same as #1 — add image tag verification to CI.

### 16. n8n has no port mapping in docker-compose.yml
**Symptom**: n8n is running but inaccessible from the browser. Only reachable via docker network.
**Root cause**: n8n was only on `asko_proxy` and `asko_automation` networks with no host port mapping. The Caddy reverse proxy routes by hostname (`n8n.asko.local`) which requires DNS setup.
**Fix applied**: Added `ports: ["5678:5678"]` manually on the Beelink.
**Remaining work**: Add port mapping to docker-compose.yml in the repo, or document that n8n requires DNS/hosts file setup for Caddy routing.

### 18. MySQL (LinguaCafe) fails with `setgid: Operation not permitted`
**Symptom**: `asko-linguacafe-db` container crashes on startup with `setgid: Operation not permitted`.
**Root cause**: `cap_drop: ALL` removes SETGID capability which MySQL 8.0 requires. Our hardened default strips all capabilities, but MySQL needs CHOWN, SETUID, SETGID, and DAC_OVERRIDE (same as PostgreSQL).
**Fix applied**: Added `cap_add: [CHOWN, SETUID, SETGID, DAC_OVERRIDE]` to linguacafe-db service.
**Remaining work**: None — fixed. Add to security docs that database services need these capabilities.

### 19. n8n secure cookie blocks HTTP access
**Symptom**: n8n shows "Your n8n server is configured to use a secure cookie, however you are either visiting this via an insecure URL."
**Root cause**: n8n defaults to secure cookies (HTTPS only). Our setup uses plain HTTP behind Tailscale.
**Fix applied**: Added `N8N_SECURE_COOKIE: "false"` env var.
**Remaining work**: None — fixed. Document that HTTPS via Caddy/Tailscale would eliminate the need for this.

### 20. LinguaCafe can't reach NLP service — wrong hostname
**Symptom**: Language loading fails with "cURL error 6: Could not resolve host: linguacafe-python-service".
**Root cause**: We named the service `linguacafe-nlp` but LinguaCafe expects the hostname `linguacafe-python-service` (matching the official compose).
**Fix applied**: Renamed service to `linguacafe-python-service`.
**Remaining work**: None — fixed.

### 21. LinguaCafe NLP service needs correct volume and PYTHONPATH
**Symptom**: Even after hostname fix, NLP models weren't accessible.
**Root cause**: Volume was mounted at wrong subpath, missing PYTHONPATH env var.
**Fix applied**: Mount full storage volume, add PYTHONPATH="/var/www/html/storage/app/model".
**Remaining work**: None — fixed.

### 22. LinguaCafe Redis needs SETUID/SETGID capabilities
**Symptom**: `linguacafe-redis` crashes with "failed switching to redis: operation not permitted".
**Root cause**: Same as issue #18 — cap_drop: ALL blocks user switching.
**Fix applied**: Added `cap_add: [SETUID, SETGID]`.
**Remaining work**: None — fixed.

### 23. WAHA dashboard is a paid (Plus) feature
**Symptom**: WAHA dashboard at `/dashboard` returns 401 regardless of credentials.
**Root cause**: The free/community WAHA image doesn't include the dashboard UI. Only API access is available.
**Fix needed**: Document that WhatsApp pairing uses the API (`/api/default/auth/qr`), not a web dashboard. Add a helper script for QR pairing.

### 24. WAHA API requires non-empty API key
**Symptom**: All WAHA API calls return 401 even with `WHATSAPP_API_KEY=""`.
**Root cause**: Newer WAHA versions require a non-empty API key. Empty string doesn't disable auth.
**Fix applied**: Set `WHATSAPP_API_KEY: "asko"`. API calls use `-H 'X-Api-Key: asko'`.
**Remaining work**: Generate a proper random key in setup.sh and store in .env.

### 25. SearXNG Query URL not auto-populated in Open WebUI admin
**Symptom**: Even with `SEARXNG_QUERY_URL` env var set, the admin UI shows no URL. User must manually enter `http://searxng:8080/search?q=<query>`.
**Root cause**: Same as #14 — UI settings may override env vars after first boot.
**Fix needed**: Same as #14 — use API to configure, or document clearly.

### 26. WAHA image tag `2026.2.2` also doesn't exist
**Symptom**: After fixing tag from `2024.12`, `2026.2.2` also fails to pull.
**Root cause**: WAHA's Docker Hub tags don't follow the release version numbers directly.
**Fix applied**: Changed to `devlikeapro/waha:latest`. WAHA is internal-only, behind a profile.
**Remaining work**: Same as #1 — image tag verification.

### 27. IronClaw onboard wizard can't save settings to PostgreSQL
**Symptom**: Wizard completes all 9 steps then fails with "Error: Database error: Failed to save settings to database".
**Root cause**: Database schema/migrations not fully applied, or permissions issue on first run.
**Fix applied**: Used `ironclaw config --no-onboard set` CLI commands to save settings individually. Also granted full PG permissions with `GRANT ALL ON SCHEMA public TO asko`.
**Remaining work**: Document the workaround. Consider filing IronClaw bug report.

### 28. IronClaw won't run as systemd service — exits immediately
**Symptom**: `ironclaw --no-onboard` starts, shows "Agent asko ready and listening", then immediately "Shutdown command received, exiting..."
**Root cause**: Without a TTY (terminal), IronClaw's REPL channel detects no stdin and triggers shutdown. Setting `REPL_ENABLED=false` doesn't prevent this.
**Fix applied**: Must run in an interactive SSH session or tmux. Systemd service doesn't work.
**Remaining work**: File IronClaw bug report. Create a tmux-based systemd wrapper. Or wait for IronClaw to add a `--daemon` flag.

### 29. IronClaw Telegram token stored as `{TELEGRAM_BOT_TOKEN}` placeholder
**Symptom**: Telegram API calls use literal `bot{TELEGRAM_BOT_TOKEN}` in URLs, returning 404.
**Root cause**: WASM Telegram channel reads the token from IronClaw's encrypted secrets store, not from environment variables. The onboard wizard (issue #27) failed to save the token.
**Fix applied**: Re-ran `ironclaw onboard --channels-only` which successfully saved the token to the database.
**Remaining work**: Document that channel tokens MUST be stored via `ironclaw onboard --channels-only`, not env vars alone.

### 30. IronClaw Ollama backend ignores model config
**Symptom**: IronClaw banner shows `model: llama3 via ollama` despite config being set to `qwen2.5:7b`.
**Root cause**: The Ollama backend has a hardcoded default (`llama3`) and the config keys `llm_model`, `selected_model`, `ollama_model` are all different. Only `OLLAMA_MODEL` env var + `export` before running works reliably.
**Fix applied**: Must explicitly `export OLLAMA_MODEL=qwen2.5:7b` before running `ironclaw --no-onboard`.
**Remaining work**: Document this requirement. The config cascade (env > database > defaults) doesn't work properly for the Ollama backend.

### 31. Qwen3 thinking mode makes responses 9+ minutes
**Symptom**: `qwen3:4b` takes 9 minutes to respond to "Say hello" via Ollama.
**Root cause**: Qwen3 models have a "thinking mode" that generates hundreds of internal reasoning tokens before the actual response. The `thinking` field in the response contains chain-of-thought text. `/no_think` in system prompt and Modelfile don't reliably disable it.
**Fix applied**: Switched to `qwen2.5:7b` (no thinking mode).
**Remaining work**: Document that Qwen3 models should NOT be used for CPU inference with agents. Only use Qwen2.5 or non-thinking models.

### 32. IronClaw 24 built-in tools cause 60-150s response times on CPU
**Symptom**: Even with the fastest non-thinking model (qwen2.5:3b, 2s for simple chat), IronClaw responses take 60-150 seconds via Telegram.
**Root cause**: IronClaw sends all 24 built-in tool schemas (~2000+ prompt tokens) with every LLM request. On CPU at ~37 tok/s prompt processing, that's 55+ seconds just for prompt evaluation. Plus retries on failed tool calls.
**Fix needed**: Use a cloud API (Anthropic/OpenAI) for IronClaw's agent reasoning. Keep local models for Open WebUI chat only. This is what production OpenClaw deployments do.

### 33. Docker services don't expose ports to host by default
**Symptom**: IronClaw (running on host) can't reach LiteLLM or PostgreSQL inside Docker.
**Root cause**: No port mappings in docker-compose.yml for internal services. Caddy was the only service with host ports.
**Fix applied**: Added `127.0.0.1:5432:5432` for PostgreSQL, `127.0.0.1:4000:4000` for LiteLLM, `127.0.0.1:11434:11434` for Ollama. All bound to localhost only.
**Remaining work**: Already committed to repo.

### 34. Tailscale Funnel doesn't survive reboots
**Symptom**: After reboot, `tailscale funnel` is not running. IronClaw Telegram webhooks stop working.
**Fix needed**: Create a systemd service for Tailscale Funnel, or use `tailscale funnel --bg` in a startup script.

### 35. Mini PC thermal shutdown under sustained load
**Symptom**: Beelink powers off during heavy inference. Happened twice during deployment.
**Root cause**: Ryzen 7 6800U in a small form factor case gets hot under sustained CPU load (model loading + inference + all Docker services).
**Fix needed**: Monitor thermals. Consider reducing simultaneous service count. Stop LinguaCafe when not in use. Possibly add external cooling.

## Summary: Priority Fixes Before Public Release

### Critical (blocks users)
1. **Verify all image tags exist** — add CI check or `make verify-images` (#1, #15, #26)
2. **Fix Open WebUI first-admin flow** — enable signup initially, disable after creation (#8)
3. **Add retry/resume to setup.sh** — don't force full reset on partial failure (#10)
4. **Fix IronClaw architecture docs** — host install, not Docker; document onboard workarounds (#2, #27, #28, #29, #30)
5. **Document cloud API requirement for IronClaw** — local models too slow with 24 tools on CPU (#32)
6. **Update LiteLLM config** for v1.81+ schema (#11)

### High (significant friction)
7. **Add hardware/network setup guide** — WiFi, keyboard layout, thermal management (#9, #12, #13, #35)
8. **Fix SearXNG auto-configuration** — env vars don't populate admin UI (#14, #25)
9. **Add IronClaw systemd service with tmux** — survives reboots (#28, #34)
10. **Generate proper WAHA API key in setup.sh** (#24)

### Medium (quality of life)
11. **Add port mappings for all services** — n8n, LiteLLM, PostgreSQL, Ollama for host access (#16, #33)
12. **Document WAHA API-only access** — no dashboard in free version (#23)
13. **Document database capability requirements** — MySQL and Redis need SETUID/SETGID (#18, #22)
14. **Update all tests** — many broken by architecture changes (IronClaw removal, new ports, etc.)
15. **Update ARCHITECTURE.md, SECURITY.md, README** — reflect IronClaw on host, actual image tags, real network topology
