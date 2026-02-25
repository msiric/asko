#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env

BACKUP_DIR="${ASKO_ROOT}/backups/$(date +%Y%m%d_%H%M%S)"

# Allow dry-run for testing
if [[ "${1:-}" == "--dry-run" ]]; then
    echo "BACKUP_DIR=${BACKUP_DIR}"
    exit 0
fi

echo "=== asko Backup ==="
mkdir -p "$BACKUP_DIR"

cd "$ASKO_ROOT"

# Dump each PostgreSQL database
echo -e "${YELLOW}Dumping databases...${NC}"
for db in asko asko_ironclaw asko_n8n asko_openwebui asko_litellm; do
    docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-asko}" "$db" 2>/dev/null \
        | gzip > "${BACKUP_DIR}/${db}.sql.gz" \
        && echo "  ${db}: OK" \
        || echo "  ${db}: SKIP (may not exist yet)"
done

# Copy config and .env
echo -e "${YELLOW}Backing up configs...${NC}"
cp "${ASKO_ROOT}/.env" "${BACKUP_DIR}/.env" 2>/dev/null || true
cp -r "${ASKO_ROOT}/config/" "${BACKUP_DIR}/config/" 2>/dev/null || true

# Record current image versions
docker compose images --format json > "${BACKUP_DIR}/images.json" 2>/dev/null || true

# Export n8n workflows (pipe to host since container can't write to host paths)
echo -e "${YELLOW}Exporting n8n workflows...${NC}"
mkdir -p "${BACKUP_DIR}/n8n-workflows"
docker compose exec -T n8n n8n export:workflow --all --output=/dev/stdout 2>/dev/null \
    > "${BACKUP_DIR}/n8n-workflows/all-workflows.json" \
    || echo "  n8n export: SKIP (n8n may not be running)"

echo ""
echo -e "${GREEN}Backup complete: ${BACKUP_DIR}${NC}"
echo "Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'unknown')"

# Retain only last 7 backups (older ones are removed)
echo ""
echo -e "${YELLOW}Cleaning older backups (retaining last 7)...${NC}"
ls -dt "${ASKO_ROOT}/backups"/*/ 2>/dev/null | tail -n +8 | xargs rm -rf 2>/dev/null || true
echo "Done"
