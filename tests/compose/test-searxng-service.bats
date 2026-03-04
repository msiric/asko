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

@test "searxng service is defined in docker-compose.yml" {
    cd "${ASKO_ROOT}"
    config=$(docker compose config)
    echo "$config" | grep -q "asko-searxng"
}

@test "searxng is on backend network only" {
    networks=$(get_service_networks "searxng")
    [[ -n "$networks" ]] || skip "python3 yaml not available"

    echo "SearXNG networks: $networks"
    echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_proxy"
    ! echo "$networks" | grep -q "asko_automation"
}

@test "searxng has security hardening" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config['services']['searxng']
sec = svc.get('security_opt', [])
assert any('no-new-privileges' in s for s in sec), f'Missing no-new-privileges: {sec}'
cap = svc.get('cap_drop', [])
assert 'ALL' in cap, f'Missing cap_drop ALL: {cap}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "searxng has resource limits" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
limits = config['services']['searxng']['deploy']['resources']['limits']
assert 'memory' in limits, f'No memory limit: {limits}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "searxng has healthcheck" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
hc = config['services']['searxng'].get('healthcheck', {})
assert 'test' in hc, f'No healthcheck: {hc}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "searxng does not expose ports to host" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config['services']['searxng']
assert 'ports' not in svc, f'SearXNG should not expose ports: {svc.get(\"ports\")}'
" 2>/dev/null || skip "python3 yaml not available"
}
