#!/bin/bash
set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
# https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: runfiles.bash initializer cannot find $f. An executable rule may have forgotten to expose it in the runfiles, or the binary may require RUNFILES_DIR to be set."; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

IMAGE_TAG="${IMAGE_TAG:-}"
CLUSTER_NAME="${CLUSTER_NAME:-chat-app}"
LOADER="${LOADER:-}"  # path to the oci_load runner binary

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG not set"
  exit 1
fi

if [ -z "$LOADER" ]; then
  echo "ERROR: LOADER not set"
  exit 1
fi

echo "LOADER: $LOADER"

# Step 1: load image into Docker/Podman daemon
echo "Loading image into daemon..."
"$LOADER"

# Step 2: load from daemon into Kind cluster
echo "Loading image '$IMAGE_TAG' into kind cluster '$CLUSTER_NAME'..."
kind load docker-image "$IMAGE_TAG" --name "$CLUSTER_NAME"

echo "Done."