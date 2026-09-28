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
    echo "  --setup      Clone DeathStarBench, trinc, ibe, rbe and cryptofun under ./workspace"
    echo "               and bootstrap socialNetwork"
    echo "  --fig2       Figure 2 crypto scheme microbenchmarks (requires --plot-only or --run)"
    echo "  --fig6       Figure 6 (requires --plot-only or --run)"
    echo "  --fig7       Figure 7 (requires --plot-only or --run)"
    echo "  --fig8       Figure 8 (requires --plot-only or --run)"
    echo "  --sec7.4     Section 7.4 TPM microbenchmarks (requires --plot-only or --run)"
    echo "  --plot-only  Only plot the selected figure(s) from the paper's data"
    echo "  --run        Run a short, single-run benchmark for the selected figure(s)"
    echo "               (a correctness check, not the paper's 10-run average)"
    echo "  -h, --help   Show this help"
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAZU_ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse flags before logging so bad input does not leave a log behind
setup_flag=false
fig2_flag=false
fig6_flag=false
fig7_flag=false
fig8_flag=false
sec7_4_flag=false
plot_only_flag=false
run_flag=false

for arg in "$@"; do
    case $arg in
        --setup) setup_flag=true ;;
        --fig2) fig2_flag=true ;;
        --fig6) fig6_flag=true ;;
        --fig7) fig7_flag=true ;;
        --fig8) fig8_flag=true ;;
        --sec7.4) sec7_4_flag=true ;;
        --plot-only) plot_only_flag=true ;;
        --run) run_flag=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            mazu_echo "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

if [[ "$setup_flag" == "false" && "$fig2_flag" == "false" && "$fig6_flag" == "false" && "$fig7_flag" == "false" && "$fig8_flag" == "false" && "$sec7_4_flag" == "false" ]]; then
    usage
    exit 1
fi

if [[ "$plot_only_flag" == "true" && "$run_flag" == "true" ]]; then
    mazu_echo "--plot-only and --run are mutually exclusive"
    exit 1
fi

for fig in fig2 fig6 fig7 fig8 sec7_4; do
    fig_flag="${fig}_flag"
    [[ "${!fig_flag}" == "true" ]] || continue
    if [[ "$plot_only_flag" == "false" && "$run_flag" == "false" ]]; then
        mazu_echo "Select --plot-only or --run for --${fig/_/.}"
        exit 1
    fi
done

# Logging: mirror all output to logs/
mazu_log_dir="$MAZU_ROOT_DIR/logs"
mkdir -p "$mazu_log_dir"
mazu_log_name="benchmark-$(date +%Y%m%d-%H%M%S)-$(IFS=_; echo "${*#--}")"
export MAZU_LOG_FILE="$mazu_log_dir/$mazu_log_name.log"
exec > >(tee -a "$MAZU_LOG_FILE") 2>&1

export MAZU_WORKSPACE_DIR="$PWD/workspace"
export MAZU_DSB_DIR="$MAZU_WORKSPACE_DIR/DeathStarBench"
export MAZU_SN_DIR="$MAZU_DSB_DIR/socialNetwork"
export MAZU_TRINC_DIR="$MAZU_WORKSPACE_DIR/trinc"
export MAZU_IBE_DIR="$MAZU_WORKSPACE_DIR/ibe"
export MAZU_RBE_DIR="$MAZU_WORKSPACE_DIR/rbe"
export MAZU_CRYPTOFUN_DIR="$MAZU_WORKSPACE_DIR/cryptofun"

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

    if [[ ! -d $MAZU_TRINC_DIR ]]; then
        mazu_echo "Cloning trinc repo"
        git clone --branch dev https://github.com/etclab/trinc.git $MAZU_TRINC_DIR
    else
        mazu_echo "Pulling trinc repo"
        git -C $MAZU_TRINC_DIR pull
    fi

    # The Figure 2 crypto scheme microbenchmarks
    if [[ ! -d $MAZU_IBE_DIR ]]; then
        mazu_echo "Cloning ibe repo"
        git clone --branch main https://github.com/etclab/ibe.git $MAZU_IBE_DIR
    else
        mazu_echo "Pulling ibe repo"
        git -C $MAZU_IBE_DIR pull
    fi

    if [[ ! -d $MAZU_RBE_DIR ]]; then
        mazu_echo "Cloning rbe repo"
        git clone --branch bench https://github.com/etclab/rbe.git $MAZU_RBE_DIR
    else
        mazu_echo "Pulling rbe repo"
        git -C $MAZU_RBE_DIR pull
    fi

    if [[ ! -d $MAZU_CRYPTOFUN_DIR ]]; then
        mazu_echo "Cloning cryptofun repo"
        git clone --branch main https://github.com/etclab/cryptofun.git $MAZU_CRYPTOFUN_DIR
    else
        mazu_echo "Pulling cryptofun repo"
        git -C $MAZU_CRYPTOFUN_DIR pull
    fi
}

