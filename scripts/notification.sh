#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# show_mac_notification <app_name> <platform> <session_url>
show_mac_notification() {
  local app_name="$1"
  local platform="$2"
  local session_url="$3"
  local current_datetime
  current_datetime=$(date +"%Y-%m-%d %H:%M") # Get date and time in YYYY-MM-DD HH:MM format

  # Only macOS supports terminal-notifier
  if [[ "$OSTYPE" != "darwin"* ]]; then
    log INFO "Not on macOS, skipping terminal notification."
    return 0
  fi

  if ! command -v terminal-notifier >/dev/null 2>&1; then
    log WARN "'terminal-notifier' not found. Install via: brew install terminal-notifier"
    return 0
  fi

  local message="✅ Deployed to $platform | $current_datetime"
  local notifier_args=()
  notifier_args+=(-title "🚀 $app_name")
  notifier_args+=(-message "$message")
  if [[ -n "$session_url" ]]; then
    notifier_args+=(-open "$session_url")
  fi
  notifier_args+=(-sound default)
  notifier_args+=(-activate "com.apple.Terminal")
  notifier_args+=(-ignoreDnD)

  log INFO "Sending notification: Title='🚀 $app_name', Message='$message', Open='$session_url'"
  terminal-notifier "${notifier_args[@]}"
}

# If the script is executed directly (not sourced) and the first argument is "show_mac_notification",
# then call the function with the subsequent arguments.
# This allows the script to be sourced by other scripts AND executed directly for testing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ "$1" == "show_mac_notification" ]]; then
  show_mac_notification "$2" "$3" "$4"
fi

# No 'return 0' at the end of the script if it might be run directly. 


# Test the script by running it directly:
# ./deployment/scripts/notification.sh show_mac_notification "Test App" "iOS" "https://www.google.com"