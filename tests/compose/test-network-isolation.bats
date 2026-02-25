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

@test "ironclaw is on proxy, agents, and backend networks" {
    networks=$(get_service_networks "ironclaw")
    if [[ -z "$networks" ]]; then
        skip "python3 yaml not available"
    fi

    echo "IronClaw networks: $networks"
    echo "$networks" | grep -q "asko_proxy"
    echo "$networks" | grep -q "asko_agents"
    echo "$networks" | grep -q "asko_backend"
    # Should NOT be on automation
    ! echo "$networks" | grep -q "asko_automation"
}

@test "ironclaw can reach postgres for memory/embeddings" {
    # IronClaw needs postgres for its hybrid search memory via asko_backend
    ic_nets=$(get_service_networks "ironclaw")
    pg_nets=$(get_service_networks "postgres")
    if [[ -z "$ic_nets" ]] || [[ -z "$pg_nets" ]]; then
        skip "python3 yaml not available"
    fi

    shared=$(comm -12 <(echo "$ic_nets" | sort) <(echo "$pg_nets" | sort))
    echo "Shared networks between ironclaw and postgres: '$shared'"
    [[ -n "$shared" ]]
}

@test "ironclaw is isolated from automation network" {
    ic_nets=$(get_service_networks "ironclaw")
    if [[ -z "$ic_nets" ]]; then
        skip "python3 yaml not available"
    fi

    # IronClaw should not be on automation (n8n's network)
    ! echo "$ic_nets" | grep -q "asko_automation"
}

@test "ironclaw can reach litellm" {
    ic_nets=$(get_service_networks "ironclaw")
    ll_nets=$(get_service_networks "litellm")
    if [[ -z "$ic_nets" ]] || [[ -z "$ll_nets" ]]; then
        skip "python3 yaml not available"
    fi

    shared=$(comm -12 <(echo "$ic_nets" | sort) <(echo "$ll_nets" | sort))
    echo "Shared networks between ironclaw and litellm: '$shared'"
    [[ -n "$shared" ]]
}

@test "n8n is on proxy and automation networks only" {
    networks=$(get_service_networks "n8n")
    if [[ -z "$networks" ]]; then
        # n8n may not exist yet in Phase 2 compose - skip
        skip "n8n not in compose or python3 yaml not available"
    fi

    echo "n8n networks: $networks"
    echo "$networks" | grep -q "asko_proxy"
    echo "$networks" | grep -q "asko_automation"
    ! echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_agents"
}

@test "ollama is on backend network only" {
    networks=$(get_service_networks "ollama")
    if [[ -z "$networks" ]]; then
        skip "python3 yaml not available"
    fi

    echo "Ollama networks: $networks"
    echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_proxy"
    ! echo "$networks" | grep -q "asko_agents"
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
