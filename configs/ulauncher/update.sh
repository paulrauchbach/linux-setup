#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	local repo_url="${BRAVE_TAB_SEARCH_REPO_URL:-git@github.com:paulrauchbach/brave-tab-search.git}"
	local destination="$HOME/.local/share/brave-tab-search"
	local theme_file
	local relative_theme_file

	command -v ulauncher >/dev/null 2>&1 || {
		log_warn "Skipping Ulauncher config because Ulauncher is not installed."
		return 0
	}

	require_git_repo_access "Brave tab search" "$repo_url"
	install_config_file "$LINUX_SETUP_COMPONENT_DIR/settings.json" "$HOME/.config/ulauncher/settings.json"
	install_config_file "$LINUX_SETUP_COMPONENT_DIR/shortcuts.json" "$HOME/.config/ulauncher/shortcuts.json"
	install_config_file "$LINUX_SETUP_COMPONENT_DIR/ulauncher.desktop" "$HOME/.config/autostart/ulauncher.desktop"
	while IFS= read -r -d '' theme_file; do
		relative_theme_file="${theme_file#"$LINUX_SETUP_COMPONENT_DIR/themes/"}"
		install_config_file "$theme_file" "$HOME/.config/ulauncher/user-themes/$relative_theme_file"
	done < <(find "$LINUX_SETUP_COMPONENT_DIR/themes" -type f -print0)
	install_or_update_git_repo "Brave tab search" "$repo_url" "$destination"
	[ -x "$destination/install.sh" ] || die "Brave tab search installer not found at $destination/install.sh."
	"$destination/install.sh"

	if pgrep -x ulauncher >/dev/null 2>&1; then
		log_warn "Restart Ulauncher to load its updated settings and extensions."
	fi
}
