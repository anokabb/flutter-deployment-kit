#!/usr/bin/env bash
# Common utility functions used by deployment scripts.
# This file is *sourced* by other scripts and therefore must not execute any code
# other than function / variable definitions.

# ------------------------------------------------------
# Colour codes for prettier terminal output
# ------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# If the parent script does not specify a log file, fall-back to tmp
export LOG_FILE="${LOG_FILE:-/tmp/deploy.log}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Create a new log file for each build with timestamp
if [[ "$LOG_FILE" == "/tmp/deploy.log" ]]; then
  # Get the directory of the original log file
  local log_dir="$(dirname "$LOG_FILE")"
  # Create a new log file with timestamp
  export LOG_FILE="${log_dir}/deploy_$(date '+%Y%m%d_%H%M%S').log"
  # Create the directory if it doesn't exist
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
fi

# ------------------------------------------------------
# Logging helper
# ------------------------------------------------------
log() {
  local level="$1"; shift || true
  local emoji=""
  case "$level" in
    INFO)  emoji="ℹ️  " ;;
    ERROR) emoji="❌  " ;;
    WARN)  emoji="⚠️  " ;;
    DEBUG) emoji="🔍  " ;;
  esac

  # Add separator line with timestamp at the start of each deployment
  if [[ "$level" == "INFO" && "$*" == *"Deployment script v"* ]]; then
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    printf "\n%s\n" "$timestamp ----------------------------------------" | tee -a "$LOG_FILE"
  fi

  # Add separator line with timestamp at the start of each deployment
  if [[ "$level" == "INFO" && "$*" == *"🔧 DEBUG mode"* ]]; then
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    printf "\n%s\n" "$timestamp ----------------------------------------" | tee -a "$LOG_FILE"
  fi

  # Ensure proper spacing between timestamp, level, emoji and message
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] ${emoji}$*"
  # Use printf instead of echo for better control over formatting
  printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------
# Securely delete files (uses `shred` when available)
# ------------------------------------------------------
secure_delete() {
  local target="$1"
  if command -v shred >/dev/null 2>&1; then
    shred -u "$target"
  else
    rm -f "$target"
  fi
}

# ------------------------------------------------------
# Cleanup handler.  The caller can set `$EXTRA_CLEANUP_FUN` to run
# additional cleanup steps (e.g. removal of temp keys)
# ------------------------------------------------------
cleanup() {
  log INFO "Cleaning up temporary artifacts ..."
  if [[ -n "${EXTRA_CLEANUP_FUN:-}" ]]; then
    eval "$EXTRA_CLEANUP_FUN"
  fi
}

# ------------------------------------------------------
# Generic requirement checker
# ------------------------------------------------------
check_requirements() {
  local -a required=(jq curl git base64 fvm)
  # terminal-notifier only exists on macOS; add conditionally
  if [[ "$OSTYPE" == "darwin"* ]]; then
    required+=(terminal-notifier)
  fi
  local missing=()
  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} )); then
    log ERROR "Missing required commands: ${missing[*]}";
    return 1
  fi
}

# ------------------------------------------------------
# Error trap helper – call with: `trap 'trap_error $LINENO' ERR`
# ------------------------------------------------------
trap_error() {
  local exit_code="$?"
  local lineno="$1"
  log ERROR "Error occurred at line $lineno (exit $exit_code)"
  cleanup
  exit "$exit_code"
}

# Ensure the file can be sourced multiple times safely.
return 0 