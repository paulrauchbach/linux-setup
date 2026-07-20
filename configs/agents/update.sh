#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

install_shared_skills_dir() {
	local source_dir="$1"
	local target_dir="$2"
	local source_path
	local target_path
	local link_target

	[ -d "$source_dir" ] || die "Config directory not found at $source_dir."
	mkdir -p "$target_dir"

	for target_path in "$target_dir"/*; do
		[ -L "$target_path" ] || continue
		link_target="$(readlink "$target_path")"
		case "$link_target" in
			"$source_dir"/*)
				[ -e "$source_dir/$(basename "$target_path")" ] ||
					run_quiet "Removing obsolete managed skill $target_path" rm -f -- "$target_path"
				;;
		esac
	done

	for source_path in "$source_dir"/*; do
		[ -e "$source_path" ] || continue
		target_path="$target_dir/$(basename "$source_path")"
		if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
			log_success "$target_path is already up to date"
			continue
		fi
		# shellcheck disable=SC2016
		run_quiet "Linking $target_path" \
			sh -c 'rm -rf -- "$1" && ln -s -- "$2" "$1"' _ "$target_path" "$source_path"
	done
}

update_config() {
	local shared_instructions="$LINUX_SETUP_COMPONENT_DIR/AGENTS.md"
	local shared_skills_dir="$LINUX_SETUP_COMPONENT_DIR/skills"

	install_config_file \
		"$LINUX_SETUP_COMPONENT_DIR/codex/config.toml" \
		"$HOME/.codex/config.toml"
	install_config_file "$shared_instructions" "$HOME/.codex/AGENTS.md"

	install_config_file \
		"$LINUX_SETUP_COMPONENT_DIR/claude/settings.json" \
		"$HOME/.claude/settings.json"
	install_config_file \
		"$LINUX_SETUP_COMPONENT_DIR/claude/statusline-command.sh" \
		"$HOME/.claude/statusline-command.sh"
	install_config_file "$shared_instructions" "$HOME/.claude/CLAUDE.md"

	install_shared_skills_dir "$shared_skills_dir" "$HOME/.codex/skills"
	install_shared_skills_dir "$shared_skills_dir" "$HOME/.claude/skills"
}
