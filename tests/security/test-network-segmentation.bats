#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "n8n cannot resolve ollama directly" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T n8n sh -c "getent hosts ollama 2>/dev/null || echo 'UNRESOLVABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNRESOLVABLE"
}

@test "caddy cannot reach postgres" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T caddy sh -c "wget -q --spider --timeout=2 http://postgres:5432/ 2>&1 || echo 'UNREACHABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNREACHABLE"
}
