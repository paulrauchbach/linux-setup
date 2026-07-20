#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	local source_conf="$LINUX_SETUP_COMPONENT_DIR/tmux.conf"
	local target_conf="$HOME/.tmux.conf"
	local tpm_dir="$HOME/.tmux/plugins/tpm"

	[ -f "$source_conf" ] || die "tmux config not found at $source_conf."
	install_config_file "$source_conf" "$target_conf"

	install_or_update_git_repo \
		"tmux plugin manager" \
		"https://github.com/tmux-plugins/tpm.git" \
		"$tpm_dir"

	if [ -x "$tpm_dir/bin/install_plugins" ]; then
		run_quiet "Installing tmux plugins" "$tpm_dir/bin/install_plugins"
	fi
}
