

0. Step 0: Repository setup
    - Clone artifact repository with: `git clone https://github.com/etclab/mazu-artifact.git`
    - All scripts are run from inside project root: `cd mazu-artifact`

1. Step 1: Clone source files, and build images for istio and envoy
    - First run `./scripts/bootstrap.sh` to install Go, Docker, and login to Docker Hub.
        - Docker Hub login is used to push the built istio images. Use `--skip-docker-login` to skip login.
        - In case of `permission denied error with docker`, either run: `newgrp docker` or logout and log back in.
    - (Note: the required images have been built and publicly available under docker user: `atosh502`. Use the below steps for creating the images from source and hosting it under a different docker user registry.)
    - In order to build and host images in Docker: `DOCKER_USER=<user-id> ./setup-system.sh configure build-envoy build-istio`
        - Duration: ~30mins, Size: ~50GB

2. Step 1: Setup benchmarks
    - Run `./setup-system.sh` to clone required source files and benchmark scripts under: `./workspace`