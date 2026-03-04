#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh" || exit 1
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
for db in asko asko_n8n asko_openwebui; do
    dump_file="${BACKUP_DIR}/${db}.sql.gz"

    # Use pipefail to catch pg_dump failures (exit code lost in pipe otherwise)
    if (set -o pipefail; docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-asko}" "$db" 2>/dev/null | gzip > "$dump_file"); then
        # Verify dump is not empty
        file_size="$(stat -f%z "$dump_file" 2>/dev/null || stat -c%s "$dump_file" 2>/dev/null || echo 0)"
        if [[ "$file_size" -gt 100 ]]; then
            echo "  ${db}: OK"
        else
            echo "  ${db}: SKIP (empty — database may not exist yet)"
            rm -f "$dump_file"
        fi
    else
        echo "  ${db}: SKIP (pg_dump failed — database may not exist yet)"
        rm -f "$dump_file"
    fi
done

# Copy config and .env
echo -e "${YELLOW}Backing up configs...${NC}"
cp "${ASKO_ROOT}/.env" "${BACKUP_DIR}/.env" 2>/dev/null || true
cp -r "${ASKO_ROOT}/config/" "${BACKUP_DIR}/config/" 2>/dev/null || true

# Record current image versions
docker compose images --format json > "${BACKUP_DIR}/images.json" 2>/dev/null || true

# Export n8n workflows
echo -e "${YELLOW}Exporting n8n workflows...${NC}"
mkdir -p "${BACKUP_DIR}/n8n-workflows"
docker compose exec -T n8n n8n export:workflow --all --output=/dev/stdout 2>/dev/null \
    > "${BACKUP_DIR}/n8n-workflows/all-workflows.json" \
    || echo "  n8n export: SKIP (n8n may not be running)"

echo ""
echo -e "${GREEN}Backup complete: ${BACKUP_DIR}${NC}"
echo "Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'unknown')"

# Retain only last 7 backups
echo ""
echo -e "${YELLOW}Cleaning older backups (retaining last 7)...${NC}"
mapfile -t old_backups < <(ls -dt "${ASKO_ROOT}/backups"/*/ 2>/dev/null | tail -n +8)
for dir in "${old_backups[@]}"; do
    [[ -n "$dir" ]] && [[ "$dir" == "${ASKO_ROOT}/backups/"* ]] && rm -rf "$dir"
done
echo "Done"