# Plots a figure with the paper's gnuplot scripts under plots/<fig>/scripts.
# They emit EPS (as in the paper), which is converted to PDF with ps2pdf.
#   $1 = figure name (e.g. fig8), $2 = glob of the scripts to run,
#   $3 = data variant: paper (default) reads data-paper/ and writes
#        outputs/paper/, run reads data-run/ and writes outputs/run/
#   $4 = extra gnuplot assignments passed to every script (optional)
plot_fig() {
    local fig=$1
    local script_glob=$2
    local variant=${3:-paper}
    local extra_vars=${4:-}
    local fig_dir="$MAZU_ROOT_DIR/plots/$fig"
    local data_dir="$fig_dir/data-$variant"
    local output_dir="$fig_dir/outputs/$variant"

    for cmd in gnuplot ps2pdf; do
        if ! command -v $cmd &> /dev/null; then
            mazu_echo "$cmd not found; install it with: sudo apt-get install -y gnuplot ghostscript"
            exit 1
        fi
    done

    mkdir -p "$output_dir"

    for gpi in "$fig_dir"/scripts/$script_glob; do
        mazu_echo "Plotting $(basename "$gpi")"
        gnuplot -e "script_dir='$fig_dir/scripts'; data_dir='$data_dir'; output_dir='$output_dir'; $extra_vars" "$gpi"
    done

    for eps in "$output_dir"/$fig*.eps; do
        ps2pdf -dEPSCrop "$eps" "${eps%.eps}.pdf"
        rm "$eps"
    done

    mazu_echo "${fig^} plots written to $output_dir"
}

# Figure 2: a single run of the go test benchmarks of etclab/rbe, etclab/ibe
# and etclab/cryptofun, as for the paper's data-paper/*-go-benchmark.txt (their
# `make benchmark`), restricted to the benchmarks Figure 2 plots. The tests are
# skipped. RBE sweeps every square number of users up to its -max-users and
# Figure 2 takes the largest; the paper ran -max-users=1024.
#   data-run/         {rbe,ibe,cryptofun}-go-benchmark.txt and all.dat, as in
#                     data-paper/
#   outputs/run/      fig2-crypto-scheme-microbenchmarks.pdf, as in outputs/paper/
#   MAZU_RBE_MAX_USERS overrides RBE's -max-users, a perfect square (default: 100)
FIG2_RBE_MAX_USERS=100

