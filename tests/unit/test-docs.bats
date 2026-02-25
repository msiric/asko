#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "SECURITY.md exists and covers key topics" {
    [[ -f "${ASKO_ROOT}/docs/SECURITY.md" ]]
    grep -q "UFW\|ufw" "${ASKO_ROOT}/docs/SECURITY.md"
    grep -q "Tailscale\|tailscale" "${ASKO_ROOT}/docs/SECURITY.md"
    grep -q "WASM\|wasm" "${ASKO_ROOT}/docs/SECURITY.md"
    grep -q "no-new-privileges" "${ASKO_ROOT}/docs/SECURITY.md"
    grep -q "cap_drop" "${ASKO_ROOT}/docs/SECURITY.md"
    grep -q "userns-remap\|user namespace" "${ASKO_ROOT}/docs/SECURITY.md"
}

@test "TAILSCALE.md exists and covers setup" {
    [[ -f "${ASKO_ROOT}/docs/TAILSCALE.md" ]]
    grep -q "install" "${ASKO_ROOT}/docs/TAILSCALE.md"
    grep -q "ACL\|acl" "${ASKO_ROOT}/docs/TAILSCALE.md"
    grep -q "family\|Family" "${ASKO_ROOT}/docs/TAILSCALE.md"
}

@test "FAMILY-ACCESS.md exists and covers onboarding" {
    [[ -f "${ASKO_ROOT}/docs/FAMILY-ACCESS.md" ]]
    grep -q "Open WebUI" "${ASKO_ROOT}/docs/FAMILY-ACCESS.md"
    grep -q "Telegram" "${ASKO_ROOT}/docs/FAMILY-ACCESS.md"
    grep -q "WhatsApp" "${ASKO_ROOT}/docs/FAMILY-ACCESS.md"
    grep -q "Tailscale" "${ASKO_ROOT}/docs/FAMILY-ACCESS.md"
}

@test "docker-daemon.json template exists" {
    [[ -f "${ASKO_ROOT}/config/docker-daemon.json.template" ]]
    grep -q "userns-remap" "${ASKO_ROOT}/config/docker-daemon.json.template"
    grep -q "no-new-privileges" "${ASKO_ROOT}/config/docker-daemon.json.template"
}

@test "README.md covers security" {
    grep -q "Security\|security" "${ASKO_ROOT}/README.md"
    grep -q "Tailscale\|tailscale" "${ASKO_ROOT}/README.md"
}
