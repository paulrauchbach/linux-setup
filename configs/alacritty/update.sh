#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	local source_conf="$LINUX_SETUP_COMPONENT_DIR/alacritty.toml"
	local target_conf="$HOME/.config/alacritty/alacritty.toml"

	command -v alacritty >/dev/null 2>&1 || return 0
	[ -f "$source_conf" ] || die "Alacritty config not found at $source_conf."
	install_config_file "$source_conf" "$target_conf"
}
