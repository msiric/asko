#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    generate_test_env
    # Docker compose needs .env, create a symlink for testing
    cp "${ASKO_ROOT}/.env.test" "${ASKO_ROOT}/.env"
}

teardown() {
    cleanup_test_env
    rm -f "${ASKO_ROOT}/.env"
}

@test "docker-compose.yml exists" {
    [[ -f "${ASKO_ROOT}/docker-compose.yml" ]]
}

@test "docker compose config validates successfully" {
    cd "${ASKO_ROOT}"
    run docker compose config --quiet
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "all Phase 1 services are defined" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    echo "$config" | grep -q "asko-ollama"
    echo "$config" | grep -q "asko-litellm"
    echo "$config" | grep -q "asko-openwebui"
    echo "$config" | grep -q "asko-postgres"
    echo "$config" | grep -q "asko-caddy"
}

@test "all services have restart policy" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    # Every service should have restart: unless-stopped
    services=$(echo "$config" | grep -c "restart:")
    # At least 5 services in Phase 1
    [[ "$services" -ge 5 ]]
}
