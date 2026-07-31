#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"

cleanup() {
	case "$TEST_ROOT" in
		/tmp/*) rm -rf -- "$TEST_ROOT" ;;
	esac
}
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_file_matches() {
	cmp -s "$1" "$2" || fail "$2 does not match $1"
}

assert_skill_link() {
	local agent="$1"
	local skill="$2"
	local expected="$REPO_ROOT/configs/agents/skills/$skill"
	local actual="$TEST_HOME/.$agent/skills/$skill"

	[ -L "$actual" ] || fail "$actual is not a symbolic link"
	[ "$(readlink "$actual")" = "$expected" ] || fail "$actual points to the wrong source"
}

assert_equal() {
	[ "$1" = "$2" ] || fail "expected '$1', got '$2'"
}

run_update() {
	HOME="$TEST_HOME" \
		NO_COLOR=1 \
		LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/setup.sh" update "$@"
}

mkdir -p \
	"$TEST_HOME/.codex/skills/.system" \
	"$TEST_HOME/.codex/skills/unrelated" \
	"$TEST_HOME/.codex/skills/grill-me" \
	"$TEST_HOME/.claude/skills"
printf 'local collision\n' >"$TEST_HOME/.codex/skills/grill-me/local.txt"
printf 'preserve me\n' >"$TEST_HOME/.codex/skills/unrelated/local.txt"
printf 'old config\n' >"$TEST_HOME/.codex/config.toml"
ln -s \
	"$REPO_ROOT/configs/agents/skills/removed-skill" \
	"$TEST_HOME/.codex/skills/removed-skill"

run_update agents >/dev/null

mkdir -p "$TEST_HOME/.local/bin"
printf 'outdated yeet\n' >"$TEST_HOME/.local/bin/yeet"
run_update yeet >/dev/null
assert_file_matches "$REPO_ROOT/yeet.sh" "$TEST_HOME/.local/bin/yeet"
[ -x "$TEST_HOME/.local/bin/yeet" ] || fail "updated yeet is not executable"

assert_file_matches \
	"$REPO_ROOT/configs/agents/codex/config.toml" \
	"$TEST_HOME/.codex/config.toml"
assert_file_matches \
	"$REPO_ROOT/configs/agents/claude/settings.json" \
	"$TEST_HOME/.claude/settings.json"
assert_file_matches \
	"$REPO_ROOT/configs/agents/claude/statusline-command.sh" \
	"$TEST_HOME/.claude/statusline-command.sh"
assert_file_matches \
	"$REPO_ROOT/configs/agents/AGENTS.md" \
	"$TEST_HOME/.codex/AGENTS.md"
assert_file_matches \
	"$REPO_ROOT/configs/agents/AGENTS.md" \
	"$TEST_HOME/.claude/CLAUDE.md"

for skill_path in "$REPO_ROOT/configs/agents/skills"/*; do
	skill="$(basename "$skill_path")"
	assert_skill_link codex "$skill"
	assert_skill_link claude "$skill"
done

[ -f "$TEST_HOME/.codex/skills/unrelated/local.txt" ] || fail "unrelated Codex skill was removed"
[ -d "$TEST_HOME/.codex/skills/.system" ] || fail "Codex system skills were removed"
[ ! -e "$TEST_HOME/.codex/skills/removed-skill" ] || fail "obsolete managed skill was retained"

if find "$TEST_HOME" -name '*.linux-setup-backup.*' -print -quit | grep -q .; then
	fail "config update created a backup artifact"
fi

run_update agents >/dev/null

HOME="$TEST_HOME" \
	NO_COLOR=1 \
	LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
	LINUX_SETUP_MODE=update-config \
	LINUX_SETUP_UPDATE_CONFIGS=agents \
	bash "$REPO_ROOT/setup.sh" >/dev/null

# shellcheck source=setup.sh
source "$REPO_ROOT/setup.sh"
expected_components="$(list_config_components | paste -sd, -)"
assert_equal \
	"$expected_components" \
	"$(normalize_configs all)"
assert_equal "agents" "$(normalize_configs agents,agents)"
component_applies_during_install agents || fail "agents should be applied during installation"
if component_applies_during_install startup-service; then
	fail "startup-service should only be applied when its extra is installed"
fi
if component_applies_during_install yeet; then
	fail "yeet should only be applied when its extra is installed or explicitly updated"
fi

if list_config_components | grep -qx manual; then
	fail "manual was exposed as an update target"
fi

if find "$REPO_ROOT/configs" -mindepth 1 -maxdepth 1 -type f -print -quit | grep -q .; then
	fail "configs contains a top-level file instead of a component directory"
fi

brave_preferences="$REPO_ROOT/configs/brave/preferences.json"
keepassxc_extension="$REPO_ROOT/configs/brave/extensions/oboonakemofpalcgghocfoadofidjkkk.json"
keepassxc_native_host="$REPO_ROOT/configs/brave/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
assert_equal \
	"DuckDuckGo" \
	"$(jq -r '.default_search_provider_data.template_url_data.short_name' "$brave_preferences")"
assert_equal \
	"DuckDuckGo" \
	"$(jq -r '.brave.default_private_search_provider_data.short_name' "$brave_preferences")"
assert_equal \
	"$(jq -r '.default_search_provider_data.template_url_data.synced_guid' "$brave_preferences")" \
	"$(jq -r '.brave.default_private_search_provider_guid' "$brave_preferences")"
assert_equal \
	"https://clients2.google.com/service/update2/crx" \
	"$(jq -r '.external_update_url' "$keepassxc_extension")"
assert_equal \
	"org.keepassxc.keepassxc_browser" \
	"$(jq -r '.name' "$keepassxc_native_host")"
jq -e \
	'.allowed_origins | index("chrome-extension://oboonakemofpalcgghocfoadofidjkkk/") != null' \
	"$keepassxc_native_host" >/dev/null || fail "KeePassXC native host does not allow the Chrome extension"

while IFS= read -r component_dir; do
	component="$(basename "$component_dir")"
	[ "$component" = "manual" ] && continue
	[ -f "$component_dir/update.sh" ] || fail "$component does not provide update.sh"
done < <(find "$REPO_ROOT/configs" -mindepth 1 -maxdepth 1 -type d | sort)

printf 'PASS: discovered agent config updates are complete, idempotent, and artifact-free\n'
