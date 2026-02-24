#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    generate_test_env
}

teardown() {
    cleanup_test_env
    rm -f "${ASKO_ROOT}/config/ironclaw/config.toml"
}

@test "ironclaw config template exists" {
    [[ -f "${ASKO_ROOT}/config/ironclaw/config.toml.template" ]]
}

@test "ironclaw template renders without errors" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"
    [[ -s "${ASKO_ROOT}/config/ironclaw/config.toml" ]]
}

@test "ironclaw config points to litellm as LLM backend" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"

    grep -q "litellm" "${ASKO_ROOT}/config/ironclaw/config.toml"
}

@test "ironclaw config enables WASM sandbox" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"

    grep -qi "wasm\|sandbox" "${ASKO_ROOT}/config/ironclaw/config.toml"
}

@test "ironclaw config enables leak detection" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"

    grep -qi "leak_detection\|safety" "${ASKO_ROOT}/config/ironclaw/config.toml"
}

@test "ironclaw config enables exec approvals" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"

    grep -qi "approval" "${ASKO_ROOT}/config/ironclaw/config.toml"
}

@test "ironclaw config does not contain raw template variables" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/ironclaw/config.toml.template" > "${ASKO_ROOT}/config/ironclaw/config.toml"

    ! grep -q '${' "${ASKO_ROOT}/config/ironclaw/config.toml"
}
