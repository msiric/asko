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

# Helper: get networks for a service from docker-compose.yml
get_service_networks() {
    local service="$1"
    # Try python yaml first, fall back to docker compose config parsing
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config.get('services', {}).get('$service', {})
nets = svc.get('networks', [])
if isinstance(nets, list):
    for n in nets:
        print(n)
elif isinstance(nets, dict):
    for n in nets.keys():
        print(n)
" 2>/dev/null || {
        # Fallback: parse docker compose config output
        cd "${ASKO_ROOT}"
        docker compose config 2>/dev/null | \
            awk "/^  ${service}:/,/^  [a-z]/" | \
            awk '/networks:/,/^    [a-z]/' | \
            grep -oP 'asko_\w+' | sort -u
    }
}

@test "n8n is on proxy and automation networks only" {
    networks=$(get_service_networks "n8n")
    if [[ -z "$networks" ]]; then
        skip "n8n not in compose or python3 yaml not available"
    fi

    echo "n8n networks: $networks"
    echo "$networks" | grep -q "asko_proxy"
    echo "$networks" | grep -q "asko_automation"
    ! echo "$networks" | grep -q "asko_backend"
}

@test "ollama is on backend network only" {
    networks=$(get_service_networks "ollama")
    if [[ -z "$networks" ]]; then
        skip "python3 yaml not available"
    fi

    echo "Ollama networks: $networks"
    echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_proxy"
    ! echo "$networks" | grep -q "asko_automation"
}

@test "data services are not on the proxy network" {
    # Ollama and postgres should NOT be on proxy
    for svc in ollama postgres; do
        networks=$(get_service_networks "$svc")
        if [[ -z "$networks" ]]; then
            skip "python3 yaml not available"
        fi
        if echo "$networks" | grep -q "asko_proxy"; then
            echo "FAIL: $svc should not be on asko_proxy"
            false
        fi
    done
}
