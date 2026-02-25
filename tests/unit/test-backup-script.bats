#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "backup.sh exists and is executable" {
    [[ -x "${ASKO_ROOT}/scripts/backup.sh" ]]
}

@test "update.sh exists and is executable" {
    [[ -x "${ASKO_ROOT}/scripts/update.sh" ]]
}

@test "import-workflows.sh exists and is executable" {
    [[ -x "${ASKO_ROOT}/scripts/import-workflows.sh" ]]
}

@test "backup.sh creates a timestamped backup directory" {
    # Check the script uses date-based backup directory
    grep -q 'BACKUP_DIR' "${ASKO_ROOT}/scripts/backup.sh"
    grep -q 'date' "${ASKO_ROOT}/scripts/backup.sh"
    # Verify the dry-run flag exists for testing
    grep -q '\-\-dry-run' "${ASKO_ROOT}/scripts/backup.sh"
}

@test "backup.sh includes database dump commands" {
    grep -q "pg_dump" "${ASKO_ROOT}/scripts/backup.sh"
}

@test "backup.sh includes config backup" {
    grep -q "config" "${ASKO_ROOT}/scripts/backup.sh"
    grep -q "\.env" "${ASKO_ROOT}/scripts/backup.sh"
}

@test "backup.sh includes retention policy" {
    # Should clean up old backups
    grep -q "tail\|rotate\|retain\|older" "${ASKO_ROOT}/scripts/backup.sh"
}

@test "update.sh runs backup before updating" {
    # The update script should call backup first
    grep -q "backup" "${ASKO_ROOT}/scripts/update.sh"
}

@test "update.sh includes health check after update" {
    grep -q "health" "${ASKO_ROOT}/scripts/update.sh"
}

@test "import-workflows.sh imports from workflows/n8n directory" {
    grep -q "workflows/n8n" "${ASKO_ROOT}/scripts/import-workflows.sh"
}
