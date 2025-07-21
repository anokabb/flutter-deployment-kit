#!/usr/bin/env bash
# Functions related to validating and loading environment variables.

# This script expects to be *sourced* after the environment file has
# already been shell-sourced into the current shell.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# check_env_vars <platform>
# Validates that all required env vars are set for the specified platform.
check_env_vars() {
  local platform="$1"
  local missing=()

  # ---------- Required shared variables ----------
  [[ -z "$PACKAGE_NAME" ]] && missing+=(PACKAGE_NAME)

  # ---------- Android keystore ----------
  [[ -z "$KEYSTORE" ]] && missing+=(KEYSTORE)
  [[ -z "$KEYSTORE_PASSWORD" ]] && missing+=(KEYSTORE_PASSWORD)
  [[ -z "$KEY_PASSWORD" ]] && missing+=(KEY_PASSWORD)
  [[ -z "$KEY_ALIAS" ]] && missing+=(KEY_ALIAS)

  # ---------- Platform-specific ---------
  if [[ "$platform" == "android" || "$platform" == "all" ]]; then
    [[ -z "$PLAYSTORE_KEY" ]] && missing+=(PLAYSTORE_KEY)
  fi

  if [[ "$platform" == "huawei" || "$platform" == "all" ]]; then
    # Only check Huawei credentials if Huawei support is enabled
    if [[ "${HUAWEI_ENABLED:-true}" == "true" ]]; then
      [[ -z "$HUAWEI_APP_ID" ]] && missing+=(HUAWEI_APP_ID)
      [[ -z "$HUAWEI_CLIENT_ID" ]] && missing+=(HUAWEI_CLIENT_ID)
      [[ -z "$HUAWEI_CLIENT_SECRET" ]] && missing+=(HUAWEI_CLIENT_SECRET)
    fi
  fi

  if [[ "$platform" == "ios" || "$platform" == "all" ]]; then
    [[ -z "$APP_STORE_CONNECT_KEY_ID" ]] && missing+=(APP_STORE_CONNECT_KEY_ID)
    [[ -z "$APP_STORE_CONNECT_ISSUER_ID" ]] && missing+=(APP_STORE_CONNECT_ISSUER_ID)
    [[ -z "$APP_STORE_CONNECT_KEY_CONTENT" ]] && missing+=(APP_STORE_CONNECT_KEY_CONTENT)
    [[ -z "$IOS_APP_IDENTIFIER" ]] && missing+=(IOS_APP_IDENTIFIER)
    [[ -z "$IOS_APPLE_ID" ]] && missing+=(IOS_APPLE_ID)
    [[ -z "$IOS_TEAM_ID" ]] && missing+=(IOS_TEAM_ID)
    [[ -z "$IOS_ITC_TEAM_ID" ]] && missing+=(IOS_ITC_TEAM_ID)
  fi

  # ---------- Shared services ----------
  if [[ "${BROWSERSTACK_ENABLED:-true}" == "true" ]]; then
    [[ -z "$BROWSERSTACK_API_USERNAME" ]] && missing+=(BROWSERSTACK_API_USERNAME)
    [[ -z "$BROWSERSTACK_API_PASSWORD" ]] && missing+=(BROWSERSTACK_API_PASSWORD)
  fi

  if [[ "${SLACK_NOTIFICATIONS_ENABLED:-true}" == "true" ]]; then
    [[ -z "$SLACK_TOKEN" ]] && missing+=(SLACK_TOKEN)
    [[ -z "$SLACK_CHANNEL" ]] && missing+=(SLACK_CHANNEL)
    [[ -z "$USER_TO_TAG" ]] && missing+=(USER_TO_TAG)
  fi

  if (( ${#missing[@]} )); then
    log ERROR "Missing required environment variables: ${missing[*]}"
    return 1
  fi
}

return 0 