#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
SOURCE="$TEST_ROOT/brave-tab-search-source"
REMOTE="$TEST_ROOT/brave-tab-search.git"

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

mkdir -p "$TEST_HOME" "$FAKE_BIN" "$SOURCE"
printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/ulauncher"
chmod +x "$FAKE_BIN/ulauncher"

git init --quiet --bare "$REMOTE"
git init --quiet -b main "$SOURCE"
git -C "$SOURCE" config user.name "Linux Setup Test"
git -C "$SOURCE" config user.email "linux-setup@example.test"
# The generated fixture must expand HOME when it runs, not while this test creates it.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nset -eu\nprintf installed >"$HOME/tab-search-installed"\n' >"$SOURCE/install.sh"
chmod +x "$SOURCE/install.sh"
git -C "$SOURCE" add install.sh
git -C "$SOURCE" commit --quiet -m initial
git -C "$SOURCE" remote add origin "$REMOTE"
git -C "$SOURCE" push --quiet -u origin main
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main

run_update() {
	HOME="$TEST_HOME" \
		PATH="$FAKE_BIN:$PATH" \
		NO_COLOR=1 \
		BRAVE_TAB_SEARCH_REPO_URL="file://$REMOTE" \
		LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/setup.sh" update ulauncher
}

run_update >/dev/null
cmp -s "$REPO_ROOT/configs/ulauncher/settings.json" "$TEST_HOME/.config/ulauncher/settings.json" ||
	fail "Ulauncher settings were not installed"
cmp -s "$REPO_ROOT/configs/ulauncher/shortcuts.json" "$TEST_HOME/.config/ulauncher/shortcuts.json" ||
	fail "Ulauncher shortcuts were not installed"
cmp -s "$REPO_ROOT/configs/ulauncher/ulauncher.desktop" "$TEST_HOME/.config/autostart/ulauncher.desktop" ||
	fail "Ulauncher autostart entry was not installed"
[ -d "$TEST_HOME/.local/share/brave-tab-search/.git" ] || fail "tab-search repository was not cloned"
[ "$(cat "$TEST_HOME/tab-search-installed")" = installed ] || fail "tab-search installer was not run"
[ -f "$TEST_HOME/.config/ulauncher/user-themes/liquid-glass-dark/theme.css" ] ||
	fail "Ulauncher theme was not installed"
[ -f "$TEST_HOME/.config/ulauncher/icons/chatgpt.svg" ] ||
	fail "Ulauncher shortcut icons were not installed"
[ -L "$TEST_HOME/.local/share/ulauncher/extensions/io.github.repository-search" ] ||
	fail "GitHub repository search extension was not installed"

run_update >/dev/null

if HOME="$TEST_HOME" PATH="$FAKE_BIN:$PATH" NO_COLOR=1 \
	BRAVE_TAB_SEARCH_REPO_URL="file://$TEST_ROOT/missing.git" \
	LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
	bash "$REPO_ROOT/setup.sh" update ulauncher >/dev/null 2>&1; then
	fail "Ulauncher config accepted an inaccessible private repository"
fi

preflight_output="$TEST_ROOT/preflight-output"
if HOME="$TEST_HOME" NO_COLOR=1 \
	LINUX_SETUP_TIER=desktop \
	LINUX_SETUP_CONFIG=yes \
	LINUX_SETUP_FULL_NAME='Linux Setup Test' \
	LINUX_SETUP_EMAIL=linux-setup@example.test \
	BRAVE_TAB_SEARCH_REPO_URL="file://$TEST_ROOT/missing.git" \
	LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
	bash "$REPO_ROOT/setup.sh" >"$preflight_output" 2>&1; then
	fail "configured desktop install passed without tab-search repository access"
fi
grep -q "requires SSH access" "$preflight_output" ||
	fail "configured desktop install did not explain the SSH requirement"

printf 'PASS: Ulauncher config is complete, idempotent, and requires repository access\n'
