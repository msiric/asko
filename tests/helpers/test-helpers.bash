#!/usr/bin/env bash
# Shared test helpers for asko BATS tests

# Project root (two levels up from helpers/)
export ASKO_ROOT
ASKO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Generate a test .env file with dummy values
generate_test_env() {
    local env_file="${1:-${ASKO_ROOT}/.env.test}"
    cat > "$env_file" <<'EOF'
POSTGRES_USER=asko
POSTGRES_PASSWORD=test-password-64chars-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
POSTGRES_DB=asko
DATABASE_URL=postgresql://asko:test-password@postgres:5432/asko
IRONCLAW_DATABASE_URL=postgresql://asko:test-password@postgres:5432/asko_ironclaw
N8N_DATABASE_URL=postgresql://asko:test-password@postgres:5432/asko_n8n
OPENWEBUI_DATABASE_URL=postgresql://asko:test-password@postgres:5432/asko_openwebui
LITELLM_MASTER_KEY=sk-asko-test-key-48chars-aaaaaaaaaaaaaaaaaaaaa
LITELLM_SALT_KEY=test-salt-32chars-aaaaaaaaaaaaaa
IRONCLAW_SECRETS_MASTER_KEY=test-hex-64chars-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
IRONCLAW_LLM_BACKEND=openai_compatible
IRONCLAW_LLM_BASE_URL=http://litellm:4000/v1
IRONCLAW_LLM_API_KEY=sk-asko-test-key-48chars-aaaaaaaaaaaaaaaaaaaaa
IRONCLAW_LLM_MODEL=local-default
IRONCLAW_TELEGRAM_BOT_TOKEN=
IRONCLAW_TELEGRAM_WEBHOOK_SECRET=test-webhook-secret-32chars-aaaa
N8N_ENCRYPTION_KEY=test-encryption-key-32chars-aaaa
N8N_USER_MANAGEMENT_JWT_SECRET=test-jwt-secret-64chars-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=test-auth-password-32chars-aaaaa
OPENWEBUI_SECRET_KEY=test-webui-secret-48chars-aaaaaaaaaaaaaaaaaaaaaaa
REDIS_PASSWORD=test-redis-password-32chars-aaaaa
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
DOMAIN_BASE=asko.local
EOF
}

# Clean up test .env
cleanup_test_env() {
    rm -f "${ASKO_ROOT}/.env.test"
}

# Check if Docker is available (for integration tests)
require_docker() {
    if ! command -v docker &>/dev/null; then
        skip "Docker not available"
    fi
}

# Check if the asko stack is running (for integration tests)
require_stack_running() {
    require_docker
    if ! docker compose -f "${ASKO_ROOT}/docker-compose.yml" ps --status running 2>/dev/null | grep -q "asko"; then
        skip "asko stack not running"
    fi
}
