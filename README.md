Artifact repository for "Mazu: Keyless Workload Authentication for Service Meshes"

0. Step 0: Repository setup
    - Clone artifact repository with: `git clone https://github.com/etclab/mazu-artifact.git`
    - All scripts are run from inside project root: `cd mazu-artifact`

1. Step 1: Clone source files, and build images for istio and envoy
    - First run `./scripts/bootstrap.sh` to install Go, Docker, and login to Docker Hub.
        - Docker Hub login is used to push the built istio images. Use `--skip-docker-login` to skip login.
        - In case of `permission denied error with docker`, either run: `newgrp docker` or logout and log back in.
    - (Note: the next step can be skipped as the required images have been built and publicly available under docker user: `atosh502`. Use the below steps for creating the images from source and hosting it under a different docker user registry.)
    - In order to build and host images in Docker: `DOCKER_USER=<user-id> ./scripts/setup-system.sh configure build-envoy build-istio`
        - Duration: ~30mins, Size: ~50GB.

2. Step 2: Setup and run benchmarks
    - Run `./scripts/benchmark.sh --setup` to clone required source files and benchmark scripts under: `./workspace`
    - Each figure (and the Section 7.4 results) can be reproduced in one of two modes:
        - `--plot-only`: plot the figures from the paper's data without running the experiment. Outputs are written to: `./plots/<name>/outputs/paper`
        - `--run`: run a small scale version of the experiment and plot its results. Outputs are written to: `./plots/<name>/outputs/run`
        - (Note: the `./scripts/benchmark.sh` only runs a scaled down version of the benchmarks as the complete runs (repeated 10 times) take ~48 hours to run)

    | Result | `--plot-only` (paper data) | `--run` (small scale run) | Output files |
    |---|---|---|---|
    | Figure 2: crypto scheme microbenchmarks | `./scripts/benchmark.sh --plot-only --fig2` | `./scripts/benchmark.sh --run --fig2` | `fig2-crypto-scheme-microbenchmarks.pdf` |
    | Figure 3: RBE microbenchmarks | `./scripts/benchmark.sh --plot-only --fig3` | `./scripts/benchmark.sh --run --fig3` | `fig3-rbe-microbenchmarks.pdf` |
    | Figure 6: SocialNetwork latency, ready pods, CPU and memory | `./scripts/benchmark.sh --plot-only --fig6` | `./scripts/benchmark.sh --run --fig6` | `fig6a-end-to-end-latency.pdf`, `fig6b-total-ready-pods.pdf`, `fig6c-cpu-utilization.pdf`, `fig6d-memory-utilization.pdf` |
    | Figure 7: replica scaling p99 latency, CPU and memory | `./scripts/benchmark.sh --plot-only --fig7` | `./scripts/benchmark.sh --run --fig7` | `fig7a-p99-latency.pdf`, `fig7b-mazu-p99-latency-by-scale.pdf`, `fig7c-cpu-utilization.pdf`, `fig7d-memory-utilization.pdf` |
    | Figure 8: cold path latency, CPU and memory | `./scripts/benchmark.sh --plot-only --fig8` | `./scripts/benchmark.sh --run --fig8` | `fig8a-e2e-latency.pdf`, `fig8b-latency-breakdown-for-fortio-server.pdf`, `fig8c-cpu-utilization.pdf`, `fig8d-memory-utilization.pdf` |
    | Section 7.4: TPM microbenchmarks (printed to the terminal) | `./scripts/benchmark.sh --plot-only --sec7.4` | `./scripts/benchmark.sh --run --sec7.4` | `swtpm-bench.txt` |
