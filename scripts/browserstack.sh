#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CURL_TIMEOUT=${CURL_TIMEOUT:-60}

# upload_to_browserstack <platform> <new_app_path>
# Sets global APP_ID, SESSION_URL and MESSAGE_TEXT env vars.
upload_to_browserstack() {
  local platform="$1"; shift
  NEW_APP_PATH="$1"

  log INFO "Uploading $NEW_APP_PATH to BrowserStack ..."

  local response
  response=$(curl --max-time "$CURL_TIMEOUT" -s -w "\n%{http_code}" -u "$BROWSERSTACK_API_USERNAME:$BROWSERSTACK_API_PASSWORD" \
    -X POST "https://api-cloud.browserstack.com/app-live/upload" \
    -F "file=@${NEW_APP_PATH}")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$ d')

  if [[ "$http_code" != "200" ]]; then
    log ERROR "BrowserStack upload failed with HTTP $http_code: $body"
    return 1
  fi

  APP_ID=$(echo "$body" | jq -r '.app_url' | sed 's/bs:\/\///')
  if [[ -z "$APP_ID" ]]; then
    log ERROR "Unable to extract APP_ID from BrowserStack response"
    return 1
  fi

  # Build session URL depending on platform
  if [[ "$platform" == "ios" ]]; then
    SESSION_URL="https://app-live.browserstack.com/dashboard#os=iOS&os_version=17.0&device=iPhone+15&app_hashed_id=${APP_ID}&scale_to_fit=true&speed=1&start=true"
  elif [[ "$platform" == "huawei" ]]; then
    SESSION_URL="https://app-live.browserstack.com/dashboard#os=android&os_version=12.0&device=Huawei+P30&app_hashed_id=${APP_ID}&scale_to_fit=true&speed=1&start=true"
  else
    SESSION_URL="https://app-live.browserstack.com/dashboard#os=android&os_version=12.0&device=Samsung+Galaxy+S22&app_hashed_id=${APP_ID}&scale_to_fit=true&speed=1&start=true"
  fi

  export APP_ID SESSION_URL

  # Prepare message text (caller may customise later)
  MESSAGE_TEXT="<@$USER_TO_TAG> BrowserStack QA link for session <${SESSION_URL}|${APP_NAME}>"

  # Add Google Play link for test_app branch if it's Android
  if [[ "$platform" == "android" && "$BRANCH" == "test_app" && -n "$DEV_USER_ID" && -n "$GOOGLE_PLAY_LINK_TEST_APP" ]]; then
    MESSAGE_TEXT="$MESSAGE_TEXT \n <@$DEV_USER_ID> Submit App to Google Play: <${GOOGLE_PLAY_LINK_TEST_APP}|Submit>"

  fi

  echo "$MESSAGE_TEXT"
}

return 0 