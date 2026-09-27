#!/bin/bash

set -e

# MAZU Benchmark Script

# Functions

mazu_echo() {
    local input_text="$*"
    echo -e "\e[1;30;44mMazu:\e[0m $input_text."
}

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --setup    Clone DeathStarBench under ./workspace and bootstrap socialNetwork"
    echo "  -h, --help Show this help"
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Parse flags before logging so bad input does not leave a log behind
setup_flag=false

for arg in "$@"; do
    case $arg in
        --setup) setup_flag=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            mazu_echo "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

if [[ "$setup_flag" == "false" ]]; then
    usage
    exit 1
fi

# Logging: mirror all output to logs/
mazu_log_dir="$(dirname "$SCRIPT_DIR")/logs"
mkdir -p "$mazu_log_dir"
mazu_log_name="benchmark-$(date +%Y%m%d-%H%M%S)-$(IFS=_; echo "${*#--}")"
export MAZU_LOG_FILE="$mazu_log_dir/$mazu_log_name.log"
exec > >(tee -a "$MAZU_LOG_FILE") 2>&1

export MAZU_WORKSPACE_DIR="$PWD/workspace"
export MAZU_DSB_DIR="$MAZU_WORKSPACE_DIR/DeathStarBench"
export MAZU_SN_DIR="$MAZU_DSB_DIR/socialNetwork"

setup() {
    if [[ ! -d $MAZU_WORKSPACE_DIR ]]; then
        mazu_echo "Creating workspace directory"
        mkdir -p $MAZU_WORKSPACE_DIR
    fi

    if [[ ! -d $MAZU_DSB_DIR ]]; then
        mazu_echo "Cloning DeathStarBench repo"
        git clone https://github.com/etclab/DeathStarBench.git $MAZU_DSB_DIR
        git -C $MAZU_DSB_DIR fetch
        git -C $MAZU_DSB_DIR switch "cloudlab-dev"
    else
        mazu_echo "Pulling DeathStarBench repo"
        git -C $MAZU_DSB_DIR pull
    fi

    # wrk2 needs its LuaJIT submodule (wrk2/deps/luajit) to build
    mazu_echo "Updating DeathStarBench submodules"
    git -C $MAZU_DSB_DIR submodule update --init --recursive

    mazu_echo "Bootstrapping socialNetwork"
    "$MAZU_SN_DIR/bootstrap.sh"
}

mazu_echo "Start of Script"

mazu_echo "Logging to $MAZU_LOG_FILE"

if [[ "$setup_flag" == "true" ]]; then
    setup
fi

mazu_echo "End of Script"
