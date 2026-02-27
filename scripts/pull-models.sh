#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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
echo -e "${YELLOW}Pulling default model (qwen2.5:7b)...${NC}"
docker compose exec -T ollama ollama pull qwen2.5:7b

echo -e "${YELLOW}Pulling embeddings model (nomic-embed-text)...${NC}"
docker compose exec -T ollama ollama pull nomic-embed-text

# Conditional: larger model if enough RAM
if [[ "$total_ram_gb" -ge 24 ]]; then
    echo ""
    echo -e "${YELLOW}Sufficient RAM detected. Pulling larger model (qwen2.5:14b)...${NC}"
    docker compose exec -T ollama ollama pull qwen2.5:14b
fi

echo ""
echo -e "${GREEN}Models installed:${NC}"
docker compose exec -T ollama ollama list
