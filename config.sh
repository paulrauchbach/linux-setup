#!/usr/bin/env bash

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

install_or_update_git_repo() {
	local display_name="$1"
	local repo_url="$2"
	local destination="$3"

	if [ -d "$destination/.git" ]; then
		run_quiet "Updating $display_name" git -C "$destination" pull --ff-only --quiet
	elif [ -e "$destination" ]; then
		log_warn "Skipping $display_name install: $destination exists and is not a git checkout."
	else
		run_quiet "Installing $display_name" git clone --quiet --depth=1 "$repo_url" "$destination"
	fi
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

apply_git_config() {
	local full_name="$1"
	local email="$2"

	run_quiet "Setting git user.name" git config --global user.name "$full_name"
	run_quiet "Setting git user.email" git config --global user.email "$email"
}

apply_tmux_config() {
	local source_conf="$LINUX_SETUP_INSTALL_DIR/configs/tmux.conf"
	local target_conf="$HOME/.tmux.conf"

	[ -f "$source_conf" ] || die "tmux config not found at $source_conf."
	run_quiet "Installing tmux config" cp "$source_conf" "$target_conf"
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

apply_zsh_config() {
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

	run_quiet \
		"Installing custom zsh theme" \
		cp "$LINUX_SETUP_INSTALL_DIR/configs/custom.zsh-theme" "$zsh_custom/themes/custom.zsh-theme"

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

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if [[ -o interactive && -z "$TMUX" && -z "$SSH_CONNECTION" && -z "$NO_TMUX" ]] &&
  command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi
# <<< linux-setup managed <<<
EOF

	log_info "Run 'exec zsh' now; new login sessions will use zsh by default."
}

apply_alacritty_config() {
	local source_conf="$LINUX_SETUP_INSTALL_DIR/configs/alacritty.toml"
	local target_dir="$HOME/.config/alacritty"

	command -v alacritty >/dev/null 2>&1 || return 0
	[ -f "$source_conf" ] || die "Alacritty config not found at $source_conf."

	mkdir -p "$target_dir"
	run_quiet "Installing Alacritty config" cp "$source_conf" "$target_dir/alacritty.toml"
}

apply_vscode_config() {
	local source_settings="$LINUX_SETUP_INSTALL_DIR/configs/vscode-settings.json"
	local extensions_file="$LINUX_SETUP_INSTALL_DIR/configs/vscode-extensions.txt"
	local target_dir="$HOME/.config/Code/User"
	local extension

	command -v code >/dev/null 2>&1 || return 0

	if [ -f "$source_settings" ]; then
		mkdir -p "$target_dir"
		run_quiet "Installing VS Code settings" cp "$source_settings" "$target_dir/settings.json"
	fi

	if [ -f "$extensions_file" ]; then
		while IFS= read -r extension; do
			extension="${extension#"${extension%%[![:space:]]*}"}"
			extension="${extension%"${extension##*[![:space:]]}"}"
			[ -n "$extension" ] || continue
			case "$extension" in
				\#*) continue ;;
			esac
			run_quiet "Installing VS Code extension $extension" \
				code --install-extension "$extension" --force
		done <"$extensions_file"
	fi
}

apply_brave_policy() {
	local source_policy="$LINUX_SETUP_INSTALL_DIR/configs/brave-policy.json"
	local target_policy="/etc/brave/policies/managed/linux-setup.json"
	local user_name
	local rendered

	if ! command -v brave-browser >/dev/null 2>&1 &&
		! command -v brave >/dev/null 2>&1 &&
		! { command -v dpkg >/dev/null 2>&1 && dpkg -s brave-origin >/dev/null 2>&1; }; then
		return 0
	fi

	[ -f "$source_policy" ] || die "Brave policy not found at $source_policy."

	user_name="$(id -un)"
	rendered="$(mktemp)"
	sed "s|__USER_NAME__|$user_name|g" "$source_policy" >"$rendered"

	require_sudo
	run_quiet "Installing Brave managed policy" \
		sudo install -D -m 0644 -o root -g root "$rendered" "$target_policy"
	rm -f "$rendered"
}

apply_personal_config() {
	local full_name="$1"
	local email="$2"

	apply_zsh_config
	apply_tmux_config
	apply_git_config "$full_name" "$email"
	apply_alacritty_config
	apply_vscode_config
	apply_brave_policy
}
