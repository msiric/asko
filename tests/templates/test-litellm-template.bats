#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    generate_test_env
}

teardown() {
    cleanup_test_env
    rm -f "${ASKO_ROOT}/config/litellm/config.yaml"
}

@test "litellm config template exists" {
    [[ -f "${ASKO_ROOT}/config/litellm/config.yaml.template" ]]
}

@test "litellm template renders to valid YAML" {
    # Load test env vars
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)

    # Render template
    envsubst < "${ASKO_ROOT}/config/litellm/config.yaml.template" > "${ASKO_ROOT}/config/litellm/config.yaml"

    # Validate YAML syntax using python3 with yaml or json fallback
    python3 -c "
try:
    import yaml
    yaml.safe_load(open('${ASKO_ROOT}/config/litellm/config.yaml'))
except ImportError:
    # Fallback: basic structure check if PyYAML not installed
    content = open('${ASKO_ROOT}/config/litellm/config.yaml').read()
    assert 'model_list:' in content, 'Missing model_list key'
    assert 'router_settings:' in content, 'Missing router_settings key'
"
}

@test "litellm config contains local-default model" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/litellm/config.yaml.template" > "${ASKO_ROOT}/config/litellm/config.yaml"

    grep -q "local-default" "${ASKO_ROOT}/config/litellm/config.yaml"
}

@test "litellm config contains ollama backend URL" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/litellm/config.yaml.template" > "${ASKO_ROOT}/config/litellm/config.yaml"

    grep -q "ollama" "${ASKO_ROOT}/config/litellm/config.yaml"
    grep -q "11434" "${ASKO_ROOT}/config/litellm/config.yaml"
}

@test "litellm config contains fallback configuration" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/litellm/config.yaml.template" > "${ASKO_ROOT}/config/litellm/config.yaml"

    grep -q "fallbacks" "${ASKO_ROOT}/config/litellm/config.yaml"
}

@test "litellm config does not contain raw template variables" {
    export $(grep -v '^#' "${ASKO_ROOT}/.env.test" | grep -v '^$' | xargs)
    envsubst < "${ASKO_ROOT}/config/litellm/config.yaml.template" > "${ASKO_ROOT}/config/litellm/config.yaml"

    # No unresolved ${...} variables should remain
    ! grep -q '${' "${ASKO_ROOT}/config/litellm/config.yaml"
}
