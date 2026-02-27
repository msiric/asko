#!/usr/bin/env bash
set -euo pipefail

# asko setup wizard
# Generates configuration and starts the AI assistant stack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_VERSION="0.1.0"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Allow sourcing functions only (for testing) ---
if [[ "${1:-}" == "--source-only" ]]; then
    # Define all functions below, but don't execute main()
    _ASKO_SOURCE_ONLY=true
fi

# ============================================================
# Utility Functions
# ============================================================

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
fatal() { echo -e "${RED}[FATAL]${NC} $*"; exit 1; }

generate_secret() {
    local length="${1:-32}"
    python3 -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range($length)), end='')"
}

generate_hex_secret() {
    local length="${1:-64}"
    python3 -c "import secrets; print(secrets.token_hex($length // 2), end='')"
}

check_command() {
    command -v "$1" &>/dev/null
}

check_architecture() {
    local arch
    arch="$(uname -m)"
    if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        return 0
    fi
    return 1
}

get_total_ram_gb() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sysctl -n hw.memsize | awk '{printf "%d", $1/1073741824}'
    else
        free -g | awk '/^Mem:/{print $2}'
    fi
}

get_available_disk_gb() {
    df -BG "$SCRIPT_DIR" 2>/dev/null | awk 'NR==2{gsub("G",""); print $4}' || \
    df -g "$SCRIPT_DIR" 2>/dev/null | awk 'NR==2{print $4}' || \
    echo "0"
}

# ============================================================
# Pre-flight Checks
# ============================================================

preflight_checks() {
    info "Running pre-flight checks..."
    local errors=0

    # Docker
    if ! check_command docker; then
        error "Docker not installed. Install from https://docs.docker.com/engine/install/"
        errors=$((errors + 1))
    fi

    # Docker Compose V2
    if ! docker compose version &>/dev/null 2>&1; then
        error "Docker Compose V2 not found. Update Docker or install docker-compose-plugin."
        errors=$((errors + 1))
    fi

    # Architecture
    if ! check_architecture; then
        error "Unsupported architecture: $(uname -m). x86_64 or arm64 required."
        errors=$((errors + 1))
    fi

    # RAM
    local ram_gb
    ram_gb=$(get_total_ram_gb)
    if [[ "$ram_gb" -lt 8 ]]; then
        error "Only ${ram_gb}GB RAM detected. Minimum 8GB required (16GB+ recommended)."
        errors=$((errors + 1))
    elif [[ "$ram_gb" -lt 16 ]]; then
        warn "Only ${ram_gb}GB RAM detected. 16GB+ recommended for comfortable operation."
    else
        info "RAM: ${ram_gb}GB detected"
    fi

    # Disk
    local disk_gb
    disk_gb=$(get_available_disk_gb)
    if [[ "$disk_gb" -lt 20 ]]; then
        warn "Only ${disk_gb}GB disk free. 50GB+ recommended (models are 5-20GB each)."
    else
        info "Disk: ${disk_gb}GB available"
    fi

    # python3 (required for secret generation)
    if ! check_command python3; then
        error "python3 not installed. Required for secret generation."
        errors=$((errors + 1))
    fi

    # envsubst (required for config template rendering)
    if ! check_command envsubst; then
        error "envsubst not found. Install with: sudo apt-get install gettext-base"
        errors=$((errors + 1))
    fi

    # Tailscale
    if ! check_command tailscale; then
        warn "Tailscale not installed. Remote access won't work without it."
        warn "Install from: https://tailscale.com/download"
    else
        info "Tailscale detected"
    fi

    if [[ "$errors" -gt 0 ]]; then
        fatal "Pre-flight checks failed with $errors error(s). Fix the above and re-run."
    fi

    info "Pre-flight checks passed"
}

# ============================================================
# Configuration
# ============================================================

