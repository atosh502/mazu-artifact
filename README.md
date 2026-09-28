## Artifact repository for "Mazu: Keyless Workload Authentication for Service Meshes"

### Artifact Evaluation Setup Instructions
- A sample CloudLab parameter set consisting of 4 d430 nodes (k8s profile, with containerd as the container runtime) can be created using [this link](https://www.cloudlab.us/p/emulab-ops/k8s&rerun_paramset=14016367-6ee0-4461-bc0a-1867ee8ffdcb). Clicking the link allows a user to set up a 4-node Kubernetes cluster for running the experiments. Once all the nodes become `Ready` and startup services have `Finished`, SSH into `node-0` and run Steps 0 through 2 above to evaluate the artifact.

### Step 0: Repository setup
- Clone artifact repository with: `git clone https://github.com/etclab/mazu-artifact.git`
- All scripts are run from inside the project root: `cd mazu-artifact`

### Step 1: Clone source files and build images for Istio and Envoy
- First run `./scripts/bootstrap.sh` to install Go and Docker, and log in to Docker Hub.
    - Docker Hub login is used to push the built Istio images. Use `--skip-docker-login` to skip the login.
    - If you get a `permission denied` error with Docker, either run `newgrp docker` or log out and log back in.
- (Note: the next step can be skipped, as the required images have already been built and are publicly available under the Docker user `atosh502`. Use the steps below to build the images from source and host them under a different Docker user's registry.)
- To build the images and host them on Docker Hub: `DOCKER_USER=<user-id> ./scripts/setup-system.sh configure build-envoy build-istio`
    - Duration: ~30 mins, Size: ~50 GB.

### Step 2: Set up and run benchmarks
- Run `./scripts/benchmark.sh --setup` to clone the required source files and benchmark scripts into `./workspace`.
- Each figure (and the Section 7.4 results) can be reproduced in one of two modes:
    - `--plot-only`: plot the figures from the paper's data without running the experiment. Outputs are written to `./plots/<name>/outputs/paper`.
    - `--run`: run a small-scale version of the experiment and plot its results. Outputs are written to `./plots/<name>/outputs/run`.
    - (Note: `./scripts/benchmark.sh` only runs a scaled-down version of the benchmarks, as the complete runs (repeated 10 times) take ~48 hours.)

| Result | `--plot-only` (paper data) | `--run` (small-scale run) | Output files |
|---|---|---|---|
| Figure 2: crypto scheme microbenchmarks | `./scripts/benchmark.sh --plot-only --fig2` | `./scripts/benchmark.sh --run --fig2` | `fig2-crypto-scheme-microbenchmarks.pdf` |
| Figure 3: RBE microbenchmarks | `./scripts/benchmark.sh --plot-only --fig3` | `./scripts/benchmark.sh --run --fig3` | `fig3-rbe-microbenchmarks.pdf` |
| Figure 6: SocialNetwork latency, ready pods, CPU and memory | `./scripts/benchmark.sh --plot-only --fig6` | `./scripts/benchmark.sh --run --fig6` | `fig6a-end-to-end-latency.pdf`, `fig6b-total-ready-pods.pdf`, `fig6c-cpu-utilization.pdf`, `fig6d-memory-utilization.pdf` |
| Figure 7: replica scaling p99 latency, CPU and memory | `./scripts/benchmark.sh --plot-only --fig7` | `./scripts/benchmark.sh --run --fig7` | `fig7a-p99-latency.pdf`, `fig7b-mazu-p99-latency-by-scale.pdf`, `fig7c-cpu-utilization.pdf`, `fig7d-memory-utilization.pdf` |
| Figure 8: cold path latency, CPU and memory | `./scripts/benchmark.sh --plot-only --fig8` | `./scripts/benchmark.sh --run --fig8` | `fig8a-e2e-latency.pdf`, `fig8b-latency-breakdown-for-fortio-server.pdf`, `fig8c-cpu-utilization.pdf`, `fig8d-memory-utilization.pdf` |
| Section 7.4: TPM microbenchmarks (printed to the terminal) | `./scripts/benchmark.sh --plot-only --sec7.4` | `./scripts/benchmark.sh --run --sec7.4` | `swtpm-bench.txt` |

