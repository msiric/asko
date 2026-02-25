#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "searxng settings.yml exists" {
    [[ -f "${ASKO_ROOT}/config/searxng/settings.yml" ]]
}

@test "searxng settings has json format enabled" {
    grep -q "json" "${ASKO_ROOT}/config/searxng/settings.yml"
}

@test "searxng settings has html format enabled" {
    grep -q "html" "${ASKO_ROOT}/config/searxng/settings.yml"
}

@test "searxng settings uses default settings" {
    grep -q "use_default_settings: true" "${ASKO_ROOT}/config/searxng/settings.yml"
}
