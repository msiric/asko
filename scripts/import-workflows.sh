#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

WORKFLOW_DIR="${ASKO_ROOT}/workflows/n8n"

echo "=== Import n8n Workflows ==="
cd "$ASKO_ROOT"

# Wait for n8n to be ready
echo -e "${YELLOW}Waiting for n8n to be ready...${NC}"
for _ in $(seq 1 30); do
    if docker compose exec -T n8n curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! docker compose exec -T n8n curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
    echo -e "${RED}n8n is not responding. Is the stack running?${NC}"
    exit 1
fi

# Import each workflow via n8n CLI inside the container
imported=0
failed=0
for workflow in "${WORKFLOW_DIR}"/*.json; do
    [[ -f "$workflow" ]] || continue
    name=$(basename "$workflow" .json)

    echo -n "  Importing ${name}... "
    if docker compose exec -T n8n n8n import:workflow --input=/dev/stdin < "$workflow" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        imported=$((imported + 1))
    else
        echo -e "${RED}FAIL${NC}"
        failed=$((failed + 1))
    fi
done

echo ""
echo -e "Imported: ${GREEN}${imported}${NC}, Failed: ${RED}${failed}${NC}"
