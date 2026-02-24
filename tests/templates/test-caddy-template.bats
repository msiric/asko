#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    generate_test_env
}

teardown() {
    cleanup_test_env
    rm -f "${ASKO_ROOT}/config/caddy/Caddyfile"
}

@test "caddy config template exists" {
    [[ -f "${ASKO_ROOT}/config/caddy/Caddyfile.template" ]]
}

@test "caddy template renders without errors" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/caddy/Caddyfile.template" > "${ASKO_ROOT}/config/caddy/Caddyfile"
    [[ -s "${ASKO_ROOT}/config/caddy/Caddyfile" ]]
}

@test "caddy config routes to open-webui" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/caddy/Caddyfile.template" > "${ASKO_ROOT}/config/caddy/Caddyfile"

    grep -q "open-webui" "${ASKO_ROOT}/config/caddy/Caddyfile"
}

@test "caddy config routes to litellm" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/caddy/Caddyfile.template" > "${ASKO_ROOT}/config/caddy/Caddyfile"

    grep -q "litellm" "${ASKO_ROOT}/config/caddy/Caddyfile"
}

@test "caddy config disables admin API" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/caddy/Caddyfile.template" > "${ASKO_ROOT}/config/caddy/Caddyfile"

    grep -q "admin off" "${ASKO_ROOT}/config/caddy/Caddyfile"
}

@test "caddy config does not contain raw template variables" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/caddy/Caddyfile.template" > "${ASKO_ROOT}/config/caddy/Caddyfile"

    ! grep -q '${' "${ASKO_ROOT}/config/caddy/Caddyfile"
}
