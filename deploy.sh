#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Modular Deployment Script
# ---------------------------------------------------------------------------
# This script is a thin orchestrator that wires together a set of reusable
# helper scripts located in `deployment/scripts/`.  Copy the entire deployment
# folder to a different Flutter project, adjust `deploy.env`, and you are ready
# to ship 🚀.
# ---------------------------------------------------------------------------
set -euo pipefail

VERSION="2.0.0"

# ----------------------------------------
# Directory plumbing
# ----------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
export PROJECT_ROOT

HELPER_DIR="$SCRIPT_DIR/scripts"
LOG_FILE="$SCRIPT_DIR/logs/deploy.log"
export LOG_FILE

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Sensitive files to remove on exit
EXTRA_CLEANUP_FUN='if [[ -f "$PROJECT_ROOT/android/playstore.json" ]]; then secure_delete "$PROJECT_ROOT/android/playstore.json"; fi; if [[ -f "$PROJECT_ROOT/ios/AppStoreConnect.p8" ]]; then secure_delete "$PROJECT_ROOT/ios/AppStoreConnect.p8"; fi'

# ----------------------------------------
# Source helper libraries
# ----------------------------------------
# shellcheck source=deployment/scripts/common.sh
source "$HELPER_DIR/common.sh"
# shellcheck source=deployment/scripts/env_check.sh
source "$HELPER_DIR/env_check.sh"
# shellcheck source=deployment/scripts/keystore.sh
source "$HELPER_DIR/keystore.sh"
# shellcheck source=deployment/scripts/versioning.sh
source "$HELPER_DIR/versioning.sh"
# shellcheck source=deployment/scripts/deploy_platform.sh
source "$HELPER_DIR/deploy_platform.sh"

# Trap unhandled errors so we always cleanup
trap 'trap_error $LINENO' ERR
trap cleanup EXIT INT TERM

# ----------------------------------------
# CLI Argument parsing
# ----------------------------------------
PLATFORM=""
BUILD_NUMBER=""
SKIP_INCREMENT=false
DEBUG=${DEBUG:-false}
BUILD_NAME=""  # Changed from BUILD_PATH to BUILD_NAME
# Optional: CLI-provided TestFlight release notes
CLI_TESTFLIGHT_RELEASE_NOTES=""

usage() {
  echo "Usage: $0 -p <platform(s)> [-n <build_number|current|fix>] [-b <build_name>] [-t <testflight_notes>] [test_flight_note \"notes\"]" >&2
  echo "  -p: Platform(s) to deploy. Options:" >&2
  echo "      - Single: android, huawei, ios" >&2
  echo "      - Multiple: android,ios or android,huawei,ios" >&2
  echo "      - All: all" >&2
  echo "  -n: Build number handling:" >&2
  echo "      - <number>: Use specific build number" >&2
  echo "      - current/fix: Use current build number without incrementing" >&2
  echo "      - (omitted): Increment current build number" >&2
  echo "  -b: Build name (optional - name of the build file in releases directory, e.g. spur-ios-145.ipa)" >&2
  echo "  -t: TestFlight release notes (optional - changelog string passed to TestFlight)" >&2
  echo "      Alternative syntax also supported: test_flight_note \"Your notes...\"" >&2
  echo "" >&2
  echo "Note: Huawei platform can be disabled by setting HUAWEI_ENABLED=false in deploy.env" >&2
  exit 1
}

while getopts "p:n:b:t:" opt; do
  case $opt in
    p) PLATFORM="$OPTARG" ;;
    n)
      BUILD_NUMBER="$OPTARG"
      # Check if it's a special keyword for skipping increment
      if [[ "$BUILD_NUMBER" == "current" || "$BUILD_NUMBER" == "fix" ]]; then
        SKIP_INCREMENT=true
        BUILD_NUMBER=""
      fi
      ;;
    b) BUILD_NAME="$OPTARG" ;;
    t) CLI_TESTFLIGHT_RELEASE_NOTES="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$PLATFORM" ]] && usage

# Parse remaining free-form args for compatibility, e.g.: test_flight_note "..."
shift $((OPTIND - 1))
while [[ $# -gt 0 ]]; do
  case "$1" in
    test_flight_note|testflight_note|--testflight-note)
      shift
      CLI_TESTFLIGHT_RELEASE_NOTES="${1:-}"
      [[ -n "${1:-}" ]] && shift || true
      ;;
    *)
      shift
      ;;
  esac
