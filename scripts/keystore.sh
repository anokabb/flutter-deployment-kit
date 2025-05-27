#!/usr/bin/env bash
# Functions for configuring the Android keystore file based on the branch.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# setup_keystore <branch>
setup_keystore() {
  local branch="$1"
  log INFO "Setting up keystore (branch=$branch)"

  local key_props_path="$PROJECT_ROOT/android/key.properties"
  local keystore_dest="$PROJECT_ROOT/android/app"
  mkdir -p "$keystore_dest"

  if [[ "$branch" == "master" ]]; then
    printf '%s\n' \
      "storePassword=$PRODUCTION_KEYSTORE_PASSWORD" \
      "keyPassword=$PRODUCTION_KEY_PASSWORD" \
      "keyAlias=$PRODUCTION_KEY_ALIAS" \
      "storeFile=master-upload.keystore" > "$key_props_path"

    echo "$PRODUCTION_KEYSTORE" | base64 --decode > "$keystore_dest/master-upload.keystore"
  else
    printf '%s\n' \
      "storePassword=$DEV_KEYSTORE_PASSWORD" \
      "keyPassword=$DEV_KEY_PASSWORD" \
      "keyAlias=$DEV_KEY_ALIAS" \
      "storeFile=upload.keystore" > "$key_props_path"

    echo "$DEV_KEYSTORE" | base64 --decode > "$keystore_dest/upload.keystore"
  fi
}

return 0 