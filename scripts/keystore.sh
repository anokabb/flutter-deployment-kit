#!/usr/bin/env bash
# Functions for configuring the Android keystore file.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# setup_keystore
setup_keystore() {
  log INFO "Setting up keystore"

  local key_props_path="$PROJECT_ROOT/android/key.properties"
  local keystore_dest="$PROJECT_ROOT/android/app"
  mkdir -p "$keystore_dest"

  printf '%s\n' \
    "storePassword=$KEYSTORE_PASSWORD" \
    "keyPassword=$KEY_PASSWORD" \
    "keyAlias=$KEY_ALIAS" \
    "storeFile=app.keystore" > "$key_props_path"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "$KEYSTORE" | base64 -D > "$keystore_dest/app.keystore"
  else
    echo "$KEYSTORE" | base64 --decode > "$keystore_dest/app.keystore"
  fi
}

return 0 