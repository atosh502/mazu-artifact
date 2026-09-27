#!/bin/bash

set -e

# MAZU Bootstrap Script
# Checks the host prerequisites for building Envoy and Istio:
#   - Go is installed
#   - Docker Engine is installed and the daemon is reachable
#   - The current user is in the docker group
#   - The current user is logged in to Docker Hub (skip with --skip-docker-login)
#
# Usage: ./bootstrap.sh [--skip-docker-login]

# Functions

mazu_echo() {
    local input_text="$*"
    echo -e "\e[1;30;44mMazu:\e[0m $input_text."
}

mazu_fail() {
    mazu_echo "$*"
    exit 1
}

docker_hub_logged_in() {
    local config="$HOME/.docker/config.json"
    [[ -f $config ]] || return 1

    # Credentials stored inline in config.json
    if grep -q '"https://index.docker.io/v1/"' "$config"; then
        return 0
    fi

    # Credentials stored in a credential helper
    local store
    store=$(grep -o '"credsStore"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" | sed 's/.*"\([^"]*\)"$/\1/')
    if [[ -n $store ]] && command -v "docker-credential-$store" >/dev/null; then
        "docker-credential-$store" list 2>/dev/null | grep -q 'index.docker.io'
        return $?
    fi

    return 1
}

# Initialization

skip_docker_login=false

for arg in "$@"; do
    case $arg in
        --skip-docker-login) skip_docker_login=true ;;
        *) mazu_fail "Unknown option: $arg" ;;
    esac
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Go

mazu_echo "Checking Go"

export PATH="$PATH:/usr/local/go/bin"

if ! command -v go >/dev/null; then
    mazu_echo "Go not found, installing"
    "$SCRIPT_DIR/install-go.sh"
fi

mazu_echo "Found $(go version)"

# Docker Engine

mazu_echo "Checking Docker Engine"

if ! command -v docker >/dev/null; then
    mazu_echo "Docker not found, installing"
    "$SCRIPT_DIR/install-docker.sh"
fi

mazu_echo "Found $(docker --version)"

# Docker group

mazu_echo "Checking docker group membership"

if ! getent group docker | cut -d: -f4 | tr ',' '\n' | grep -qx "$USER"; then
    mazu_echo "Adding $USER to the docker group"
    sudo groupadd -f docker
    sudo usermod -aG docker "$USER"
fi

# A new group membership only applies to new logins; re-run this script under sg instead
if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    if [[ -n "${MAZU_SG_REEXEC:-}" ]]; then
        mazu_fail "Could not activate the docker group with sg; log out and back in, then re-run"
    fi
    mazu_echo "Re-running with the docker group active"
    exec sg docker -c "MAZU_SG_REEXEC=1 $(printf '%q ' "$BASH" "${BASH_SOURCE[0]}" "$@")"
fi

if ! docker info >/dev/null 2>&1; then
    mazu_fail "Cannot reach the Docker daemon; check 'sudo systemctl status docker'"
fi

mazu_echo "Docker daemon reachable as $USER"

# Docker Hub login

if [[ "$skip_docker_login" == "true" ]]; then
    mazu_echo "Skipping Docker Hub login check"
elif docker_hub_logged_in; then
    mazu_echo "Logged in to Docker Hub"
elif [[ -t 0 ]]; then
    mazu_echo "Not logged in to Docker Hub, running 'docker login'"
    docker login ${DOCKER_USER:+-u "$DOCKER_USER"}
else
    mazu_fail "Not logged in to Docker Hub; run 'docker login' or pass --skip-docker-login"
fi

mazu_echo "Bootstrap Complete"
