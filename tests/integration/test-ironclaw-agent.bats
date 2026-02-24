#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "ironclaw container is running" {
    cd "${ASKO_ROOT}"
    run docker compose ps --status running --format "{{.Name}}" 2>/dev/null
    echo "$output" | grep -q "asko-ironclaw"
}

@test "ironclaw web gateway responds" {
    cd "${ASKO_ROOT}"
    # IronClaw exposes port 3000 for its web gateway
    run docker compose exec -T caddy wget -q --spider --timeout=5 http://ironclaw:3000/ 2>&1
    # Accept any response (200, 401, etc) — just verify the gateway is listening
    [[ "$status" -eq 0 ]] || {
        # Fallback: check if the port is open at all
        run docker compose exec -T ironclaw sh -c "curl -sf http://localhost:3000/ > /dev/null 2>&1 || curl -sf http://localhost:3000/api/health > /dev/null 2>&1"
        [[ "$status" -eq 0 ]]
    }
}

@test "ironclaw health endpoint responds" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T ironclaw sh -c "curl -sf http://localhost:3000/api/health 2>/dev/null || curl -sf http://localhost:3000/api/gateway/status 2>/dev/null || echo 'NO_HEALTH'"
    echo "output: $output"
    ! echo "$output" | grep -q "NO_HEALTH"
}

@test "ironclaw can reach litellm for inference" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T ironclaw sh -c "curl -sf http://litellm:4000/health"
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}
