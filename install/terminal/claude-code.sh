#!/bin/bash

if ! command -v claude >/dev/null 2>&1; then
  run_quiet "Installing Claude Code" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
else
  log_info "Claude Code is already installed"
fi

ZSHRC="$HOME/.zshrc"
PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'

if [ ! -f "$ZSHRC" ] || ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$ZSHRC"; then
  echo "$PATH_EXPORT" >> "$ZSHRC"
  log_info "Added ~/.local/bin to PATH in $ZSHRC"
fi
