#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "postgres is healthy and accepting connections" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T postgres pg_isready -U asko
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "postgres has pgvector extension available" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T postgres psql -U asko -d asko -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
    echo "output: $output"
    echo "$output" | grep -q "vector"
}

@test "postgres has all required databases" {
    cd "${ASKO_ROOT}"
    for db in asko asko_n8n asko_openwebui; do
        run docker compose exec -T postgres psql -U asko -lqt
        echo "$output" | grep -q "$db"
    done
}

@test "ollama responds on health endpoint" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T caddy wget -q -O - http://ollama:11434/api/tags
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "litellm responds on health endpoint" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T caddy wget -q -O - http://litellm:4000/health
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "open-webui responds on root endpoint" {
    cd "${ASKO_ROOT}"
    run docker compose exec -T caddy wget -q --spider http://open-webui:8080/
    [[ "$status" -eq 0 ]]
}

@test "caddy responds on port 80" {
    cd "${ASKO_ROOT}"
    run curl -sf -o /dev/null -w "%{http_code}" http://localhost:80/
    echo "output: $output"
    # Should get a response (200 or redirect)
    [[ "$output" =~ ^(200|301|302|308)$ ]]
}

@test "all containers show as running" {
    cd "${ASKO_ROOT}"
    # Get container count and running count
    total=$(docker compose ps -q | wc -l)
    running=$(docker compose ps --status running -q | wc -l)

    echo "Total: $total, Running: $running"
    [[ "$total" -eq "$running" ]]
    [[ "$total" -ge 5 ]]  # At least 5 services in Phase 1
}