run_fig2() {
    local fig_dir="$MAZU_ROOT_DIR/plots/fig2"
    local data_dir="$fig_dir/data-run"
    local output_dir="$fig_dir/outputs/run"
    local rbe_max_users=${MAZU_RBE_MAX_USERS:-$FIG2_RBE_MAX_USERS}
    local sqrt
    sqrt=$(awk -v n="$rbe_max_users" 'BEGIN { print int(sqrt(n) + 0.5) }')

    if [[ ! "$rbe_max_users" =~ ^[0-9]+$ || $((sqrt * sqrt)) -ne $rbe_max_users || $sqrt -lt 2 ]]; then
        mazu_echo "MAZU_RBE_MAX_USERS must be a perfect square of at least 4, not $rbe_max_users"
        exit 1
    fi
    for dir in "$MAZU_RBE_DIR" "$MAZU_IBE_DIR" "$MAZU_CRYPTOFUN_DIR"; do
        if [[ ! -f "$dir/go.mod" ]]; then
            mazu_echo "$dir not found; run with --setup first"
            exit 1
        fi
    done
    if ! command -v go &> /dev/null; then
        mazu_echo "go not found; install it with ./scripts/bootstrap.sh"
        exit 1
    fi

    # Both directories only ever hold the output of the previous run
    mazu_echo "Clearing $data_dir and $output_dir"
    rm -rf "$data_dir" "$output_dir"
    mkdir -p "$data_dir"

    # The go test -bench patterns match one level of the benchmark name per
    # slash: only the largest number of users runs for RBE, though its sweep
    # still sets up every smaller one
    run_go_bench "$MAZU_RBE_DIR" "$data_dir/rbe-go-benchmark.txt" \
        -bench "^Benchmark(Encrypt|Decrypt|VerifyMembership)\$/-$rbe_max_users\$" \
        -timeout 12h -args -max-users="$rbe_max_users"
    run_go_bench "$MAZU_IBE_DIR" "$data_dir/ibe-go-benchmark.txt" \
        -bench '^Benchmark(Extract|Encrypt|Decrypt)$'
    run_go_bench "$MAZU_CRYPTOFUN_DIR" "$data_dir/cryptofun-go-benchmark.txt" \
        -bench '^Benchmark(GenerateRSAKeyPair|RSASignSHA256|RSAVerifySHA256|GenerateECDSAKeyPair|ECDSASignASN1|ECDSAVerifyASN1|GenerateEd25519KeyPair|Ed25519phSign|Ed2519phVerify)$'

    "$fig_dir/scripts/make-all-dat.sh" "$data_dir"

    plot_fig fig2 "crypto-scheme-*.gpi" run
}

# Runs go test benchmarks (no tests) in a repo, showing the progress and
# keeping the output
#   $1 = repo dir, $2 = output file, $3... = extra go test arguments
run_go_bench() {
    local dir=$1
    local out=$2
    shift 2
    local cmd=(go test -v -run '^$' -benchmem "$@")

    mazu_echo "Running the $(basename "$dir") benchmarks, results in $out"
    echo "${cmd[*]}" > "$out"
    (cd "$dir" && "${cmd[@]}") 2>&1 | tee -a "$out"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        mazu_echo "The $(basename "$dir") benchmarks failed; see $out"
        exit 1
    fi
}

# The run scripts reach the TPM nodes by name (node-0 node-1), which not every
# experiment resolves; default TPM_NODES to the control-plane InternalIPs
resolve_tpm_nodes() {
    if [[ -z "${TPM_NODES:-}" ]]; then
        TPM_NODES=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
            -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{end}')
        export TPM_NODES="${TPM_NODES% }"
    fi
    mazu_echo "TPM nodes: $TPM_NODES"
}

# Removes what a run leaves in the cluster: the run scripts only tear down
# before each arm, so the last arm's workload and mesh stay up. Mirrors their
# teardown: the workload, Prometheus (already gone unless the run failed) and
# the Istio/Mazu mesh. Best effort: the results are on disk by now, so a
# failed step is reported rather than fatal.
#   $1 = workload manifests under socialNetwork/scratch/yaml, space-separated
#   $2 = app labels of the workload pods to wait on, space-separated
teardown_run() {
    local manifests=$1
    local apps=$2
    local args=()
    for manifest in $manifests; do
        args+=(-f "$MAZU_SN_DIR/scratch/yaml/$manifest")
    done

    mazu_echo "Tearing down the workload"
    kubectl delete --ignore-not-found "${args[@]}" || mazu_echo "Could not delete the workload; check kubectl get pods"
    for app in $apps; do
        kubectl wait --for=delete pod -l app="$app" --timeout=300s 2>/dev/null || true
    done

    teardown_mesh
}

