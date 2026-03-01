# Miles Setup Guide

**Miles** (Memory-Integrated Language Engine with Search) is a personal AI assistant running on OpenClaw, deployed alongside the asko Docker stack.

This guide covers setting up Miles on a fresh machine or restoring from backup.

## Prerequisites

- Ubuntu Server 24.04 (or similar Linux)
- Docker + Docker Compose installed
- Tailscale connected to your tailnet
- Anthropic API key
- Telegram bot token (create via @BotFather)
- 16+ GB RAM, 50+ GB disk

## Part 1: asko Docker Stack (~10 min)

```bash
git clone https://github.com/msiric/asko.git
cd asko
./setup.sh
```

This sets up: PostgreSQL, Ollama, LiteLLM, SearXNG, Open WebUI, n8n, Caddy.

Verify: `make health` — all 7 services should be healthy.

## Part 2: OpenClaw (Miles) (~15 min)

### Build and configure

```bash
cd ~
git clone https://github.com/openclaw/openclaw.git
cd openclaw
docker build -t openclaw:local -f Dockerfile .
```

### Create .env

```bash
cat > .env << 'EOF'
OPENCLAW_CONFIG_DIR=/home/$USER/.openclaw
OPENCLAW_WORKSPACE_DIR=/home/$USER/.openclaw/workspace
ANTHROPIC_API_KEY=<your-anthropic-key>
BRAVE_API_KEY=<your-brave-search-key>
SERPAPI_KEY=<your-serpapi-key>
GOG_KEYRING_PASSWORD=<generate-random>
GH_CONFIG_DIR=/home/node/.openclaw/gh-config
OPENCLAW_GATEWAY_BIND=loopback
EOF
chmod 600 .env
```

### Add project name to docker-compose.yml

Add `name: miles` as the first line of `docker-compose.yml`.

### Add volume mounts to docker-compose.yml

Under the gateway service volumes, add:
```yaml
      - /home/$USER/.gogcli:/home/node/.config/gogcli
      - /home/$USER/obsidian-vault:/home/node/obsidian-vault
```

Add environment variables:
```yaml
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      BRAVE_API_KEY: ${BRAVE_API_KEY}
      SERPAPI_KEY: ${SERPAPI_KEY}
      GOG_KEYRING_PASSWORD: ${GOG_KEYRING_PASSWORD}
      GH_CONFIG_DIR: /home/node/.openclaw/gh-config
      PATH: /home/node/.local/bin:/home/node/.openclaw:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Bind ports to localhost:
```yaml
    ports:
      - "127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}:18789"
      - "127.0.0.1:${OPENCLAW_BRIDGE_PORT:-18790}:18790"
```

### Create OpenClaw config

```bash
mkdir -p ~/.openclaw
```

Start the gateway:
```bash
docker compose up -d openclaw-gateway
```

### Configure via Telegram

1. Message your bot on Telegram
2. Approve your pairing code:
   ```bash
   docker compose run --rm openclaw-cli pairing approve telegram <CODE>
   ```
3. Tell Miles your name, preferences, and identity

### Install CLI tools in the container

```bash
# gog (Google Calendar/Gmail)
docker exec miles-openclaw-gateway-1 sh -c \
  "curl -fsSL -o /tmp/gog.tar.gz https://github.com/steipete/gogcli/releases/latest/download/gogcli_*_linux_amd64.tar.gz && \
   cd /tmp && tar xzf gog.tar.gz && cp gog /home/node/.openclaw/gog && chmod +x /home/node/.openclaw/gog"

# gh (GitHub CLI)
docker exec miles-openclaw-gateway-1 sh -c \
  "curl -fsSL https://github.com/cli/cli/releases/latest/download/gh_*_linux_amd64.tar.gz | \
   tar xz -C /tmp/ && cp /tmp/gh_*/bin/gh /home/node/.openclaw/gh && chmod +x /home/node/.openclaw/gh"

# Create bin directory and symlinks
docker exec miles-openclaw-gateway-1 sh -c \
  "mkdir -p /home/node/.local/bin && \
   ln -sf /home/node/.openclaw/gog /home/node/.local/bin/gog && \
   ln -sf /home/node/.openclaw/gh /home/node/.local/bin/gh"
```

### Authenticate CLI tools

```bash
# Google Calendar/Gmail (interactive — opens browser for OAuth)
docker exec -it miles-openclaw-gateway-1 sh -c \
  "PATH=/home/node/.openclaw:\$PATH GOG_KEYRING_PASSWORD=<password> \
   gog auth credentials set /path/to/google-credentials.json && \
   gog auth add your@gmail.com --services calendar,gmail --manual --force-consent"

# GitHub
docker exec miles-openclaw-gateway-1 sh -c \
  "mkdir -p /home/node/.openclaw/gh-config && \
   echo <github-pat> | GH_CONFIG_DIR=/home/node/.openclaw/gh-config /home/node/.openclaw/gh auth login --with-token"
```

## Part 3: CouchDB for Obsidian LiveSync (~5 min)

```bash
mkdir -p ~/couchdb
cat > ~/couchdb/.env << 'EOF'
COUCHDB_USER=<username>
COUCHDB_PASSWORD=<generate-random>
EOF
chmod 600 ~/couchdb/.env
```

Create `~/couchdb/docker-compose.yml` (see docs/couchdb-compose.yml for template).

```bash
cd ~/couchdb
docker compose up -d

