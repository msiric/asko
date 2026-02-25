#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <backup-directory>"
    echo ""
    echo "Available backups:"
    ls -dt "${ASKO_ROOT}/backups"/*/ 2>/dev/null | head -10 || echo "  (none)"
    exit 1
fi

BACKUP_DIR="$1"
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Backup directory not found: ${BACKUP_DIR}${NC}"
    exit 1
fi

echo "=== asko Restore ==="
echo -e "${YELLOW}Restoring from: ${BACKUP_DIR}${NC}"
echo ""
read -rp "This will overwrite current data. Are you sure? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

cd "$ASKO_ROOT"

# Restore .env
if [[ -f "${BACKUP_DIR}/.env" ]]; then
    echo -e "${YELLOW}Restoring .env...${NC}"
    cp "${BACKUP_DIR}/.env" "${ASKO_ROOT}/.env"
    chmod 600 "${ASKO_ROOT}/.env"
fi

# Restore configs
if [[ -d "${BACKUP_DIR}/config" ]]; then
    echo -e "${YELLOW}Restoring configs...${NC}"
    cp -r "${BACKUP_DIR}/config/"* "${ASKO_ROOT}/config/" 2>/dev/null || true
fi

# Restore databases
echo -e "${YELLOW}Restoring databases...${NC}"
for dump in "${BACKUP_DIR}"/*.sql.gz; do
    [[ -f "$dump" ]] || continue
    db=$(basename "$dump" .sql.gz)
    echo -n "  ${db}... "
    gunzip -c "$dump" | docker compose exec -T postgres psql -U asko "$db" > /dev/null 2>&1 \
        && echo -e "${GREEN}OK${NC}" \
        || echo -e "${RED}FAIL${NC}"
done

echo ""
echo -e "${GREEN}Restore complete.${NC}"
echo "Restart services: docker compose restart"