done

# Validate build name if provided
if [[ -n "$BUILD_NAME" ]]; then
  # Check if file exists in releases directory
  if [[ ! -f "$SCRIPT_DIR/releases/$BUILD_NAME" ]]; then
    log ERROR "Build file not found in releases directory: $BUILD_NAME"
    exit 1
  fi
  
  # Validate file extension
  if [[ ! "$BUILD_NAME" =~ \.(ipa|aab)$ ]]; then
    log ERROR "Invalid build file extension. Must be .ipa or .aab"
    exit 1
  fi
  
  # Export full build path for platform scripts
  export BUILD_PATH="$SCRIPT_DIR/releases/$BUILD_NAME"
  log INFO "Using existing build file: $BUILD_NAME"
fi

# Validate platform(s) - allow single platforms, comma-separated, or "all"
if [[ "$PLATFORM" != "all" ]]; then
  # Split and validate each platform
  IFS=',' read -ra TEMP_PLATFORMS <<< "$PLATFORM"
  for platform in "${TEMP_PLATFORMS[@]}"; do
    platform=$(echo "$platform" | xargs)  # Trim whitespace
    if [[ ! "$platform" =~ ^(android|huawei|ios)$ ]]; then
      log ERROR "Invalid platform: $platform"
      usage
    fi
  
  done
fi

# If build number is provided (and not a skip keyword), validate it
if [[ -n "$BUILD_NUMBER" && "$SKIP_INCREMENT" == "false" ]]; then
[[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]] && usage
fi



# # Check if working directory is clean and up-to-date (skip in DEBUG mode)
# if [[ "$DEBUG" != "true" ]]; then
#   log INFO "Checking git status for clean working directory..."
#   STATUS=$(git -C "$PROJECT_ROOT" status)
#   if [[ $STATUS == *"Your branch is up to date with"* && $STATUS == *"nothing to commit, working tree clean"* ]]; then
#     log INFO "Branch is up-to-date and working directory is clean"
#   else
#     log ERROR "Branch is not up-to-date or there are uncommitted changes. Please push/pull and commit all changes first."
#     log ERROR "Use DEBUG=true to skip this check during development"
#     exit 1
#   fi
# else
#   log INFO "🔧 DEBUG mode: Skipping git status checks"
# fi


# ----------------------------------------
# Load env file
# ----------------------------------------
if [[ -f "$SCRIPT_DIR/deploy.env" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/deploy.env"
else
  log ERROR "deploy.env missing – copy deploy.env.example and configure the values"
  exit 1
fi

# Only accept TestFlight notes from CLI; ignore any from env
if [[ -n "${CLI_TESTFLIGHT_RELEASE_NOTES:-}" ]]; then
  export TESTFLIGHT_RELEASE_NOTES="$CLI_TESTFLIGHT_RELEASE_NOTES"
else
  unset TESTFLIGHT_RELEASE_NOTES || true
fi


# Export additional variables that Fastlane might need
export PACKAGE_NAME
export BUILD_NUMBER
export GOOGLE_PLAY_TRACK="${GOOGLE_PLAY_TRACK:-internal}"
export RELEASE_STATUS="${RELEASE_STATUS:-completed}"
export APP_STORE_CONNECT_KEY_ID
export APP_STORE_CONNECT_ISSUER_ID
export IOS_APP_IDENTIFIER
export IOS_APPLE_ID
export IOS_TEAM_ID
export IOS_ITC_TEAM_ID
export HUAWEI_APP_ID
export HUAWEI_CLIENT_ID
export HUAWEI_CLIENT_SECRET
export HUAWEI_ENABLED="${HUAWEI_ENABLED:-true}"
export BROWSERSTACK_ENABLED="${BROWSERSTACK_ENABLED:-true}"
export SLACK_NOTIFICATIONS_ENABLED="${SLACK_NOTIFICATIONS_ENABLED:-true}"

# Function to filter platforms based on enabled features
filter_platforms() {
  local input_platforms="$1"
  local filtered_platforms=()
  
  # Handle "all" platforms
  if [[ "$input_platforms" == "all" ]]; then
    filtered_platforms+=("android" "ios")
    [[ "$HUAWEI_ENABLED" == "true" ]] && filtered_platforms+=("huawei")
  else
    # Split and filter platforms
    IFS=',' read -ra TEMP_PLATFORMS <<< "$input_platforms"
    for platform in "${TEMP_PLATFORMS[@]}"; do
      platform=$(echo "$platform" | xargs)  # Trim whitespace
      if [[ "$platform" == "huawei" && "$HUAWEI_ENABLED" != "true" ]]; then
        continue
      fi
      filtered_platforms+=("$platform")
    done
  fi
  
  # Return filtered platforms as comma-separated string
  local IFS=','
  echo "${filtered_platforms[*]}"
}

# ----------------------------------------
# Pre-flight checks & setup
# ----------------------------------------
check_requirements

# Log Huawei status if disabled
if [[ "$HUAWEI_ENABLED" != "true" ]]; then
  log WARN "Huawei support is disabled (HUAWEI_ENABLED=false)"
fi

# Filter platforms based on enabled features
FILTERED_PLATFORMS=$(filter_platforms "$PLATFORM")

# Check if we have any platforms left after filtering
if [[ -z "$FILTERED_PLATFORMS" ]]; then
  log ERROR "No platforms available for deployment after filtering"
  exit 1
fi

log INFO "Platforms to deploy: $FILTERED_PLATFORMS"

# Check environment variables for each platform that will be deployed
IFS=',' read -ra PLATFORMS_TO_CHECK <<< "$FILTERED_PLATFORMS"
for platform in "${PLATFORMS_TO_CHECK[@]}"; do
  platform=$(echo "$platform" | xargs)  # Trim whitespace
  check_env_vars "$platform"
done

setup_keystore

# Determine build number: use provided value, current value, or increment current
if [[ "$SKIP_INCREMENT" == "true" ]]; then
  BUILD_NUMBER=$(get_current_build_number)
  log INFO "Using current build number without incrementing: $BUILD_NUMBER"
elif [[ -z "$BUILD_NUMBER" ]]; then
  log INFO "No build number provided, incrementing current build number"
  CURRENT_BUILD_NUMBER=$(get_current_build_number)
  BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))
  log INFO "Using incremented build number: $BUILD_NUMBER"
