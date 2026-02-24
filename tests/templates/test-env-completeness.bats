#!/usr/bin/env bats

load '../helpers/test-helpers'

@test ".env.example file exists" {
    [[ -f "${ASKO_ROOT}/.env.example" ]]
}

@test "every variable in docker-compose.yml is documented in .env.example" {
    # Extract all ${VAR} references from docker-compose.yml
    compose_vars=$(grep -oP '\$\{(\w+?)(?::?-[^}]*)?\}' "${ASKO_ROOT}/docker-compose.yml" \
        | sed 's/\${//;s/[:}].*//;s/-.*$//' \
        | sort -u)

    # Check each is in .env.example
    missing=""
    for var in $compose_vars; do
        if ! grep -q "^${var}=" "${ASKO_ROOT}/.env.example" && \
           ! grep -q "^#.*${var}" "${ASKO_ROOT}/.env.example"; then
            missing="${missing} ${var}"
        fi
    done

    if [[ -n "$missing" ]]; then
        echo "Variables in docker-compose.yml but missing from .env.example:${missing}"
        [[ -z "$missing" ]]
    fi
}

@test ".env.example does not contain actual secrets" {
    # .env.example should have placeholder values, not real secrets
    ! grep -qP '^[A-Z_]+=sk-[a-zA-Z0-9]{20,}' "${ASKO_ROOT}/.env.example"
    ! grep -qP '^[A-Z_]+=[a-f0-9]{32,}$' "${ASKO_ROOT}/.env.example"
}

@test ".env.example has comments explaining each section" {
    # Should have at least section headers as comments
    grep -q "^#.*PostgreSQL" "${ASKO_ROOT}/.env.example" || \
    grep -q "^#.*postgres" "${ASKO_ROOT}/.env.example"
}
