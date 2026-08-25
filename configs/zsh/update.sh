#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

set_or_append_setting() {
	local file="$1"
	local key="$2"
	local value="$3"

	if grep -q "^${key}=" "$file"; then
		sed -i "s|^${key}=.*|${key}=${value}|" "$file"
	else
		printf '%s=%s\n' "$key" "$value" >>"$file"
	fi
}

ensure_line() {
	local file="$1"
	local line="$2"

	grep -qF "$line" "$file" || printf '%s\n' "$line" >>"$file"
}

configured_omz_plugins() {
	local plugins=(git)
	local plugin
	local command_name
	local command_plugins=(
		"eza:eza"
		"fzf:fzf"
		"zoxide:zoxide"
		"tmux:tmux"
		"docker:docker"
		"mise:mise"
	)

	for plugin in "${command_plugins[@]}"; do
		command_name="${plugin%%:*}"
		if command -v "$command_name" >/dev/null 2>&1; then
			plugins+=("${plugin#*:}")
		fi
	done

	if command -v mise >/dev/null 2>&1 && mise which python >/dev/null 2>&1; then
		plugins+=(python)
	fi

	plugins+=(zsh-autosuggestions zsh-syntax-highlighting)
	printf '%s ' "${plugins[@]}"
}

set_default_shell_to_zsh() {
	local current_shell
	local user_name
	local zsh_path

	command -v chsh >/dev/null 2>&1 || {
		log_warn "chsh is unavailable; zsh was not set as the default shell."
		return 0
	}

	user_name="$(id -un)"
	zsh_path="$(readlink -f "$(command -v zsh)")"
	current_shell="$(getent passwd "$user_name" | cut -d: -f7)"

	if [ -n "$current_shell" ] &&
		[ "$(readlink -f "$current_shell")" = "$zsh_path" ]; then
		return 0
	fi

	require_sudo
	run_quiet "Setting zsh as the default shell" sudo chsh -s "$zsh_path" "$user_name"
}

update_config() {
	local zsh_root="${ZSH:-$HOME/.oh-my-zsh}"
	local zsh_custom="${ZSH_CUSTOM:-$zsh_root/custom}"
	local zshrc="$HOME/.zshrc"
	local plugins

	if ! command -v zsh >/dev/null 2>&1; then
		apt_install zsh
	fi

	if ! command -v zsh >/dev/null 2>&1; then
		log_warn "zsh is unavailable; skipping shell config."
		return 0
	fi

	set_default_shell_to_zsh

	install_or_update_git_repo \
		"oh-my-zsh" \
		"https://github.com/ohmyzsh/ohmyzsh.git" \
		"$zsh_root"

	mkdir -p "$zsh_custom/plugins" "$zsh_custom/themes"
	install_or_update_git_repo \
		"zsh-autosuggestions" \
		"https://github.com/zsh-users/zsh-autosuggestions.git" \
		"$zsh_custom/plugins/zsh-autosuggestions"
	install_or_update_git_repo \
		"zsh-syntax-highlighting" \
		"https://github.com/zsh-users/zsh-syntax-highlighting.git" \
		"$zsh_custom/plugins/zsh-syntax-highlighting"

	install_config_file \
		"$LINUX_SETUP_COMPONENT_DIR/custom.zsh-theme" \
		"$zsh_custom/themes/custom.zsh-theme"

	touch "$zshrc"
	ensure_line "$zshrc" "export ZSH=\"\$HOME/.oh-my-zsh\""
	set_or_append_setting "$zshrc" "ZSH_THEME" '"custom"'

	plugins="$(configured_omz_plugins)"
	plugins="${plugins% }"
	set_or_append_setting "$zshrc" "plugins" "($plugins)"
	ensure_line "$zshrc" "source \"\$ZSH/oh-my-zsh.sh\""

	sed -i \
		'/^# >>> linux-setup managed >>>$/,/^# <<< linux-setup managed <<<$/{d;}' \
		"$zshrc"
	sed -i \
		'/^# >>> linux-setup tmux auto-start >>>$/,/^# <<< linux-setup tmux auto-start <<<$/{d;}' \
		"$zshrc"

	cat >>"$zshrc" <<'EOF'

# >>> linux-setup managed >>>
export PATH="$HOME/.local/bin:$PATH"

if command -v batcat >/dev/null 2>&1; then
  alias bat="batcat"
fi
unalias cat 2>/dev/null || true

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if [ -x "$HOME/.local/bin/yeet" ]; then
  alias yeet="YEET_CLI=agy $HOME/.local/bin/yeet"
fi
# <<< linux-setup managed <<<
EOF

	log_info "Run 'exec zsh' now; new login sessions will use zsh by default."
}
