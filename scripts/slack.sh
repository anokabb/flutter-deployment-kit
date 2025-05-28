#!/usr/bin/env bash
# Helper for sending formatted messages to Slack using chat.postMessage API.

# Set log file to a writable location
export LOG_FILE="${HOME}/.slack_deploy.log"

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CURL_TIMEOUT=${CURL_TIMEOUT:-60}
SLACK_CHANNEL=${SLACK_CHANNEL:-"#general"}

# post_slack_message <message_text>
post_slack_message() {
  local message="$1"

  if [[ -z "${SLACK_TOKEN:-}" ]]; then
    log ERROR "SLACK_TOKEN environment variable is not set"
    return 1
  fi

  if [[ "${DEBUG:-false}" == "true" ]]; then
    log DEBUG "[dry-run] Would send Slack message: $message"
    return 0
  fi

  log INFO "Posting message to Slack ($SLACK_CHANNEL)"

  # Build JSON payload with jq for proper escaping
  local payload
  payload=$(jq -n --arg channel "$SLACK_CHANNEL" --arg text "$message" '{channel:$channel,text:$text,unfurl_links:false,as_user:true}')

  local response
  response=$(curl --max-time "$CURL_TIMEOUT" -s -w "\n%{http_code}" \
      -X POST \
      -H "Authorization: Bearer ${SLACK_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$payload" \
      "https://slack.com/api/chat.postMessage")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$ d')

  if [[ "$http_code" != "200" ]] || [[ "$(echo "$body" | jq -r '.ok')" != "true" ]]; then
    log ERROR "Slack message failed: $body"
    return 1
  fi
}

# test_slack_message <channel> <message>
test_slack_message() {
  local channel="$1"
  local message="$2"
  local slack_token="$3"
  # Usage: test_slack_message <channel> <message> <slack_token>
  # Example: test_slack_message "#general" "Hello world" "xoxb-your-token"
  
  if [[ -z "$channel" || -z "$message" || -z "$slack_token" ]]; then
    log ERROR "Usage: ./slack.sh <channel> <message> <slack_token>"
    log INFO "Example: ./slack.sh '#general' 'Hello world' 'xoxb-your-token'"
    return 1
  fi

  export SLACK_TOKEN="$slack_token"
  
  echo "Testing Slack message:"
  echo "Channel: $channel"
  echo "Message: $message"
  echo "SLACK_TOKEN: $SLACK_TOKEN"
  
  # Temporarily override SLACK_CHANNEL
  local original_channel="$SLACK_CHANNEL"
  SLACK_CHANNEL="$channel"
  post_slack_message "$message"
  local result=$?
  SLACK_CHANNEL="$original_channel"
  return $result
}

# If script is executed directly (not sourced), run the test function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_slack_message "$@"
  exit $?
fi

return 0

# To test the slack message, run the following command: 
# ./slack.sh <channel> <message> <slack_token>