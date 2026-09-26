#!/bin/bash
set -e

# Get and print current script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo "Script directory: $SCRIPT_DIR"

ENVOY_DIR="$SCRIPT_DIR/workspace/proxy/envoy"

# Build 1: st2-NIChaRes branch
pushd "$ENVOY_DIR"
git checkout st2-NIChaRes
popd
MAZU_ENVOY_OUTPUT_FILENAME=envoy-st2-NIChaRes "$SCRIPT_DIR/build-system.sh" build-envoy

# Build 2: st3-TokRev branch
pushd "$ENVOY_DIR"
git checkout st3-TokRev
popd
MAZU_ENVOY_OUTPUT_FILENAME=envoy "$SCRIPT_DIR/build-system.sh" build-envoy