# The mesh half of teardown_run, for a workload that is not a set of manifests
teardown_mesh() {
    mazu_echo "Tearing down Prometheus and the mesh"
    "$MAZU_SN_DIR/setup_social_network.sh" uninstall-prometheus || mazu_echo "Could not uninstall Prometheus"
    "$MAZU_SN_DIR/setup_social_network.sh" remove-istio || mazu_echo "Could not remove the mesh; check kubectl get pods -n istio-system"
    kubectl wait --for=delete pod -l app=istiod -n istio-system --timeout=300s 2>/dev/null || true
    kubectl wait --for=delete pod -l app=istio-ingressgateway -n istio-system --timeout=300s 2>/dev/null || true
}

# Figure 6: a single short run of DeathStarBench's
# run-socialnetwork-strategies.sh (Istio vs Mazu st5-AttUpd, wrk2 against
# SocialNetwork, the whole stack rebuilt for every RPS step). The paper pools
# 10 runs at RPS 100-1200, 240s per step (see
# results/sn-strategies-10runs-*); this is only a correctness run at the RPS
# below. The run is pooled with the paper's cld_pool_sn_*.py scripts (stddev
# N/A), and plotted with the paper's gnuplot scripts restricted to that RPS.
#   outputs/run/raw/  everything the sweep writes, plus the pooled .dat files
#   data-run/         sn-scale/ and sn-pod-growth/, as in data-paper/
#   outputs/run/      fig6*.pdf, named as in outputs/paper/
#   MAZU_RUN_DURATION overrides the duration of each RPS step in seconds (default: 60)
FIG6_RPS_VALUES=(100 200 400)
# Directory names the sweep gives the Istio and Mazu arms
FIG6_STRATEGIES=(istio st5-AttUpd)

run_fig6() {
    local fig_dir="$MAZU_ROOT_DIR/plots/fig6"
    local data_dir="$fig_dir/data-run"
    local output_dir="$fig_dir/outputs/run"
    local raw_dir="$output_dir/raw"
    # The pooling scripts pool every sn-strategies-*/ directory under raw/
    local run_dir="$raw_dir/sn-strategies-run01"
    local duration=${MAZU_RUN_DURATION:-60}
    local sweep="$MAZU_SN_DIR/run-socialnetwork-strategies.sh"

    if [[ ! -x "$sweep" ]]; then
        mazu_echo "$sweep not found; run with --setup first"
        exit 1
    fi

    # Both directories only ever hold the output of the previous run
    mazu_echo "Clearing $data_dir and $output_dir"
    rm -rf "$data_dir" "$output_dir"
    mkdir -p "$data_dir" "$raw_dir"

    resolve_tpm_nodes

    mazu_echo "Running the SocialNetwork strategy sweep at RPS ${FIG6_RPS_VALUES[*]}, ${duration}s per step, results in $run_dir"
    # Run from socialNetwork: install-mazu writes istio-install-config.yaml to
    # the cwd. The sweep keeps going when a step fails; pool_fig6_run reports
    # which results are missing.
    if ! (cd "$MAZU_SN_DIR" && RPS_VALUES="${FIG6_RPS_VALUES[*]}" DURATION=$duration \
            RESULTS_DIR="$run_dir" "$sweep"); then
        mazu_echo "The SocialNetwork strategy sweep reported a failure; see $run_dir/run.log"
    fi

    # Mirrors the sweep's own teardown_app: the HPAs are applied outside the
    # helm release, and the gateway is applied outside both
    mazu_echo "Tearing down the workload"
    kubectl delete --ignore-not-found -f "$MAZU_SN_DIR/scratch/yaml/sn-hpa.yaml" || mazu_echo "Could not delete the HPAs"
    helm uninstall social-network --wait --timeout 10m0s 2>/dev/null || true
    kubectl delete --ignore-not-found -f "$MAZU_SN_DIR/kubernetes/istio-gateway.yaml" || mazu_echo "Could not delete the gateway"
    teardown_mesh

    pool_fig6_run "$raw_dir" "$data_dir"

    local rps_values="${FIG6_RPS_VALUES[*]}"
    plot_fig fig6 "sn_*.gpi" run \
        "rps_values='$rps_values'; RPS_LIST='$rps_values'; yauto=1"
}

