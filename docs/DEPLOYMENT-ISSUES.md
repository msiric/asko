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

## Summary: Priority Fixes Before Public Release

1. **Verify all image tags exist** — add CI check or `make verify-images`
2. **Fix Open WebUI first-admin flow** — enable signup initially, disable after creation
3. **Add retry/resume to setup.sh** — don't force full reset on partial failure
4. **Resolve IronClaw architecture** — host install or custom Dockerfile
5. **Update LiteLLM config** for v1.81+ schema
6. **Add hardware/network setup guide** for common mini PCs
