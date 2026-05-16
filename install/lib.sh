#!/bin/bash

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  bold=$'\033[1m'
  dim=$'\033[2m'
  red=$'\033[31m'
  green=$'\033[32m'
  yellow=$'\033[33m'
  blue=$'\033[34m'
  reset=$'\033[0m'
else
  bold=""
  dim=""
  red=""
  green=""
  yellow=""
  blue=""
  reset=""
fi

log_title() {
  printf '\n%s%s%s\n' "$bold" "$*" "$reset"
}

log_step() {
  printf '\n%s==>%s %s\n' "$blue" "$reset" "$*"
}

log_info() {
  printf '  %s-%s %s\n' "$dim" "$reset" "$*"
}

log_success() {
  printf '  %sOK%s %s\n' "$green" "$reset" "$*"
}

log_warn() {
  printf '  %sWARN%s %s\n' "$yellow" "$reset" "$*" >&2
}

log_error() {
  printf '  %sERROR%s %s\n' "$red" "$reset" "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

run_quiet() {
  local message="$1"
  shift

  local log_file
  log_file="$(mktemp)"

  printf '  %s... ' "$message"
  if "$@" > "$log_file" 2>&1; then
    printf '%sOK%s\n' "$green" "$reset"
    rm -f "$log_file"
    return 0
  fi

  printf '%sFAILED%s\n' "$red" "$reset"
  log_error "$message failed. Command output:"
  sed 's/^/    /' "$log_file" >&2
  rm -f "$log_file"
  return 1
}

require_sudo() {
  log_step "Checking sudo access"
  sudo -v

  if [ -z "${SUDO_KEEPALIVE_PID:-}" ]; then
    while true; do
      sudo -n true
      sleep 60
    done 2>/dev/null &
    SUDO_KEEPALIVE_PID="$!"
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
  fi
}
