#!/bin/bash

set -euo pipefail

# install zsh following <https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH>
if ! command -v zsh >/dev/null 2>&1; then
  run_quiet "Installing zsh" sudo apt-get install -y -qq zsh
fi

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  log_info "Changing default shell to zsh"
  chsh -s "$(command -v zsh)"
else
  log_info "Default shell is already zsh"
fi