# Writes the data-paper/ files into data-run/ from the runs under outputs/run/raw
#   $1 = raw dir holding the sn-strategies-*/ run directories, $2 = data dir
pool_fig6_run() {
    local raw_dir=$1
    local data_dir=$2
    local pool_dir="$MAZU_SN_DIR/results/sn-strategies-10runs-09-18-26_161122"

    local missing=false
    for strategy in "${FIG6_STRATEGIES[@]}"; do
        for rps in "${FIG6_RPS_VALUES[@]}"; do
            if ! compgen -G "$raw_dir/sn-strategies-*/$strategy/$rps.txt" > /dev/null; then
                mazu_echo "Missing $strategy/$rps.txt under $raw_dir"
                missing=true
            fi
        done
    done
    for file in plot_sn_pod_growth.dat plot_sn_cpu.dat plot_sn_memory.dat; do
        if ! compgen -G "$raw_dir/sn-strategies-*/$file" > /dev/null; then
            mazu_echo "Missing $file under $raw_dir"
            missing=true
        fi
    done
    if [[ "$missing" == "true" ]]; then
        mazu_echo "Figure 6 run is incomplete; see the run.log under $raw_dir"
        exit 1
    fi

    # The pooling scripts import from socialNetwork relative to their own
    # path, so they run in place and write the pooled files into raw/
    mazu_echo "Pooling one run; warnings about the missing runs are expected"
    for script in cld_pool_sn_latency.py cld_pool_sn_pods.py cld_pool_sn_cpu.py cld_pool_sn_memory.py; do
        python3 "$pool_dir/$script" "$raw_dir"
    done

    mkdir -p "$data_dir/sn-scale/cpu" "$data_dir/sn-scale/mem" "$data_dir/sn-pod-growth"
    cp "$raw_dir"/plot_sn_latency_pooled_{istio,mazu}.dat "$data_dir/sn-scale/"
    cp "$raw_dir"/plot_sn_pod_growth_pooled_{istio,mazu}.dat "$data_dir/sn-pod-growth/"
    cp "$raw_dir"/plot_sn_cpu_pooled_{proxy,istiod,kube_apiserver}.dat "$data_dir/sn-scale/cpu/"
    cp "$raw_dir"/plot_sn_memory_pooled_{proxy,istiod,kube_apiserver}.dat "$data_dir/sn-scale/mem/"
    # The CPU and memory scripts pivot the pooled files with this helper
    cp "$MAZU_ROOT_DIR/plots/fig6/data-paper/sn-scale/cpu/pivot_cpu.awk" "$data_dir/sn-scale/cpu/"

    mazu_echo "Figure 6 data written to $data_dir"
}

# Figure 7: a single short run of DeathStarBench's
# run-benchmark1.5b-replica-scale-sweep.sh (Istio vs Mazu st5-AttUpd, wrk2 RPS
# sweep against a Bookinfo fleet at each replica scale). The paper pools 10
# runs of scales 1x-32x at RPS 100-2000, 120s per step (see
# results/benchmark1.5b-replica-scale-10runs-*); this is only a correctness run
# at the scales and RPS below. The run is pooled with the paper's
# cld_pool_*.py scripts (stddev 0), and plotted with the paper's gnuplot
# scripts restricted to the scales that ran.
#   outputs/run/raw/  everything the sweep writes, plus the pooling scripts
#   data-run/         pooled_latency_by_scale.dat and cld_resource_pooled_*.dat,
#                     as in data-paper/
#   outputs/run/      fig7*.pdf, named as in outputs/paper/
#   MAZU_RUN_DURATION overrides the duration of each RPS step in seconds (default: 60)
FIG7_SCALES=(1 2)
FIG7_RPS_VALUES=(100 200 400)
# Directory names the sweep gives the Istio and Mazu arms
FIG7_STRATEGIES=(istio st5-AttUpd)

