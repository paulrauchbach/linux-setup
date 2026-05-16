#!/bin/bash

# Installs and configures oh-my-zsh following <https://github.com/ohmyzsh/ohmyzsh/wiki>
# Settings mirror the previous nix config:
#   theme:   agnoster
#   plugins: git eza docker python zsh-autosuggestions zsh-syntax-highlighting

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSHRC="$HOME/.zshrc"

# --- Install or update oh-my-zsh ---
if [ -d "$HOME/.oh-my-zsh" ]; then
  run_quiet "Updating oh-my-zsh" zsh "$ZSH/tools/upgrade.sh" -v silent
else
  # RUNZSH=no: do not start zsh immediately after install
  # CHSH=no: do not change the default shell (install/zsh.sh handles this)
  run_quiet "Installing oh-my-zsh" bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi

# --- Install or update third-party plugins ---
install_or_update_plugin() {
  local name="$1"
  local repo="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"
  if [ -d "$dest/.git" ]; then
    run_quiet "Updating plugin: $name" git -C "$dest" pull --ff-only --quiet
  else
    run_quiet "Installing plugin: $name" git clone --quiet --depth=1 "$repo" "$dest"
  fi
}

# autosuggestion.enable = true
install_or_update_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
# syntaxHighlighting.enable = true
install_or_update_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting

# --- Apply settings to ~/.zshrc ---

# theme = "agnoster"
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME="custom"|' "$ZSHRC"
else
  echo 'ZSH_THEME="custom"' >> "$ZSHRC"
fi
mkdir -p "$ZSH_CUSTOM/themes"
run_quiet "Installing custom zsh theme" cp "$LINUX_SETUP_INSTALL_DIR/configs/custom.zsh-theme" "$ZSH_CUSTOM/themes/custom.zsh-theme"

# plugins = [ git eza docker python ] + autosuggestions + syntax-highlighting
PLUGINS_LINE='plugins=(git eza docker python zsh-autosuggestions zsh-syntax-highlighting)'
if grep -q '^plugins=' "$ZSHRC"; then
  sed -i "s|^plugins=.*|$PLUGINS_LINE|" "$ZSHRC"
else
  echo "$PLUGINS_LINE" >> "$ZSHRC"
fi

# add activate mise
if ! grep -q 'mise activate' "$ZSHRC"; then
  echo 'eval "$(mise activate zsh)"' >> "$ZSHRC"
fi

# start tmux by default for interactive shells
TMUX_BLOCK_START="# >>> linux-setup tmux auto-start >>>"
TMUX_BLOCK_END="# <<< linux-setup tmux auto-start <<<"
TMUX_BLOCK=$(cat <<'EOF'
# >>> linux-setup tmux auto-start >>>
if [[ -o interactive && -z "$TMUX" && -z "$SSH_CONNECTION" && -z "$NO_TMUX" ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi
# <<< linux-setup tmux auto-start <<<
EOF
)

if grep -qF "$TMUX_BLOCK_START" "$ZSHRC"; then
  sed -i "/$TMUX_BLOCK_START/,/$TMUX_BLOCK_END/d" "$ZSHRC"
fi
printf '\n%s\n' "$TMUX_BLOCK" >> "$ZSHRC"

log_info "Restart your shell or run: source ~/.zshrc"
