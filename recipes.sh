#!/usr/bin/env bash

install_gum() {
	if command -v gum >/dev/null 2>&1; then
		return 0
	fi

	is_supported_platform ||
		die "gum is required for interactive setup; automatic installation supports Debian and Ubuntu only."

	apt_update
	if apt-cache show gum >/dev/null 2>&1; then
		apt_install gum
	else
		add_signed_apt_repo \
			"Charm" \
			"https://repo.charm.sh/apt/gpg.key" \
			"/etc/apt/keyrings/charm.asc" \
			"deb [signed-by=/etc/apt/keyrings/charm.asc] https://repo.charm.sh/apt/ * *" \
			"/etc/apt/sources.list.d/charm.list"
		apt_install gum
	fi

	command -v gum >/dev/null 2>&1 || die "gum installation completed but the command is unavailable."
}

install_github_cli() {
	local architecture

	is_supported_platform || {
		log_warn "Skipping GitHub CLI on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	architecture="$(dpkg --print-architecture)"
	add_signed_apt_repo \
		"GitHub CLI" \
		"https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
		"/etc/apt/keyrings/githubcli-archive-keyring.gpg" \
		"deb [arch=$architecture signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		"/etc/apt/sources.list.d/github-cli.list"
	apt_install gh
}