else
  log INFO "Using provided build number: $BUILD_NUMBER"
fi

update_pubspec_version "$BUILD_NUMBER"

# ----------------------------------------
# Flutter setup
# ----------------------------------------
if [[ -n "${BUILD_PATH:-}" ]]; then
  log INFO "Skipping Flutter setup since we're using an existing build"
else
  log INFO "Running flutter clean & pub get"
  cd "$PROJECT_ROOT" # Ensure we are in the project root
  fvm flutter clean
  fvm flutter pub get
  
  # Run pod install for iOS if it's one of the target platforms
  if [[ "$FILTERED_PLATFORMS" == *"ios"* ]]; then
    log INFO "Running pod install for iOS"
    pushd ios >/dev/null || exit 1
      pod deintegrate || true
      [[ -f Podfile.lock ]] && rm Podfile.lock
      pod install --repo-update
    popd >/dev/null
  fi
fi

# ----------------------------------------
# Deploy 🎉
# ----------------------------------------
# Deploy to filtered platforms in parallel
IFS=',' read -ra PLATFORMS <<< "$FILTERED_PLATFORMS"
deployment_pids=()
deployment_platforms=()

# Start all deployments in parallel
for platform in "${PLATFORMS[@]}"; do
  # Trim whitespace from platform
  platform=$(echo "$platform" | xargs)
  log INFO "Starting deployment for platform: $platform"
  
  # Start deployment in background
  (
    if ! deploy_platform "$platform"; then
      log ERROR "Deployment failed for platform: $platform"
      exit 1
    fi
    log INFO "Successfully completed deployment for platform: $platform"
  ) &
  
  # Store the PID and platform
  deployment_pids+=($!)
  deployment_platforms+=("$platform")
done

# Wait for all deployments to complete and check their status
failed_deployments=0
for i in "${!deployment_pids[@]}"; do
  pid=${deployment_pids[$i]}
  platform=${deployment_platforms[$i]}
  
  # Wait for this deployment to complete
  if wait $pid; then
    log INFO "✅ $platform: Success (Version $(get_full_version))"
  else
    log ERROR "❌ $platform: Failed (Version $(get_full_version))"
    ((failed_deployments++))
  fi
done

# Report final status
if [[ $failed_deployments -eq 0 ]]; then
  log INFO "All platform deployments completed successfully for Version $(get_full_version) ✅"
else
  log ERROR "Some deployments failed for Version $(get_full_version). Exiting with status 1"
  exit 1
fi