# Initialize for LiveSync
curl -s https://raw.githubusercontent.com/vrtmrz/obsidian-livesync/main/utils/couchdb/couchdb-init.sh | \
  hostname=http://localhost:5984 username=<user> password=<pass> bash
```

## Part 4: Obsidian Vault (~5 min)

```bash
mkdir -p ~/obsidian-vault/{Daily,Projects,Work,Personal,Ideas,People,Recipes,Travel,Resources,Templates,Inbox,Archive}
```

## Part 5: Tailscale Serve (~2 min)

```bash
# HTTPS for services (tailnet only)
sudo tailscale serve --bg --https 8443 http://localhost:80     # Open WebUI
sudo tailscale serve --bg --https 5679 http://localhost:5678   # n8n
sudo tailscale serve --bg --https 5984 http://localhost:5984   # CouchDB
sudo tailscale serve --bg --https 8384 http://localhost:8384   # Syncthing

# Funnel for Telegram webhooks (public)
sudo tailscale funnel --bg 8080                                # OpenClaw webhooks
```

## Part 6: Syncthing (~5 min)

```bash
sudo apt install syncthing
systemctl --user enable --now syncthing
```

Pair with your Mac via `https://<tailscale-hostname>:8384`.

## Part 7: Scripts and Cron (~5 min)

### Deploy scripts

Copy from backup or create:
- `~/.openclaw/scripts/reminder-check.py`
- `~/.openclaw/scripts/sync-reminders.sh`
- `~/.openclaw/scripts/health-monitor.sh`
- `~/.openclaw/scripts/backup-openclaw.sh`
- `~/.openclaw/flight-deal-tracker.py`

### Create secrets file

```bash
cat > ~/.secrets.env << 'EOF'
export TELEGRAM_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<your-telegram-id>"
export SERPAPI_KEY="<serpapi-key>"
EOF
chmod 600 ~/.secrets.env
```

### Set up crontab

```bash
crontab -e
# Add:
# asko Docker stack backup
0 3 * * * /home/$USER/asko/scripts/backup.sh >> /home/$USER/asko/logs/backup.log 2>&1

# Miles full backup
15 3 * * * /home/$USER/.openclaw/scripts/backup-openclaw.sh >> /home/$USER/.openclaw/backup.log 2>&1

# Flight deal tracker
0 8 */2 * * . /home/$USER/.secrets.env && docker exec -e SERPAPI_KEY=$SERPAPI_KEY -e TELEGRAM_TOKEN=$TELEGRAM_TOKEN -e TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID miles-openclaw-gateway-1 /home/node/.openclaw/venv/bin/python3 /home/node/.openclaw/flight-deal-tracker.py >> /home/$USER/.openclaw/flight-tracker.log 2>&1

# Reminder checker (every 5 min)
*/5 * * * * . /home/$USER/.secrets.env && TZ=Europe/Prague TELEGRAM_TOKEN=$TELEGRAM_TOKEN TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID /usr/bin/python3 /home/$USER/.openclaw/scripts/reminder-check.py >> /home/$USER/.reminder-check.log 2>&1

# Reminder sync (every 5 min)
*/5 * * * * /home/$USER/.openclaw/scripts/sync-reminders.sh

# Health monitoring (every 15 min)
*/15 * * * * /home/$USER/.openclaw/scripts/health-monitor.sh >> /home/$USER/.health-monitor.log 2>&1

# Log rotation (monthly)
0 0 1 * * truncate -s 0 /home/$USER/.reminder-check.log /home/$USER/.openclaw/flight-tracker.log /home/$USER/.openclaw/backup.log /home/$USER/.health-monitor.log 2>/dev/null
```

## Part 8: Multi-Agent Setup (optional)

Configure in `~/.openclaw/openclaw.json`:
- `agents.list` — define agents per family member
- `bindings` — route by Telegram sender ID
- `session.dmScope` — per-channel-peer for isolation

Create workspace directories per person with SOUL.md files.

See `memory/implementation-plan.md` for detailed multi-agent config.

## Restoring from Backup

1. Follow Parts 1-6 above (infrastructure)
2. Copy backup contents:
   ```bash
   BACKUP=~/.openclaw/backups/<timestamp>
   cp $BACKUP/openclaw.json ~/.openclaw/
   cp $BACKUP/jobs.json ~/.openclaw/cron/
   cp -r $BACKUP/scripts ~/.openclaw/
   cp -r $BACKUP/workspace-* ~/.openclaw/
   cp $BACKUP/openclaw-docker.env ~/openclaw/.env
   cp $BACKUP/secrets.env ~/.secrets.env
   cp -r $BACKUP/couchdb ~/couchdb/
   crontab $BACKUP/crontab.txt
   ```
3. Restart all services
4. Verify via `make health` and Telegram

## Quick Reference

| Service | HTTP (LAN) | HTTPS (Tailscale) |
|---------|------------|-------------------|
| Open WebUI | http://IP:80 | https://hostname:8443 |
| n8n | http://IP:5678 | https://hostname:5679 |
| CouchDB | localhost:5984 | https://hostname:5984 |
| Syncthing | localhost:8384 | https://hostname:8384 |
| Miles webhooks | — | https://hostname (Funnel) |
