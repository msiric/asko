#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKFLOW_DIR="${ASKO_ROOT}/workflows/n8n"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Import n8n Workflows ==="

# Load credentials from .env
if [[ -f "${ASKO_ROOT}/.env" ]]; then
    N8N_USER=$(grep "^N8N_BASIC_AUTH_USER=" "${ASKO_ROOT}/.env" | cut -d'=' -f2-)
    N8N_PASS=$(grep "^N8N_BASIC_AUTH_PASSWORD=" "${ASKO_ROOT}/.env" | cut -d'=' -f2-)
else
    echo -e "${RED}No .env file found. Run setup.sh first.${NC}"
    exit 1
fi

N8N_URL="http://localhost:5678"

# Wait for n8n to be ready
echo -e "${YELLOW}Waiting for n8n to be ready...${NC}"
for i in $(seq 1 30); do
    if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
    echo -e "${RED}n8n is not responding. Is the stack running?${NC}"
    exit 1
fi

# Import each workflow
imported=0
failed=0
for workflow in "${WORKFLOW_DIR}"/*.json; do
    [[ -f "$workflow" ]] || continue
    name=$(basename "$workflow" .json)

    echo -n "  Importing ${name}... "
    if curl -sf -X POST "${N8N_URL}/api/v1/workflows" \
        -H "Content-Type: application/json" \
        -u "${N8N_USER}:${N8N_PASS}" \
        -d @"$workflow" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        imported=$((imported + 1))
    else
        echo -e "${RED}FAIL${NC}"
        failed=$((failed + 1))
    fi
done

echo ""
echo -e "Imported: ${GREEN}${imported}${NC}, Failed: ${RED}${failed}${NC}"
