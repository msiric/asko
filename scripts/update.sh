#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== asko Update ==="
cd "$ASKO_ROOT"

# 1. Backup first
echo -e "${YELLOW}Step 1: Creating backup before update...${NC}"
"${SCRIPT_DIR}/backup.sh"

# 2. Pull new images
echo ""
echo -e "${YELLOW}Step 2: Pulling new images...${NC}"
docker compose pull

# 3. Record new versions
docker compose images --format json > .versions 2>/dev/null || true

# 4. Rolling restart (data layer first, then inference, then apps)
echo ""
echo -e "${YELLOW}Step 3: Rolling restart...${NC}"

echo "  Restarting data layer (postgres, redis)..."
docker compose up -d --remove-orphans postgres redis
sleep 5

echo "  Restarting inference layer (ollama, litellm)..."
docker compose up -d --remove-orphans ollama litellm
sleep 5

echo "  Restarting agent + automation layer (ironclaw, n8n, waha)..."
docker compose up -d --remove-orphans ironclaw n8n waha
sleep 5

echo "  Restarting UI + proxy layer (open-webui, caddy)..."
docker compose up -d --remove-orphans open-webui caddy
sleep 5

# 5. Health check
echo ""
echo -e "${YELLOW}Step 4: Running health checks...${NC}"
"${SCRIPT_DIR}/health-check.sh" && {
    echo ""
    echo -e "${GREEN}=== Update complete ===${NC}"
} || {
    echo ""
    echo -e "${RED}=== Update completed with health check warnings ===${NC}"
    echo "Check: docker compose ps"
    echo "Restore from backup if needed: ${ASKO_ROOT}/backups/"
}
