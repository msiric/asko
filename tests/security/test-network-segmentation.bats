#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "ironclaw cannot ping postgres" {
    cd "${ASKO_ROOT}"
    # Try to resolve postgres from ironclaw's container - should fail
    run docker compose exec -T ironclaw sh -c "getent hosts postgres 2>/dev/null || echo 'UNRESOLVABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNRESOLVABLE"
}

@test "ironclaw cannot ping ollama" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T ironclaw sh -c "getent hosts ollama 2>/dev/null || echo 'UNRESOLVABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNRESOLVABLE"
}

@test "ironclaw can resolve litellm" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T ironclaw sh -c "getent hosts litellm 2>/dev/null || echo 'UNRESOLVABLE'"
    echo "output: $output"
    ! echo "$output" | grep -q "UNRESOLVABLE"
}

@test "caddy cannot reach postgres" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T caddy sh -c "wget -q --spider --timeout=2 http://postgres:5432/ 2>&1 || echo 'UNREACHABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNREACHABLE"
}
