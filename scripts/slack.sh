#!/usr/bin/env bash
# Helper for sending formatted messages to Slack using chat.postMessage API.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CURL_TIMEOUT=${CURL_TIMEOUT:-60}
SLACK_CHANNEL=${SLACK_CHANNEL:-"#general"}

# post_slack_message <message_text>
post_slack_message() {
  local message="$1"

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

return 0