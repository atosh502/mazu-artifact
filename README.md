

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
    - Run `./scripts/benchmark.sh` to clone required source files and benchmark scripts under: `./workspace`
    - For plotting the figures from paper without running the experiment:
        - Use: `./scripts/benchmark.sh --plot-only --figX` where figX can be `fig2, fig6, fig7 or fig8`.
        - The output figures will be written to: `./plots/figX/outputs/paper`.
    - For running a small scale version of the experiments and generate the figures:
        - Use: `./scripts/benchmark.sh --run --figX` where figX can be `fig2, fig6, fig7 or fig8`.
        - The output figures will be written to: `./plots/figX/outputs/run`


# TODO: what does the full run config looks like?
# TODO: what does the cluster setup looks like? is there a way to get the cluster profile?