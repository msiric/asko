#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env

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
read -rp "This will stop services and overwrite current data. Are you sure? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

cd "$ASKO_ROOT"

# Restore .env first (needed for credentials)
if [[ -f "${BACKUP_DIR}/.env" ]]; then
    echo -e "${YELLOW}Restoring .env...${NC}"
    cp "${BACKUP_DIR}/.env" "${ASKO_ROOT}/.env"
    chmod 600 "${ASKO_ROOT}/.env"
    load_env
fi

# Restore configs
if [[ -d "${BACKUP_DIR}/config" ]]; then
    echo -e "${YELLOW}Restoring configs...${NC}"
    cp -r "${BACKUP_DIR}/config/"* "${ASKO_ROOT}/config/" 2>/dev/null || true
fi

# Stop application services before database restore (postgres stays running)
echo -e "${YELLOW}Stopping application services...${NC}"
docker compose stop open-webui n8n litellm searxng caddy 2>/dev/null || true

# Restore databases (drop and recreate to avoid conflicts)
echo -e "${YELLOW}Restoring databases...${NC}"
restore_failed=0
for dump in "${BACKUP_DIR}"/*.sql.gz; do
    [[ -f "$dump" ]] || continue
    db=$(basename "$dump" .sql.gz)
    echo -n "  ${db}... "

    # Verify backup integrity before restoring
    if ! gunzip -t "$dump" > /dev/null 2>&1; then
        echo -e "${RED}FAIL (corrupt backup file)${NC}"
        restore_failed=$((restore_failed + 1))
        continue
    fi

    # Drop and recreate the database, then restore
    if ! docker compose exec -T postgres dropdb -U "${POSTGRES_USER:-asko}" --if-exists "$db" 2>&1; then
        echo -e "${RED}FAIL (dropdb error)${NC}"
        restore_failed=$((restore_failed + 1))
        continue
    fi
    if ! docker compose exec -T postgres createdb -U "${POSTGRES_USER:-asko}" "$db" 2>&1; then
        echo -e "${RED}FAIL (createdb error)${NC}"
        restore_failed=$((restore_failed + 1))
        continue
    fi
    if gunzip -c "$dump" | docker compose exec -T postgres psql -U "${POSTGRES_USER:-asko}" "$db" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL (restore error)${NC}"
        restore_failed=$((restore_failed + 1))
    fi
done

if [[ "$restore_failed" -gt 0 ]]; then
    echo ""
    echo -e "${RED}${restore_failed} database(s) failed to restore. Services NOT restarted.${NC}"
    echo "Fix the issue and run: docker compose up -d"
    exit 1
fi

# Restart all services
echo -e "${YELLOW}Restarting services...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}Restore complete.${NC}"
