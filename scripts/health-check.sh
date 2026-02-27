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
check "SearXNG" docker compose exec -T searxng wget -q --spider http://localhost:8080/
check "Ollama" docker compose exec -T ollama ollama list
check "LiteLLM" docker compose exec -T litellm python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:4000/health/liveliness')"
check "Open WebUI" docker compose exec -T open-webui curl -sf http://localhost:8080/
check "n8n" docker compose exec -T n8n wget -q -O /dev/null http://127.0.0.1:5678/healthz
check "Caddy" curl -sf -o /dev/null http://localhost:80/

echo ""
echo "Container status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"

[[ "$failed" -eq 0 ]]