run_fig7() {
    local fig_dir="$MAZU_ROOT_DIR/plots/fig7"
    local data_dir="$fig_dir/data-run"
    local output_dir="$fig_dir/outputs/run"
    local raw_dir="$output_dir/raw"
    # The pooling scripts pool every benchmark*/ directory under raw/
    local run_dir="$raw_dir/benchmark1.5b-replica-scale-run01"
    local duration=${MAZU_RUN_DURATION:-60}
    local sweep="$MAZU_SN_DIR/run-benchmark1.5b-replica-scale-sweep.sh"

    if [[ ! -x "$sweep" ]]; then
        mazu_echo "$sweep not found; run with --setup first"
        exit 1
    fi

    # Both directories only ever hold the output of the previous run
    mazu_echo "Clearing $data_dir and $output_dir"
    rm -rf "$data_dir" "$output_dir"
    mkdir -p "$data_dir" "$raw_dir"

    resolve_tpm_nodes

    mazu_echo "Running the replica-scale sweep at scales ${FIG7_SCALES[*]} and RPS ${FIG7_RPS_VALUES[*]}, ${duration}s per step, results in $run_dir"
    # Run from socialNetwork: install-mazu writes istio-install-config.yaml to
    # the cwd. The sweep keeps going when a scale fails and exits non-zero at
    # the end; pool_fig7_run reports which results are missing.
    if ! (cd "$MAZU_SN_DIR" && SCALES="${FIG7_SCALES[*]}" RPS_VALUES="${FIG7_RPS_VALUES[*]}" \
            DURATION=$duration SKIP_PLOT=1 RESULTS_DIR="$run_dir" "$sweep"); then
        mazu_echo "The replica-scale sweep reported a failure; see $run_dir/logs"
    fi

    # Both Bookinfo manifests name the same resources as the scaled copies the
    # sweep applied, so either one deletes the fleet at any scale
    teardown_run "bookinfo-const.yaml bookinfo-const-tpm.yaml bf-gateway.yaml bf-hpa.yaml bf-no-connection-reuse.yaml" \
        "details productpage ratings reviews"

    pool_fig7_run "$raw_dir" "$data_dir"

    local scales="${FIG7_SCALES[*]/%/x}"
    plot_fig fig7 "fixed-resource-*.gpi" run \
        "scales='$scales'; rps_values='${FIG7_RPS_VALUES[*]}'; yauto=1"
}

# Writes the data-paper/ files into data-run/ from the runs under outputs/run/raw
#   $1 = raw dir holding the benchmark*/ run directories, $2 = data dir
pool_fig7_run() {
    local raw_dir=$1
    local data_dir=$2
    local pool_dir="$MAZU_SN_DIR/results/benchmark1.5b-replica-scale-10runs-09-19-26_101910"

    local missing=false
    for scale in "${FIG7_SCALES[@]}"; do
        for strategy in "${FIG7_STRATEGIES[@]}"; do
            for rps in "${FIG7_RPS_VALUES[@]}"; do
                for file in "$rps.txt" "metrics_$rps.json"; do
                    if ! compgen -G "$raw_dir/benchmark*/scale-${scale}x/$strategy/$file" > /dev/null; then
                        mazu_echo "Missing scale-${scale}x/$strategy/$file under $raw_dir"
                        missing=true
                    fi
                done
            done
        done
    done
    if [[ "$missing" == "true" ]]; then
        mazu_echo "Figure 7 run is incomplete; see the logs/ directory under $raw_dir"
        exit 1
    fi

    # The pooling scripts hardcode the paper's RPS ladder and pool the run
    # directories next to them, so a copy with the run's ladder is placed in
    # raw/. They keep the paper's six scales, which fixes the data layout the
    # gnuplot scripts read; the scales that did not run come out as NaN.
    local rps_list
    rps_list=$(IFS=,; echo "${FIG7_RPS_VALUES[*]}")
    for script in cld_pool_replica_scale.py cld_pool_resource_usage.py; do
        sed "s/^RPS_VALUES = \[.*\]$/RPS_VALUES = [$rps_list]/" "$pool_dir/$script" > "$raw_dir/$script"
        if ! grep -qx "RPS_VALUES = \[$rps_list\]" "$raw_dir/$script"; then
            mazu_echo "Could not set RPS_VALUES in $raw_dir/$script"
            exit 1
        fi
    done

    mazu_echo "Pooling one run at scales ${FIG7_SCALES[*]/%/x}; warnings about the missing runs and scales are expected"
    python3 "$raw_dir/cld_pool_replica_scale.py"
    python3 "$raw_dir/cld_pool_resource_usage.py"

    cp "$raw_dir/pooled_replica_scale.dat" "$data_dir/pooled_latency_by_scale.dat"
    cp "$raw_dir"/cld_resource_pooled_{cpu,memory}.dat "$data_dir/"

    mazu_echo "Figure 7 data written to $data_dir"
}

