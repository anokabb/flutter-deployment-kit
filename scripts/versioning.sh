#!/usr/bin/env bash
# Functions to update the pubspec version number.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# get_current_build_number
get_current_build_number() {
  local current_build_number
  current_build_number=$(grep -E '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed -E 's/version:[[:space:]]*[^+]*\+([0-9]+).*/\1/')
  
  if [[ -z "$current_build_number" ]]; then
    log ERROR "Unable to determine current build number from pubspec.yaml"
    return 1
  fi
  
  echo "$current_build_number"
}

# update_pubspec_version <build_number>
update_pubspec_version() {
  local build_number="$1"
  log INFO "Updating pubspec.yaml with build number $build_number"

  # Extract semver part (x.y.z) and ignore +nnn build number
  local current_semver
  current_semver=$(grep -E '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed -E 's/version:[[:space:]]*([^+]*)\+.*/\1/')

  if [[ -z "$current_semver" ]]; then
    log ERROR "Unable to determine current version from pubspec.yaml"
    return 1
  fi

  # macOS sed behaves differently vs GNU, handle both
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E "s/^version:.*/version: ${current_semver}+${build_number}/" "$PROJECT_ROOT/pubspec.yaml"
  else
    sed -i -E "s/^version:.*/version: ${current_semver}+${build_number}/" "$PROJECT_ROOT/pubspec.yaml"
  fi

  log INFO "Updated pubspec.yaml to ${current_semver}+${build_number}"
}

return 0 