ask_config() {
    echo ""
    echo -e "${BOLD}=== asko Configuration ===${NC}"
    echo ""

    # Domain base (validated: no spaces, no protocol prefix)
    while true; do
        read -rp "Domain base [asko.local]: " DOMAIN_BASE
        DOMAIN_BASE="${DOMAIN_BASE:-asko.local}"
        if [[ "$DOMAIN_BASE" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
            break
        fi
        warn "Invalid domain. Use only letters, numbers, dots, and hyphens (e.g., asko.local)"
    done

    # Anthropic API key (silent input to prevent shoulder-surfing)
    read -rsp "Anthropic API key (optional, press Enter to skip): " ANTHROPIC_API_KEY
    echo ""
    ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

    # OpenAI API key
    read -rsp "OpenAI API key (optional, press Enter to skip): " OPENAI_API_KEY
    echo ""
    OPENAI_API_KEY="${OPENAI_API_KEY:-}"

    echo ""
    info "Configuration captured"
}

# ============================================================
# File Generation
# ============================================================

generate_env() {
    local env_file="${1:-${SCRIPT_DIR}/.env}"
    info "Generating ${env_file}..."

    # generate_secret uses [a-zA-Z0-9] only — safe for embedding in DATABASE_URL
    # without URL-encoding. Do NOT change the charset without updating URL construction.
    local pg_pass
    pg_pass=$(generate_secret 64)

    cat > "$env_file" <<EOF
# asko Environment Configuration
# Generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# DO NOT commit this file to git

# --- PostgreSQL ---
POSTGRES_USER=asko
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=asko

# --- Database URLs ---
DATABASE_URL=postgresql://asko:${pg_pass}@postgres:5432/asko
OPENWEBUI_DATABASE_URL=postgresql://asko:${pg_pass}@postgres:5432/asko_openwebui

# --- LiteLLM ---
LITELLM_MASTER_KEY=sk-asko-$(generate_secret 48)
LITELLM_SALT_KEY=$(generate_secret 32)

# --- n8n ---
N8N_ENCRYPTION_KEY=$(generate_secret 32)
N8N_USER_MANAGEMENT_JWT_SECRET=$(generate_secret 64)
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$(generate_secret 32)

# --- Open WebUI ---
OPENWEBUI_SECRET_KEY=$(generate_secret 48)

# --- SearXNG ---
SEARXNG_SECRET=$(generate_secret 32)

# --- LinguaCafe ---
LINGUACAFE_DB_PASSWORD=$(generate_secret 32)

# --- Admin (auto-generated — used for Open WebUI and n8n) ---
ADMIN_EMAIL=admin@${DOMAIN_BASE:-asko.local}
ADMIN_PASSWORD=$(generate_secret 24)

# --- Cloud LLM API Keys ---
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# --- Domain ---
DOMAIN_BASE=${DOMAIN_BASE:-asko.local}
EOF

    chmod 600 "$env_file"
    info "Environment file generated (chmod 600)"
}

render_templates() {
    local env_file="${1:-${SCRIPT_DIR}/.env}"
    info "Rendering config templates..."

    # Load env vars
    set -a
    source "$env_file"
    set +a

    # LiteLLM config uses its own "os.environ/VAR" syntax for secrets,
    # so we copy it verbatim rather than running envsubst on it.
    if [[ -f "${SCRIPT_DIR}/config/litellm/config.yaml.template" ]]; then
        cp "${SCRIPT_DIR}/config/litellm/config.yaml.template" \
           "${SCRIPT_DIR}/config/litellm/config.yaml"
        info "  config/litellm/config.yaml (verbatim — uses LiteLLM env refs)"
    fi

    if [[ -f "${SCRIPT_DIR}/config/caddy/Caddyfile.template" ]]; then
        envsubst < "${SCRIPT_DIR}/config/caddy/Caddyfile.template" \
            > "${SCRIPT_DIR}/config/caddy/Caddyfile"
        info "  config/caddy/Caddyfile"
    fi

    info "Templates rendered"
}

# ============================================================
# Stack Management
# ============================================================

start_stack() {
    info "Pulling Docker images (this may take a while on first run)..."
    cd "$SCRIPT_DIR"
    docker compose pull

    info "Starting services..."
    docker compose up -d

    info "Waiting for services to become healthy..."
    local max_wait=120
    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        local healthy
        healthy=$(docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || echo 0)
        local total
        total=$(docker compose ps -q 2>/dev/null | wc -l | tr -d ' ')

        if [[ "$healthy" -ge "$total" ]] && [[ "$total" -gt 0 ]]; then
            info "All $total services healthy"
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        echo -ne "\r  Waiting... ${elapsed}s (${healthy}/${total} healthy)"
    done

    echo ""
    warn "Not all services became healthy within ${max_wait}s"
    warn "Check: docker compose ps"
}

pull_default_model() {
    info "Pulling default Ollama model (qwen2.5:7b)..."
    docker compose exec -T ollama ollama pull qwen2.5:7b || \
        warn "Failed to pull qwen2.5:7b. You can pull models later with: docker compose exec ollama ollama pull <model>"

    info "Pulling embeddings model (nomic-embed-text)..."
    docker compose exec -T ollama ollama pull nomic-embed-text || \
        warn "Failed to pull nomic-embed-text."
}

# ============================================================
# Post-Setup Automation
# ============================================================

post_setup() {
    info "Running post-setup automation..."

    # Load generated env vars
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a

    # --- Wait for Open WebUI API to be ready ---
    info "Waiting for Open WebUI API..."
    local webui_ready=false
    for _ in $(seq 1 30); do
        if docker compose exec -T open-webui \
            curl -sf http://localhost:8080/api/v1/auths/signup -X OPTIONS > /dev/null 2>&1; then
            webui_ready=true
            break
        fi
        sleep 2
    done
    if [[ "$webui_ready" != "true" ]]; then
        warn "Open WebUI API not responding after 60s. Admin creation may fail."
    fi

    # --- Open WebUI: create admin account ---
    info "Creating Open WebUI admin account..."
    local webui_payload
    webui_payload=$(python3 -c "
import json, os
print(json.dumps({
    'email': os.environ.get('ADMIN_EMAIL', ''),
    'password': os.environ.get('ADMIN_PASSWORD', ''),
    'name': 'Admin'
}))")
    docker compose exec -T open-webui \
        curl -sf -X POST http://localhost:8080/api/v1/auths/signup \
        -H "Content-Type: application/json" \
        -d "$webui_payload" > /dev/null 2>&1 \
        && info "  Open WebUI admin created" \
        || warn "  Open WebUI admin already exists or signup failed (configure manually)"

    # --- n8n: create owner account ---
    info "Creating n8n owner account..."
    local n8n_payload
    n8n_payload=$(python3 -c "
import json, os
print(json.dumps({
    'email': os.environ.get('ADMIN_EMAIL', ''),
    'firstName': 'Admin',
    'lastName': 'Asko',
    'password': os.environ.get('ADMIN_PASSWORD', '')
}))")
    docker compose exec -T n8n \
        curl -sf -X POST http://localhost:5678/rest/owner/setup \
        -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "$n8n_payload" > /dev/null 2>&1 \
        && info "  n8n owner created" \
        || warn "  n8n owner already exists or setup failed (configure manually at n8n.${DOMAIN_BASE})"

    # --- n8n: import workflows ---
    info "Importing n8n workflows..."
    local imported=0
    for workflow in "${SCRIPT_DIR}/workflows/n8n/"*.json; do
        [[ -f "$workflow" ]] || continue
        if docker compose exec -T n8n n8n import:workflow --input=/dev/stdin < "$workflow" > /dev/null 2>&1; then
            imported=$((imported + 1))
        fi
    done
    info "  ${imported} workflows imported (activate in n8n UI after configuring credentials)"

    # --- Backup crontab ---
    info "Setting up daily backup cron (3:00 AM)..."
    mkdir -p "${SCRIPT_DIR}/logs"
    local backup_cmd="${SCRIPT_DIR}/scripts/backup.sh"
    local cron_entry="0 3 * * * ${backup_cmd} >> ${SCRIPT_DIR}/logs/backup.log 2>&1"
    if crontab -l 2>/dev/null | grep -qF "$backup_cmd"; then
        info "  Backup cron already configured"
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        info "  Backup cron added"
    fi

    info "Post-setup complete"
}

# ============================================================
# Summary
# ============================================================

print_summary() {
    local domain_base="${DOMAIN_BASE:-asko.local}"

    # Load env for admin credentials
    local admin_email admin_password
    admin_email=$(grep "^ADMIN_EMAIL=" "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d'=' -f2-)
    admin_password=$(grep "^ADMIN_PASSWORD=" "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d'=' -f2-)

    echo ""
    echo -e "${GREEN}${BOLD}=== asko is running! ===${NC}"
    echo ""
    echo -e "  ${BOLD}Admin credentials${NC} (same for Open WebUI and n8n):"
    echo -e "    Email:    ${admin_email:-admin@${domain_base}}"
    echo -e "    Password: ${admin_password:-see .env file}"
    echo ""
    echo -e "  ${BOLD}Ready to use:${NC}"
    echo "    Chat UI:   http://chat.${domain_base}  (admin account created)"
    echo "    n8n:       http://n8n.${domain_base}   (admin account created, workflows imported)"
    echo "    LiteLLM:   http://ai.${domain_base}"
    echo ""
    echo "    Backups:   Scheduled daily at 3:00 AM"
    echo ""
    echo -e "  ${BOLD}Needs manual setup:${NC}"
    echo "    1. Add DNS entries for *.${domain_base} pointing to this machine"
    echo "       Or access directly via http://localhost:80"
    echo "    2. Telegram bot: message @BotFather → /newbot → add token"
    echo "       in n8n credentials, then activate workflows"
    echo "    3. (Optional) Cloudflare Tunnel for n8n Telegram webhooks:"
    echo "       cloudflared tunnel --url http://localhost:5678"
    echo "    4. (Optional) Amadeus API key for flight price monitoring:"
    echo "       Register at https://developers.amadeus.com"
    echo ""
    echo -e "  ${BOLD}Commands:${NC}  make help"
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    echo ""
    echo -e "${BOLD}  __ _ ___| | _____  ${NC}"
    echo -e "${BOLD} / _\` / __| |/ / _ \\ ${NC}"
    echo -e "${BOLD}| (_| \\__ \\   < (_) |${NC}"
    echo -e "${BOLD} \\__,_|___/_|\\_\\___/ ${NC} v${ASKO_VERSION}"
    echo ""
    echo "Security-first, self-hosted AI assistant stack"
    echo ""

    # Idempotency: detect existing installation
    if [[ -f "${SCRIPT_DIR}/.env" ]]; then
        info "Existing installation detected (.env found)"
        echo ""
        echo "  1) Continue with existing config (re-renders templates, starts services, pulls models)"
        echo "  2) Reset everything (WARNING: regenerates all secrets, breaks running services)"
        echo "  3) Abort"
        echo ""
        read -rp "Choice [1]: " choice
        choice="${choice:-1}"

        case "$choice" in
            1)
                info "Continuing with existing configuration..."
                cd "$SCRIPT_DIR"
                render_templates
                start_stack
                pull_default_model
                post_setup
                print_summary
                return 0
                ;;
            2)
                warn "This will regenerate ALL secrets and require re-initializing databases."
                read -rp "Type 'RESET' to confirm: " confirm
                if [[ "$confirm" != "RESET" ]]; then
                    echo "Aborted."
                    exit 0
                fi
                ;;
            *)
                echo "Aborted."
                exit 0
                ;;
        esac
    fi

    preflight_checks
    ask_config
    generate_env
    render_templates
    start_stack
    pull_default_model
    post_setup
    print_summary
}

# Only run main if not sourced for testing
if [[ "${_ASKO_SOURCE_ONLY:-}" != "true" ]]; then
    main "$@"
fi
