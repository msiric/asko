#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo "=== asko Update ==="
cd "$ASKO_ROOT"

# Step 1: Backup
echo -e "${YELLOW}Step 1: Creating backup before update...${NC}"
"${SCRIPT_DIR}/backup.sh"

# Step 2: Pull new images
echo ""
echo -e "${YELLOW}Step 2: Pulling new images...${NC}"
docker compose pull

# Record new versions
docker compose images --format json > .versions 2>/dev/null || true

# Step 3: Rolling restart (data → inference → agent/automation → UI/proxy)
echo ""
echo -e "${YELLOW}Step 3: Rolling restart...${NC}"

echo "  Restarting data layer (postgres, searxng)..."
docker compose up -d --remove-orphans postgres searxng
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

# Step 4: Health check
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
