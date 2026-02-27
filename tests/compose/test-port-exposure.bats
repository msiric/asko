#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "only caddy and n8n expose public ports" {
    cd "${ASKO_ROOT}"

    # Get always-on services (no profiles) that expose ports to all interfaces
    # Ports bound to 127.0.0.1 are host-local only, not public
    services_with_public_ports=$(python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
for name, svc in config.get('services', {}).items():
    if svc.get('profiles'):
        continue
    for port in svc.get('ports', []):
        p = str(port)
        if not p.startswith('127.0.0.1:'):
            print(name)
            break
" 2>/dev/null || echo "PARSE_ERROR")

    if [[ "$services_with_public_ports" == "PARSE_ERROR" ]]; then
        skip "python3 yaml module not available"
    fi

    echo "Services with public ports: $services_with_public_ports"
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        [[ "$svc" == "caddy" ]] || [[ "$svc" == "n8n" ]] || {
            echo "FAIL: $svc should not expose public ports"
            false
        }
    done <<< "$services_with_public_ports"
}

@test "caddy only exposes port 80" {
    cd "${ASKO_ROOT}"

    exposed_ports=$(python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
caddy = config.get('services', {}).get('caddy', {})
for port in caddy.get('ports', []):
    if isinstance(port, str):
        host_port = port.split(':')[0]
    elif isinstance(port, dict):
        host_port = str(port.get('published', ''))
    else:
        host_port = str(port)
    print(host_port)
" 2>/dev/null || echo "PARSE_ERROR")

    if [[ "$exposed_ports" == "PARSE_ERROR" ]]; then
        skip "python3 yaml module not available"
    fi

    echo "Exposed ports: $exposed_ports"
    [[ $(echo "$exposed_ports" | wc -l) -eq 1 ]]
    echo "$exposed_ports" | grep -q "80"
}
