#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
    # Get LiteLLM master key from .env
    if [[ -f "${ASKO_ROOT}/.env" ]]; then
        export LITELLM_MASTER_KEY=$(grep "^LITELLM_MASTER_KEY=" "${ASKO_ROOT}/.env" | cut -d'=' -f2-)
    fi
}

@test "litellm lists available models" {
    cd "${ASKO_ROOT}"
    run curl -sf \
        -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
        http://localhost:4000/v1/models

    echo "output: $output"
    [[ "$status" -eq 0 ]]
    echo "$output" | grep -q "local-default"
}

@test "litellm can reach ollama backend" {
    cd "${ASKO_ROOT}"
    # Query the local-default model with a simple prompt
    run curl -sf \
        -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"model": "local-default", "messages": [{"role": "user", "content": "Say hello in one word"}], "max_tokens": 10}' \
        http://localhost:4000/v1/chat/completions

    echo "output: $output"
    [[ "$status" -eq 0 ]]
    # Response should contain a choices array
    echo "$output" | grep -q "choices"
}

@test "litellm health endpoint shows healthy status" {
    cd "${ASKO_ROOT}"
    run curl -sf http://localhost:4000/health
    echo "output: $output"
    [[ "$status" -eq 0 ]]
}

@test "litellm rejects requests without auth key" {
    cd "${ASKO_ROOT}"
    run curl -sf http://localhost:4000/v1/models
    # Should fail (401 or 403)
    [[ "$status" -ne 0 ]]
}
