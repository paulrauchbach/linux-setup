#!/bin/bash

set -euo pipefail

: "${LINUX_SETUP_INSTALL_DIR:?LINUX_SETUP_INSTALL_DIR is not set. Run install.sh.}"
source "$LINUX_SETUP_INSTALL_DIR/install/lib.sh"

# test if run as root
if [ "$EUID" -eq 0 ]; then
  die "Please do not run this script as root."
fi

prompt_for() {
  local var_name="$1"
  local prompt="$2"
  local value

  if [ -n "${!var_name:-}" ]; then
    return
  fi

  if [ -t 0 ]; then
    printf '%s\n' "$prompt"
    IFS= read -r value
  elif [ -e /dev/tty ]; then
    printf '%s\n' "$prompt" > /dev/tty
    IFS= read -r value < /dev/tty
  else
    echo "$var_name is required. Set it in the environment and rerun install.sh." >&2
    exit 1
  fi || {
    echo "Could not read $var_name." >&2
    exit 1
  }

  printf -v "$var_name" '%s' "$value"
}

log_title "Configure user profile"
prompt_for CONFIG_FULL_NAME "Please enter your full name. This will be used to configure certain programs (e.g. git):"
prompt_for CONFIG_EMAIL "Please enter your email address. This will be used to configure certain programs (e.g. git):"

export CONFIG_FULL_NAME
export CONFIG_EMAIL

require_sudo

run_script() {
  local script_path="$1"
  local script_name
  script_name="$(basename "$script_path" .sh)"

  log_step "$script_name"
  source "$script_path"
  log_success "$script_name complete"
}

run_script "$LINUX_SETUP_INSTALL_DIR/install/oh-my-zsh.sh"
run_script "$LINUX_SETUP_INSTALL_DIR/install/terminal.sh"

log_title "Setup complete"
