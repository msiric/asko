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

# Helper
get_service_networks() {
    local service="$1"
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config.get('services', {}).get('$service', {})
nets = svc.get('networks', [])
if isinstance(nets, list):
    for n in nets: print(n)
elif isinstance(nets, dict):
    for n in nets.keys(): print(n)
" 2>/dev/null
}

get_service_env() {
    local service="$1" var="$2"
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config.get('services', {}).get('$service', {})
env = svc.get('environment', {})
if isinstance(env, dict):
    print(env.get('$var', ''))
elif isinstance(env, list):
    for e in env:
        if e.startswith('$var='):
            print(e.split('=', 1)[1])
" 2>/dev/null
}

@test "n8n service is defined in docker-compose.yml" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)
    echo "$config" | grep -q "asko-n8n"
}

@test "waha service is defined in docker-compose.yml" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)
    echo "$config" | grep -q "asko-waha"
}

@test "n8n is on proxy and automation networks only" {
    networks=$(get_service_networks "n8n")
    [[ -n "$networks" ]] || skip "python3 yaml not available"

    echo "n8n networks: $networks"
    echo "$networks" | grep -q "asko_proxy"
    echo "$networks" | grep -q "asko_automation"
    ! echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_agents"
}

@test "waha is on automation network only" {
    networks=$(get_service_networks "waha")
    [[ -n "$networks" ]] || skip "python3 yaml not available"

    echo "WAHA networks: $networks"
    echo "$networks" | grep -q "asko_automation"
    ! echo "$networks" | grep -q "asko_proxy"
    ! echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_agents"
}

@test "n8n has community packages disabled" {
    val=$(get_service_env "n8n" "N8N_COMMUNITY_PACKAGES_ENABLED")
    [[ -n "$val" ]] || skip "python3 yaml not available"

    echo "N8N_COMMUNITY_PACKAGES_ENABLED=$val"
    [[ "$val" == "false" ]]
}

@test "n8n has public API disabled" {
    val=$(get_service_env "n8n" "N8N_PUBLIC_API_DISABLED")
    [[ -n "$val" ]] || skip "python3 yaml not available"

    echo "N8N_PUBLIC_API_DISABLED=$val"
    [[ "$val" == "true" ]]
}

@test "n8n has git node excluded" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
env = config['services']['n8n']['environment']
exclude = env.get('N8N_NODES_EXCLUDE', '')
assert 'git' in exclude.lower(), f'Git node not excluded: {exclude}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "n8n has basic auth enabled" {
    val=$(get_service_env "n8n" "N8N_BASIC_AUTH_ACTIVE")
    [[ -n "$val" ]] || skip "python3 yaml not available"

    [[ "$val" == "true" ]]
}

@test "n8n depends on postgres" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
deps = config['services']['n8n'].get('depends_on', {})
assert 'postgres' in deps, f'n8n does not depend on postgres: {deps}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "n8n has security hardening (cap_drop, no-new-privileges)" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config['services']['n8n']
sec = svc.get('security_opt', [])
assert any('no-new-privileges' in s for s in sec), f'Missing no-new-privileges: {sec}'
cap = svc.get('cap_drop', [])
assert 'ALL' in cap, f'Missing cap_drop ALL: {cap}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "n8n has resource limits" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
deploy = config['services']['n8n'].get('deploy', {})
limits = deploy.get('resources', {}).get('limits', {})
assert 'memory' in limits, f'n8n has no memory limit: {limits}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "n8n has healthcheck" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
hc = config['services']['n8n'].get('healthcheck', {})
assert 'test' in hc, f'n8n has no healthcheck: {hc}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "waha has security hardening" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)
    echo "$config" | grep -A 30 "asko-waha" | grep -q "no-new-privileges"
}