# Figure 8: a single short run of DeathStarBench's run-benchmark2.sh (Istio vs
# Mazu st5-AttUpd, fortio at 100 RPS). The paper averages 10 runs of 240s each
# (see results/benchmark2-10runs-*); this is only a correctness run. The run's
# plot_*.dat files are "averaged" over that one run with the paper's
# cld_avg_data.py (stddev 0), so the paper's gnuplot scripts plot them as-is.
#   outputs/run/raw/  everything run-benchmark2.sh writes
#   data-run/         plot_*_avg.dat, as in data-paper/
#   outputs/run/      fig8*.pdf, named as in outputs/paper/
#   MAZU_RUN_DURATION overrides the load duration in seconds (default: 60)
FIG8_METRICS=(cpu memory e2e_latency latency_breakdown_v2)

run_fig8() {
    local fig_dir="$MAZU_ROOT_DIR/plots/fig8"
    local data_dir="$fig_dir/data-run"
    local output_dir="$fig_dir/outputs/run"
    local raw_dir="$output_dir/raw"
    # cld_avg_data.py averages every *run*/ directory under raw/
    local run_dir="$raw_dir/benchmark2-run01"
    local duration=${MAZU_RUN_DURATION:-60}

    if [[ ! -x "$MAZU_SN_DIR/run-benchmark2.sh" ]]; then
        mazu_echo "$MAZU_SN_DIR/run-benchmark2.sh not found; run with --setup first"
        exit 1
    fi

    # Both directories only ever hold the output of the previous run
    mazu_echo "Clearing $data_dir and $output_dir"
    rm -rf "$data_dir" "$output_dir"
    mkdir -p "$data_dir" "$run_dir"

    resolve_tpm_nodes

    mazu_echo "Running benchmark2 for ${duration}s, results in $run_dir"
    # Run from socialNetwork: install-mazu writes istio-install-config.yaml to
    # the cwd. A failed run still gets torn down; average_fig8_run reports
    # which results are missing.
    if ! (cd "$MAZU_SN_DIR" && DURATION=$duration RESULTS_DIR="$run_dir" ./run-benchmark2.sh); then
        mazu_echo "benchmark2 reported a failure; see the run.log files under $run_dir"
    fi

    teardown_run "fortio.yaml fortio-tpm.yaml fortio-no-connection-reuse.yaml" \
        "fortio-server fortio-client"

    average_fig8_run "$raw_dir" "$data_dir"
    plot_fig fig8 "plot_cold_path_*.gpi" run
}

# Writes data-run/plot_<metric>_avg.dat from the runs under outputs/run/raw
#   $1 = raw dir holding the *run*/ directories, $2 = data dir
average_fig8_run() {
    local raw_dir=$1
    local data_dir=$2
    local avg_script="$MAZU_SN_DIR/results/benchmark2-10runs-09-17-26_080502/cld_avg_data.py"

    local missing=false
    for metric in "${FIG8_METRICS[@]}"; do
        if ! compgen -G "$raw_dir/*run*/plot_$metric.dat" > /dev/null; then
            mazu_echo "Missing plot_$metric.dat under $raw_dir"
            missing=true
        fi
    done
    if [[ "$missing" == "true" ]]; then
        mazu_echo "Figure 8 run is incomplete; see the run.log files under $raw_dir"
        exit 1
    fi

    for metric in "${FIG8_METRICS[@]}"; do
        python3 "$avg_script" "$raw_dir" -m "$metric" -o "$data_dir/plot_${metric}_avg.dat"
    done

    mazu_echo "Figure 8 data written to $data_dir"
}

# Section 7.4: prints the AttestCounter and VerifyCounter timings from the
# trinc TPM microbenchmarks (go test -bench output) with scripts/parse_bench.py
#   $1 = data variant: paper (default) reads data-paper/ and writes
#        outputs/paper/, run reads data-run/ and writes outputs/run/
SEC7_4_BENCHMARKS=(AttestCounter VerifyCounter)

