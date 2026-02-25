#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Pull Ollama Models ==="
cd "$ASKO_ROOT"

# Detect available RAM
if [[ "$(uname)" == "Darwin" ]]; then
    total_ram_gb=$(sysctl -n hw.memsize | awk '{printf "%d", $1/1073741824}')
else
    total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
fi

echo "Detected RAM: ${total_ram_gb}GB"
echo ""

# Always pull: default model + embeddings
echo -e "${YELLOW}Pulling default model (phi3:3.8b)...${NC}"
docker compose exec -T ollama ollama pull phi3:3.8b

echo -e "${YELLOW}Pulling embeddings model (nomic-embed-text)...${NC}"
docker compose exec -T ollama ollama pull nomic-embed-text

# Conditional: larger model if enough RAM
if [[ "$total_ram_gb" -ge 24 ]]; then
    echo ""
    echo -e "${YELLOW}Sufficient RAM detected. Pulling larger model (llama3.1:8b)...${NC}"
    docker compose exec -T ollama ollama pull llama3.1:8b
fi

echo ""
echo -e "${GREEN}Models installed:${NC}"
docker compose exec -T ollama ollama list
