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
    echo "  --setup      Clone DeathStarBench under ./workspace and bootstrap socialNetwork"
    echo "  --fig8       Figure 8 (requires --plot-only for now)"
    echo "  --plot-only  Only plot the selected figure(s) from the paper's data"
    echo "  -h, --help   Show this help"
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAZU_ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse flags before logging so bad input does not leave a log behind
setup_flag=false
fig8_flag=false
plot_only_flag=false

for arg in "$@"; do
    case $arg in
        --setup) setup_flag=true ;;
        --fig8) fig8_flag=true ;;
        --plot-only) plot_only_flag=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            mazu_echo "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

if [[ "$setup_flag" == "false" && "$fig8_flag" == "false" ]]; then
    usage
    exit 1
fi

if [[ "$fig8_flag" == "true" && "$plot_only_flag" == "false" ]]; then
    mazu_echo "Running the fig8 experiment is not supported yet; use --fig8 --plot-only"
    exit 1
fi

# Logging: mirror all output to logs/
mazu_log_dir="$MAZU_ROOT_DIR/logs"
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

# Plots fig8 with the paper's gnuplot scripts. They emit EPS (as in the paper),
# which is converted to PDF with ps2pdf.
plot_fig8() {
    local fig8_dir="$MAZU_ROOT_DIR/plots/fig8"
    local data_dir="$fig8_dir/data-paper"
    local output_dir="$fig8_dir/outputs/paper"

    for cmd in gnuplot ps2pdf; do
        if ! command -v $cmd &> /dev/null; then
            mazu_echo "$cmd not found; install it with: sudo apt-get install -y gnuplot ghostscript"
            exit 1
        fi
    done

    mkdir -p "$output_dir"

    for gpi in "$fig8_dir"/scripts/plot_cold_path_*.gpi; do
        mazu_echo "Plotting $(basename "$gpi")"
        gnuplot -e "script_dir='$fig8_dir/scripts'; data_dir='$data_dir'; output_dir='$output_dir'" "$gpi"
    done

    for eps in "$output_dir"/fig8*.eps; do
        ps2pdf -dEPSCrop "$eps" "${eps%.eps}.pdf"
        rm "$eps"
    done

    mazu_echo "Fig8 plots written to $output_dir"
}

mazu_echo "Start of Script"

mazu_echo "Logging to $MAZU_LOG_FILE"

if [[ "$setup_flag" == "true" ]]; then
    setup
fi

if [[ "$fig8_flag" == "true" ]]; then
    plot_fig8
fi

mazu_echo "End of Script"
