#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	# btop's packaged Debian icon (Icon=btop) is a flat black pixel-art glyph
	# with no background, so it barely reads in the app grid or alt-tab. This
	# installs a nicer icon under the same name in the user icon theme
	# directory, which the freedesktop icon spec searches before
	# /usr/share/icons/hicolor, without touching the apt-owned package files.
	# Source: Papirus icon theme (GPL-3.0),
	# https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
	local source_icon="$LINUX_SETUP_COMPONENT_DIR/btop.svg"
	local target_icon="$HOME/.local/share/icons/hicolor/scalable/apps/btop.svg"

	command -v btop >/dev/null 2>&1 || return 0
	[ -f "$source_icon" ] || die "btop icon not found at $source_icon."
	install_config_file "$source_icon" "$target_icon"
}
