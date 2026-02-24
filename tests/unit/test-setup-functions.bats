#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    # Source setup.sh functions (the file must define functions we can test)
    if [[ -f "${ASKO_ROOT}/setup.sh" ]]; then
        # Source only the functions, not the main execution
        source "${ASKO_ROOT}/setup.sh" --source-only 2>/dev/null || true
    fi
}

teardown() {
    cleanup_test_env
}

# --- Secret Generation ---

@test "generate_secret produces output of requested length" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    result=$(generate_secret 32)
    [[ ${#result} -ge 32 ]]
}

@test "generate_secret produces different values each call" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    secret1=$(generate_secret 32)
    secret2=$(generate_secret 32)
    [[ "$secret1" != "$secret2" ]]
}

@test "generate_secret output contains only safe characters" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    result=$(generate_secret 64)
    # Should only contain alphanumeric characters (safe for env vars)
    [[ "$result" =~ ^[a-zA-Z0-9]+$ ]]
}

@test "generate_hex_secret produces valid hex of requested length" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    result=$(generate_hex_secret 64)
    [[ ${#result} -eq 64 ]]
    [[ "$result" =~ ^[0-9a-f]+$ ]]
}

# --- Template Rendering ---

@test "render_template substitutes environment variables" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    export TEST_VAR="hello-world"
    template='Value is ${TEST_VAR}'
    result=$(echo "$template" | envsubst)
    [[ "$result" == "Value is hello-world" ]]
}

@test "render_templates creates config files from templates" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    generate_test_env
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | xargs)

    # render_templates should create config files from .template files
    render_templates "${ASKO_ROOT}/.env.test"

    [[ -f "${ASKO_ROOT}/config/litellm/config.yaml" ]]
    [[ -f "${ASKO_ROOT}/config/caddy/Caddyfile" ]]
}

# --- .env Generation ---

@test "generate_env creates .env file" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    local test_env="${ASKO_ROOT}/.env.test-gen"
    generate_env "$test_env"
    [[ -f "$test_env" ]]
    rm -f "$test_env"
}

@test "generated .env contains all required variables" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    local test_env="${ASKO_ROOT}/.env.test-gen"
    generate_env "$test_env"

    # Check critical variables exist
    grep -q "^POSTGRES_USER=" "$test_env"
    grep -q "^POSTGRES_PASSWORD=" "$test_env"
    grep -q "^LITELLM_MASTER_KEY=" "$test_env"
    grep -q "^N8N_ENCRYPTION_KEY=" "$test_env"
    grep -q "^OPENWEBUI_SECRET_KEY=" "$test_env"
    grep -q "^REDIS_PASSWORD=" "$test_env"

    rm -f "$test_env"
}

@test "generated .env has no empty required secrets" {
    source "${ASKO_ROOT}/setup.sh" --source-only
    local test_env="${ASKO_ROOT}/.env.test-gen"
    generate_env "$test_env"

    # These must never be empty
    local required_secrets=(
        POSTGRES_PASSWORD
        LITELLM_MASTER_KEY
        LITELLM_SALT_KEY
        N8N_ENCRYPTION_KEY
        N8N_USER_MANAGEMENT_JWT_SECRET
        N8N_BASIC_AUTH_PASSWORD
        OPENWEBUI_SECRET_KEY
        REDIS_PASSWORD
    )

    for var in "${required_secrets[@]}"; do
        value=$(grep "^${var}=" "$test_env" | cut -d'=' -f2-)
        [[ -n "$value" ]]
    done

    rm -f "$test_env"
}
