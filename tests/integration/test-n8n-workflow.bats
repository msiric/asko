#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "n8n container is running" {
    cd "${ASKO_ROOT}"
    run docker compose ps --status running --format "{{.Name}}" 2>/dev/null
    echo "$output" | grep -q "asko-n8n"
}

@test "n8n health endpoint responds" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T n8n curl -sf http://localhost:5678/healthz
    [[ "$status" -eq 0 ]]
}

@test "n8n can reach litellm" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T n8n curl -sf http://litellm:4000/health
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "n8n cannot reach ollama directly" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T n8n sh -c "curl -sf --connect-timeout 2 http://ollama:11434/api/tags 2>/dev/null || echo 'UNREACHABLE'"
    echo "output: $output"
    echo "$output" | grep -q "UNREACHABLE"
}

@test "waha container is running" {
    cd "${ASKO_ROOT}"
    run docker compose ps --status running --format "{{.Name}}" 2>/dev/null
    echo "$output" | grep -q "asko-waha"
}
