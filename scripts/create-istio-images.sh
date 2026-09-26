#!/bin/bash
set -e

# create istio images for multiple strategies: st2-NIChaRes, st3-TokRev, st4-AudUpd, st5-AttUpd

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ISTIO_DIR="$SCRIPT_DIR/workspace/istio"

STRATEGIES=("st2-NIChaRes" "st3-TokRev" "st4-AudUpd" "st5-AttUpd")

for STRATEGY in "${STRATEGIES[@]}"; do
    echo "=== Building Istio image for $STRATEGY ==="

    # Checkout the strategy branch (st3-TokRev uses st2-NIChaRes branch)
    if [[ "$STRATEGY" == "st3-TokRev" ]]; then
        BRANCH="st2-NIChaRes-v3"
    else
        BRANCH="${STRATEGY}-v3"
    fi
    git -C "$ISTIO_DIR" checkout "$BRANCH"

    # Build the istio image with the strategy TAG
    GOTOOLCHAIN=auto TAG="$STRATEGY" "$SCRIPT_DIR/build-system.sh" build-istio

    echo "=== Completed $STRATEGY ==="
done

echo "All Istio images created successfully"