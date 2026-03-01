#!/usr/bin/env bash
# See https://github.com/bazelbuild/rules_go/wiki/Editor-setup

# This is a custom script to improve the performance of gopackagesdriver.
# Most importantly, it uses a separate output base to avoid contending
# for bazel lock with other bazel commands in the standard output base. 
# BUILD_WORKSPACE_DIRECTORY is automatically set by bazel run --script_path,
# ensuring gopackagesdriver still operates on the same workspace.
# We share the disk cache with the standard output base to reuse action results
# and build outputs.

set -euo pipefail

_CACHE_PREFIX="${HOME}/.cache/chat_app"

# Keep this in sync with .bazelrc --disk_cache flag.
_DISK_CACHE_DIR="${_CACHE_PREFIX}_bazel_disk_cache"

_GOPKGS_DRIVER_DIR="${_CACHE_PREFIX}_gopackagesdriver"

_OUTPUT_BASE="${_GOPKGS_DRIVER_DIR}/output_base"
_RUNSCRIPT="${_GOPKGS_DRIVER_DIR}/bazel-run"
# The last timestamp the runscript was generated.
_RUNSCRIPT_STAMP="${_GOPKGS_DRIVER_DIR}/generated_at"

_LOG="/tmp/gopackagesdriver.log"

_GOPKGS_DRIVER_TARGET="@rules_go//go/tools/gopackagesdriver"

# GOPACKAGESDRIVER_REFRESH=1

TTL_SECONDS=43200 # 12 hours
_NOW="$(date +%s)"

mkdir -p "${_GOPKGS_DRIVER_DIR}"

# Important: NEVER write anything to stdout from this wrapper,
# as it's used to communicate with gopackages/gopls (JSON protocol over stdout).
log() { printf '%s\n' "$*" >> "${_LOG}"; }

is_stale() {
  local last=0
  if [[ -f "${_RUNSCRIPT_STAMP}" ]]; then
    last="$(cat "${_RUNSCRIPT_STAMP}" 2> /dev/null || echo 0)"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
  fi
  ((_NOW - last >= TTL_SECONDS))
}

runfiles_missing() {
  [[ -x "${_RUNSCRIPT}" ]] || return 1
  local runfiles_dir
  # Extract the runfiles directory from the runscript.
  # The 2nd line in that script has the format: "cd ${runfiles_dir} && \"
  # We strip "cd " prefix and " && \" suffix to get the runfiles_dir.
  # if sed fails, we can't conclude if the runfiles is really missing, so we should
  # return 1 (false) i.e consider it NOT missing. This err on the side of caution
  # to avoid spurious regen.
  runfiles_dir="$(sed -n '2s/^cd \(.*\) && \\$/\1/p' "${_RUNSCRIPT}" 2> /dev/null)" || return 1
  [[ -n "${runfiles_dir}" ]] && [[ ! -d "${runfiles_dir}" ]]
}

need_regen() {
  [[ "${GOPACKAGESDRIVER_REFRESH:-}" == "1" ]] || [[ ! -x "${_RUNSCRIPT}" ]] || is_stale || runfiles_missing
}

if need_regen; then
  rm -f "${_RUNSCRIPT_STAMP}"
  # Clear the log file.
  : > "${_LOG}"

  if runfiles_missing; then
    log "[wrapper] regen needed: runfiles directory missing"
  fi
  log "[wrapper] regen needed at ${_NOW}"

  _TMP_RUNSCRIPT="${_RUNSCRIPT}.tmp.$$"

  # Generate a runscript to invoke gopackagesdriver, so we release the bazel lock
  # as soon as the script finishes. Even if this operates in a separate output base,
  # this can help if gopls issues multiple concurrent queries to gopackagesdriver.
  if ! bazel run --script_path="${_TMP_RUNSCRIPT}" ${_GOPKGS_DRIVER_TARGET} \
    >> "${_LOG}" 2>&1; then
    log "Failed to generate run script"
    exit 1
  fi

  mv -f "${_TMP_RUNSCRIPT}" "${_RUNSCRIPT}"

  printf '%s' "${_NOW}" > "${_RUNSCRIPT_STAMP}"
  log "[wrapper] generated runscript at ${_RUNSCRIPT}"
fi

export GOPACKAGESDRIVER_BAZEL_FLAGS="--output_base=${_OUTPUT_BASE}"

# Build flags: disk_cache for faster rebuilds, download_regex ensures .pkg.json
# outputs are retained (gopackagesdriver needs these intermediate outputs).
# Note that --remote_download_regex only matters if we use remote execution, but
# it doesn't hurt to set it for local builds as well.
export GOPACKAGESDRIVER_BAZEL_BUILD_FLAGS="--disk_cache=${_DISK_CACHE_DIR} --remote_download_regex='.*pkg.json'"

export GOPACKAGESDRIVER_BAZEL_QUERY_FLAGS="--order_output=no --loading_phase_threads=8"

# IMPORTANT: again, do NOT redirect stdout.
exec "${_RUNSCRIPT}" "$@" 2>> "${_LOG}"