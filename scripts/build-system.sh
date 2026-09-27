#!/bin/bash

set -e

# MAZU Config and Build Script
# Author: Collin MacDonald (cmacdonald01@wm.edu)
# Date: January 27th, 2025

# Functions

mazu_echo() {
    local input_text="$*"
    echo -e "\e[1;30;44mMazu:\e[0m $input_text."
}

# Initialization

mazu_echo "Start of Script"

mazu_echo "Initializing variables from input flags"

# Initialize flags for operations
config_system=false
build_envoy_flag=false
build_istio_flag=false
clean_flag=false
skip_docker_login_flag=false

# eval related
perf_setup_istio_flag=false
perf_setup_test_flag=false

for cmd in "$@"; do
    case $cmd in
        configure) config_system=true ;;
        build-envoy) build_envoy_flag=true ;;
        build-istio) build_istio_flag=true ;;
        clean) clean_flag=true ;;
        skip-docker-login) skip_docker_login_flag=true ;;
        *) 
            mazu_echo "Unknown command: $cmd"
            ;;
    esac
done

# Setup environment
mazu_echo "Setting up enviroment"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Check host prerequisites; Docker Hub login is only needed to push Istio images
bootstrap_args=()
if [[ "$skip_docker_login_flag" == "true" || ( "$build_istio_flag" == "false" && "$config_system" == "false" ) ]]; then
    bootstrap_args+=(--skip-docker-login)
fi
"$SCRIPT_DIR/bootstrap.sh" "${bootstrap_args[@]}"

# bootstrap.sh may have just added us to the docker group; re-run under sg so docker works without a re-login
if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    if [[ -n "${MAZU_SG_REEXEC:-}" ]]; then
        mazu_echo "Could not activate the docker group with sg; log out and back in, then re-run"
        exit 1
    fi
    mazu_echo "Re-running with the docker group active"
    exec sg docker -c "MAZU_SG_REEXEC=1 $(printf '%q ' "$BASH" "${BASH_SOURCE[0]}" "$@")"
fi

export PATH="$PATH:/usr/local/go/bin"
export MAZU_WORKSPACE_DIR="$PWD/workspace"
export MAZU_ISTIO_DIR="$MAZU_WORKSPACE_DIR/istio"
export MAZU_PROXY_DIR="$MAZU_WORKSPACE_DIR/proxy"
export MAZU_ENVOY_DIR="$MAZU_PROXY_DIR/envoy"

export MAZU_PROXY_OUT_DIR="$MAZU_PROXY_DIR/out/linux_amd64"
export MAZU_ISTIO_TMP_DIR="$MAZU_ISTIO_DIR/out/tmp"
export MAZU_ENVOY_OUTPUT_FILENAME="${MAZU_ENVOY_OUTPUT_FILENAME:-envoy}"
export MAZU_USE_LOCAL_ENVOY=1

export DOCKER_USER="${DOCKER_USER:-}"
export HUB="docker.io/$DOCKER_USER"
export TAG="${TAG:-st5-AttUpd}"
export PULL_POLICY="Always"
export ISTIO="$MAZU_ISTIO_DIR"

# Setup workspace
mazu_echo "Setting up workspace"

if [[ ! -d $MAZU_WORKSPACE_DIR ]]; then
    mazu_echo "Creating workspace directory"
    mkdir -p $MAZU_WORKSPACE_DIR
fi

# Setup repos
mazu_echo "Setting up repos"

if [[ ! -d $MAZU_ISTIO_DIR ]]; then
    mazu_echo "Cloning Istio repo"
    git clone https://github.com/etclab/istio.git $MAZU_ISTIO_DIR
    git -C $MAZU_ISTIO_DIR fetch
    git -C $MAZU_ISTIO_DIR switch "dev"
else
    mazu_echo "Pulling Istio repo"
    git -C $MAZU_ISTIO_DIR pull
fi

if [[ ! -d $MAZU_PROXY_DIR ]]; then
    mazu_echo "Cloning Proxy repo"
    git clone https://github.com/etclab/proxy.git $MAZU_PROXY_DIR
    git -C $MAZU_PROXY_DIR fetch
    git -C $MAZU_PROXY_DIR switch "master"
else
    mazu_echo "Pulling Proxy repo"
    git -C $MAZU_PROXY_DIR pull
fi

if [[ ! -d $MAZU_ENVOY_DIR ]]; then
    mazu_echo "Cloning Envoy repo"
    git clone https://github.com/etclab/envoy.git $MAZU_ENVOY_DIR
    git -C $MAZU_ENVOY_DIR fetch
    git -C $MAZU_ENVOY_DIR switch "dev"
else
    mazu_echo "Pulling Envoy repo"
    git -C $MAZU_ENVOY_DIR pull
fi

if [[ "$build_envoy_flag" == "true" || "$config_system" == "true" ]]; then
    cd $MAZU_PROXY_DIR

    if [[ "$clean_flag" == "true" ]]; then
        mazu_echo "Bulding Envoy - 'make clean'"
        BUILD_WITH_CONTAINER=1 make clean
    fi

    mazu_echo "Bulding Envoy - 'make build'"
    BUILD_WITH_CONTAINER=1 BAZEL_CONFIG_CURRENT=--config=release make build

    mazu_echo "Bulding Envoy - 'make exportcache'"
    BUILD_WITH_CONTAINER=1 BAZEL_CONFIG_CURRENT=--config=release make exportcache
    
    mkdir -p "$MAZU_ISTIO_TMP_DIR"
    cp -f "$MAZU_PROXY_OUT_DIR/envoy" "$MAZU_ISTIO_TMP_DIR/$MAZU_ENVOY_OUTPUT_FILENAME"

    cd -
fi

if [[ "$build_istio_flag" == "true" || "$config_system" == "true" ]]; then

    if [[ -z "$DOCKER_USER" ]]; then
        mazu_echo "DOCKER_USER is not set; export it to your Docker Hub username (e.g. DOCKER_USER=atosh502)"
        exit 1
    fi

    cd $MAZU_ISTIO_DIR

    if [[ "$clean_flag" == "true" ]]; then
        mazu_echo "Bulding Istio - 'make clean'"
        BUILD_WITH_CONTAINER=1 make clean
    fi 

    # Select envoy binary based on TAG
    if [[ "$TAG" == "st2-NIChaRes" ]]; then
        mazu_echo "Using envoy-st2-NIChaRes binary"
        cp -f "$MAZU_ISTIO_TMP_DIR/envoy-st2-NIChaRes" "$MAZU_ISTIO_TMP_DIR/envoy"
    fi

    mazu_echo "Bulding Istio - 'make docker'"
    BUILD_WITH_CONTAINER=1 GOTOOLCHAIN=auto make docker.proxyv2
    BUILD_WITH_CONTAINER=1 GOTOOLCHAIN=auto make docker.pilot

    mazu_echo "Bulding Istio - 'make docker.push'"
    BUILD_WITH_CONTAINER=1 GOTOOLCHAIN=auto make push.docker.proxyv2
    BUILD_WITH_CONTAINER=1 GOTOOLCHAIN=auto make push.docker.pilot

    cd -
fi

mazu_echo "Configuration Complete"

mazu_echo "End of Script"
