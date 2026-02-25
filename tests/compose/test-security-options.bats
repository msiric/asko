#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    generate_test_env
    cp "${ASKO_ROOT}/.env.test" "${ASKO_ROOT}/.env"
}

teardown() {
    cleanup_test_env
    rm -f "${ASKO_ROOT}/.env"
}

@test "all services have security_opt: no-new-privileges" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    # Count services (lines with 'container_name: asko-')
    service_count=$(echo "$config" | grep -c "container_name: asko-")
    # Count no-new-privileges occurrences
    nnp_count=$(echo "$config" | grep -c "no-new-privileges")

    echo "services: $service_count, no-new-privileges: $nnp_count"
    [[ "$nnp_count" -ge "$service_count" ]]
}

@test "all services have cap_drop: ALL" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    # Every service should drop all capabilities
    service_count=$(echo "$config" | grep -c "container_name: asko-")
    cap_drop_count=$(echo "$config" | grep -c "cap_drop:")

    [[ "$cap_drop_count" -ge "$service_count" ]]
}

@test "all services have resource limits" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    service_count=$(echo "$config" | grep -c "container_name: asko-")
    # Each service should have a memory limit under deploy.resources.limits
    limit_count=$(echo "$config" | grep -c "memory:")

    # At least one memory limit per service (limits + reservations = 2x)
    [[ "$limit_count" -ge "$service_count" ]]
}

@test "all services have healthchecks" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)

    service_count=$(echo "$config" | grep -c "container_name: asko-")
    healthcheck_count=$(echo "$config" | grep -c "healthcheck:")

    echo "services: $service_count, healthchecks: $healthcheck_count"
    [[ "$healthcheck_count" -ge "$service_count" ]]
}

@test "caddy has NET_BIND_SERVICE capability" {
    cd "${ASKO_ROOT}"
    # Check the compose file directly (config output format varies)
    grep -q "NET_BIND_SERVICE" "${ASKO_ROOT}/docker-compose.yml"
}

@test "caddy is read-only" {
    cd "${ASKO_ROOT}"
    # Check within the caddy service block in the compose file
    python3 -c "
import yaml, sys
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
caddy = config.get('services', {}).get('caddy', {})
assert caddy.get('read_only') == True, f'caddy read_only is {caddy.get(\"read_only\")}'
" 2>/dev/null || {
        # Fallback: grep-based check
        grep -A 40 "container_name: asko-caddy" "${ASKO_ROOT}/docker-compose.yml" | grep -q "read_only: true"
    }
}

@test "no unused services provisioned" {
    cd "${ASKO_ROOT}"
    # Redis was removed (YAGNI — no service connected to it)
    ! grep -q "asko-redis" "${ASKO_ROOT}/docker-compose.yml"
}
