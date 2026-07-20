#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=no

update_config() {
	local source_unit="$LINUX_SETUP_COMPONENT_DIR/linux-setup-startup.service"
	local target_unit="$HOME/.config/systemd/user/linux-setup-startup.service"

	command -v systemctl >/dev/null 2>&1 || {
		log_warn "systemctl is unavailable; skipping the startup service config."
		return 0
	}

	if [ ! -e "$target_unit" ] && [ "${LINUX_SETUP_INSTALLING_COMPONENT:-no}" != "yes" ]; then
		log_warn "The startup service is not installed; select the startup-service extra first."
		return 0
	fi

	[ -f "$source_unit" ] || die "Startup service unit not found at $source_unit."
	install_config_file "$source_unit" "$target_unit"
	run_quiet "Reloading the systemd user manager" systemctl --user daemon-reload
}
