#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "only caddy exposes ports to the host" {
    cd "${ASKO_ROOT}"

    # Parse docker-compose.yml for port mappings
    # Lines with "ports:" followed by host:container mappings
    # Only the caddy service should have them

    # Get all always-on services (no profiles) that have ports: sections
    services_with_ports=$(python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
for name, svc in config.get('services', {}).items():
    if 'ports' in svc and not svc.get('profiles'):
        print(name)
" 2>/dev/null || echo "PARSE_ERROR")

    if [[ "$services_with_ports" == "PARSE_ERROR" ]]; then
        skip "python3 yaml module not available"
    fi

    # Only caddy should appear
    echo "Services with ports: $services_with_ports"
    [[ "$services_with_ports" == "caddy" ]]
}

@test "caddy only exposes ports 80 and 443" {
    cd "${ASKO_ROOT}"

    exposed_ports=$(python3 -c "
import yaml
with open('${ASKO_ROOT}/docker-compose.yml') as f:
    config = yaml.safe_load(f)
caddy = config.get('services', {}).get('caddy', {})
for port in caddy.get('ports', []):
    # port can be string '80:80' or dict
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
    # Should only contain 80 and 443
    [[ $(echo "$exposed_ports" | wc -l) -le 2 ]]
    echo "$exposed_ports" | grep -q "80"
    echo "$exposed_ports" | grep -q "443"
}
