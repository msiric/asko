#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

passed=0
failed=0

check() {
    local name="$1"
    shift
    if "$@" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC}   ${name}"
        passed=$((passed + 1))
    else
        echo -e "${RED}[FAIL]${NC} ${name}"
        failed=$((failed + 1))
    fi
}

echo "=== asko Health Check ==="
echo ""

cd "$ASKO_ROOT"

# PostgreSQL
check "PostgreSQL" docker compose exec -T postgres pg_isready -U asko

# Redis
check "Redis" docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD:-}" ping

# Ollama
check "Ollama" docker compose exec -T ollama curl -sf http://localhost:11434/api/tags

# LiteLLM
check "LiteLLM" docker compose exec -T litellm curl -sf http://localhost:4000/health

# Open WebUI
check "Open WebUI" docker compose exec -T open-webui curl -sf http://localhost:8080/

# Caddy
check "Caddy" curl -sf -o /dev/null http://localhost:80/

echo ""
echo "Container status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"

[[ "$failed" -eq 0 ]]
