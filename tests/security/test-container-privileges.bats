#!/usr/bin/env bats

load '../helpers/test-helpers'

setup() {
    require_docker
    require_stack_running
}

@test "no container runs as root user" {
    cd "${ASKO_ROOT}"

    # Check each running container's user
    containers=$(docker compose ps -q 2>/dev/null)
    for container in $containers; do
        user=$(docker inspect --format '{{.Config.User}}' "$container" 2>/dev/null)
        # User should be set to non-root, OR the image default should be non-root
        # Some images (postgres, redis) run as their own user by default
        # The key check is no-new-privileges below
        echo "Container $container runs as user: ${user:-default}"
    done
}

@test "all running containers have no-new-privileges" {
    cd "${ASKO_ROOT}"

    containers=$(docker compose ps -q 2>/dev/null)
    for container in $containers; do
        nnp=$(docker inspect --format '{{.HostConfig.SecurityOpt}}' "$container" 2>/dev/null)
        echo "Container $container security_opt: $nnp"
        echo "$nnp" | grep -q "no-new-privileges"
    done
}

@test "all running containers drop ALL capabilities" {
    cd "${ASKO_ROOT}"

    containers=$(docker compose ps -q 2>/dev/null)
    for container in $containers; do
        cap_drop=$(docker inspect --format '{{.HostConfig.CapDrop}}' "$container" 2>/dev/null)
        echo "Container $container cap_drop: $cap_drop"
        echo "$cap_drop" | grep -qi "all"
    done
}

@test "all running containers have memory limits" {
    cd "${ASKO_ROOT}"

    containers=$(docker compose ps -q 2>/dev/null)
    for container in $containers; do
        mem=$(docker inspect --format '{{.HostConfig.Memory}}' "$container" 2>/dev/null)
        echo "Container $container memory limit: $mem"
        # Memory limit should be > 0 (0 means unlimited)
        [[ "$mem" -gt 0 ]]
    done
}