# Section 7.4: a single run of trinc's `make benchmark` (go test -bench against
# the TPM at /dev/tpmrm0), as for the paper's data-paper/swtpm-bench.data
#   outputs/run/raw/  swtpm-bench.data, everything make benchmark prints
#   data-run/         swtpm-bench.data, as in data-paper/
#   outputs/run/      swtpm-bench.txt, as in outputs/paper/
run_sec7_4() {
    local sec_dir="$MAZU_ROOT_DIR/plots/sec7.4"
    local data_dir="$sec_dir/data-run"
    local output_dir="$sec_dir/outputs/run"
    local raw_dir="$output_dir/raw"
    local tpm_path=/dev/tpmrm0

    if [[ ! -f "$MAZU_TRINC_DIR/Makefile" ]]; then
        mazu_echo "$MAZU_TRINC_DIR not found; run with --setup first"
        exit 1
    fi
    if [[ ! -e "$tpm_path" ]]; then
        mazu_echo "$tpm_path not found; the benchmarks need a TPM on this node"
        exit 1
    fi

    # Both directories only ever hold the output of the previous run
    mazu_echo "Clearing $data_dir and $output_dir"
    rm -rf "$data_dir" "$output_dir"
    mkdir -p "$data_dir" "$raw_dir"

    mazu_echo "Running the trinc microbenchmarks against $tpm_path, results in $raw_dir"
    # make runs go test with sudo; tee shows the progress and keeps the output
    (cd "$MAZU_TRINC_DIR" && make benchmark tpmpath="$tpm_path") | tee "$raw_dir/swtpm-bench.data"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        mazu_echo "The trinc microbenchmarks failed; see $raw_dir/swtpm-bench.data"
        exit 1
    fi

    cp "$raw_dir/swtpm-bench.data" "$data_dir/"
    print_sec7_4 run
}

print_sec7_4() {
    local variant=${1:-paper}
    local sec_dir="$MAZU_ROOT_DIR/plots/sec7.4"
    local data_file="$sec_dir/data-$variant/swtpm-bench.data"
    local output_dir="$sec_dir/outputs/$variant"

    if [[ ! -f "$data_file" ]]; then
        mazu_echo "$data_file not found"
        exit 1
    fi

    mkdir -p "$output_dir"

    mazu_echo "Parsing $(basename "$data_file")"
    python3 "$sec_dir/scripts/parse_bench.py" "$data_file" "${SEC7_4_BENCHMARKS[@]}" \
        > "$output_dir/swtpm-bench.txt"
    cat "$output_dir/swtpm-bench.txt"

    mazu_echo "Section 7.4 timings written to $output_dir/swtpm-bench.txt"
}

mazu_echo "Start of Script"

mazu_echo "Logging to $MAZU_LOG_FILE"

if [[ "$setup_flag" == "true" ]]; then
    setup
fi

if [[ "$fig2_flag" == "true" ]]; then
    if [[ "$run_flag" == "true" ]]; then
        run_fig2
    else
        plot_fig fig2 "crypto-scheme-*.gpi"
    fi
fi

if [[ "$fig6_flag" == "true" ]]; then
    if [[ "$run_flag" == "true" ]]; then
        run_fig6
    else
        plot_fig fig6 "sn_*.gpi"
    fi
fi

if [[ "$fig7_flag" == "true" ]]; then
    if [[ "$run_flag" == "true" ]]; then
        run_fig7
    else
        plot_fig fig7 "fixed-resource-*.gpi"
    fi
fi

if [[ "$fig8_flag" == "true" ]]; then
    if [[ "$run_flag" == "true" ]]; then
        run_fig8
    else
        plot_fig fig8 "plot_cold_path_*.gpi"
    fi
fi

if [[ "$sec7_4_flag" == "true" ]]; then
    if [[ "$run_flag" == "true" ]]; then
        run_sec7_4
    else
        print_sec7_4
    fi
fi

mazu_echo "End of Script"
