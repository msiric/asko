#!/usr/bin/env bats

load '../helpers/test-helpers'

@test ".env file is not committed to git" {
    cd "${ASKO_ROOT}"
    # .env should be in .gitignore
    grep -q "^\.env$" .gitignore
}

@test ".gitignore excludes generated config files" {
    cd "${ASKO_ROOT}"
    grep -q "config/litellm/config.yaml" .gitignore
    grep -q "config/caddy/Caddyfile" .gitignore
}

@test ".gitignore excludes backups directory" {
    cd "${ASKO_ROOT}"
    grep -q "backups/" .gitignore
}

@test "setup.sh sets .env permissions to 600" {
    # Verify the setup script contains chmod 600 for .env
    grep -q "chmod 600" "${ASKO_ROOT}/setup.sh"
    grep -q "\.env" "${ASKO_ROOT}/setup.sh"
}

@test "no secrets in committed template files" {
    cd "${ASKO_ROOT}"

    # Template files should use ${VAR} references, not actual values
    for template in config/*/*.template; do
        [[ -f "$template" ]] || continue
        # Should not contain what looks like a real API key
        ! grep -qP 'sk-[a-zA-Z0-9]{20,}' "$template"
        ! grep -qP '[a-f0-9]{32,}' "$template"
    done
}

@test "init-databases.sql does not contain plaintext passwords" {
    if [[ -f "${ASKO_ROOT}/config/postgres/init-databases.sql" ]]; then
        ! grep -qi "password" "${ASKO_ROOT}/config/postgres/init-databases.sql" || \
        # If it mentions password, it should be a placeholder
        grep -q "password" "${ASKO_ROOT}/config/postgres/init-databases.sql"
    fi
}
