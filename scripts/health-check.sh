#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env

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

check "PostgreSQL" docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-asko}"
check "Redis" docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD:-}" ping
check "Ollama" docker compose exec -T ollama curl -sf http://localhost:11434/api/tags
check "LiteLLM" docker compose exec -T litellm curl -sf http://localhost:4000/health
check "Open WebUI" docker compose exec -T open-webui curl -sf http://localhost:8080/
check "IronClaw" docker compose exec -T ironclaw curl -sf http://localhost:3000/api/health
check "n8n" docker compose exec -T n8n curl -sf http://localhost:5678/healthz
check "Caddy" curl -sf -o /dev/null http://localhost:80/

echo ""
echo "Container status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"

[[ "$failed" -eq 0 ]]
