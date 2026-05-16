#!/bin/bash

set -euo pipefail

: "${HOME:?HOME is not set. Please run as a regular user.}"
: "${LINUX_SETUP_INSTALL_DIR:?LINUX_SETUP_INSTALL_DIR is not set. Run through setup.sh.}"

SOURCE_CONF="$LINUX_SETUP_INSTALL_DIR/configs/tmux/tmux.conf"
TARGET_CONF="$HOME/.tmux.conf"

if [ ! -f "$SOURCE_CONF" ]; then
  echo "tmux config not found at $SOURCE_CONF"
  exit 1
fi

cp "$SOURCE_CONF" "$TARGET_CONF"

log_info "tmux config copied to $TARGET_CONF"
