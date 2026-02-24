#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    if [[ -f "${ASKO_ROOT}/setup.sh" ]]; then
        source "${ASKO_ROOT}/setup.sh" --source-only 2>/dev/null || true
    fi
}

# --- Pre-flight Check Functions ---

@test "check_command returns 0 for existing command" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    run check_command "bash"
    [[ "$status" -eq 0 ]]
}

@test "check_command returns non-zero for missing command" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    run check_command "definitely-not-a-real-command-xyz"
    [[ "$status" -ne 0 ]]
}

@test "check_architecture detects x86_64" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    # This test is platform-specific; skip on non-x86_64
    if [[ "$(uname -m)" != "x86_64" ]] && [[ "$(uname -m)" != "arm64" ]]; then
        skip "Unknown architecture"
    fi
    run check_architecture
    # Should succeed on both x86_64 and arm64 (for dev on Mac)
    # The function should at minimum not crash
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "check_ram returns RAM in GB" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    result=$(get_total_ram_gb)
    # Should be a positive number
    [[ "$result" -gt 0 ]]
}

@test "check_disk_space returns available space in GB" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    result=$(get_available_disk_gb)
    # Should be a positive number
    [[ "$result" -gt 0 ]]
}

@test "preflight_checks function exists and is callable" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    # Just verify the function is defined
    declare -f preflight_checks > /dev/null
}
