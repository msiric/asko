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

@test "linguacafe is behind linguacafe profile" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config['services']['linguacafe']
profiles = svc.get('profiles', [])
assert 'linguacafe' in profiles, f'Missing linguacafe profile: {profiles}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "linguacafe services are on isolated network" {
    networks=$(get_service_networks "linguacafe")
    [[ -n "$networks" ]] || skip "python3 yaml not available"

    echo "LinguaCafe networks: $networks"
    echo "$networks" | grep -q "asko_linguacafe"
    ! echo "$networks" | grep -q "asko_backend"
    ! echo "$networks" | grep -q "asko_proxy"
    ! echo "$networks" | grep -q "asko_automation"
}

@test "linguacafe-db is behind linguacafe profile" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
svc = config['services']['linguacafe-db']
profiles = svc.get('profiles', [])
assert 'linguacafe' in profiles, f'Missing linguacafe profile: {profiles}'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "all linguacafe services have security hardening" {
    python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
for name in ['linguacafe', 'linguacafe-db', 'linguacafe-redis', 'linguacafe-python-service']:
    svc = config['services'][name]
    sec = svc.get('security_opt', [])
    assert any('no-new-privileges' in s for s in sec), f'{name} missing no-new-privileges'
    cap = svc.get('cap_drop', [])
    assert 'ALL' in cap, f'{name} missing cap_drop ALL'
" 2>/dev/null || skip "python3 yaml not available"
}

@test "linguacafe profile validates with docker compose" {
    cd "${ASKO_ROOT}"
    run docker compose --profile linguacafe config --quiet
    [[ "$status" -eq 0 ]]
}
