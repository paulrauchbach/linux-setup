#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
TEST_BIN="$TEST_ROOT/bin"
GUM_LOG="$TEST_ROOT/gum.log"

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

mkdir -p "$TEST_HOME" "$TEST_BIN"
# The generated script must expand its own positional argument, not this test's.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'' \
	"printf '%s\\n' \"\${1:-}\" >>\"$GUM_LOG\"" \
	'' \
	'if [ "${1:-}" = "confirm" ]; then' \
	'	exit 1' \
	'fi' >"$TEST_BIN/gum"
chmod +x "$TEST_BIN/gum"

run_in_terminal() {
	script --quiet --return --command "$1" /dev/null >/dev/null
}

common_env="HOME=$TEST_HOME PATH=$TEST_BIN:$PATH NO_COLOR=1 LINUX_SETUP_INSTALL_DIR=$REPO_ROOT"

run_in_terminal \
	"$common_env bash $REPO_ROOT/setup.sh update agents"

if grep -qx confirm "$GUM_LOG"; then
	fail "an explicit update target requested confirmation"
fi

: >"$GUM_LOG"
run_in_terminal \
	"$common_env LINUX_SETUP_MODE=update-config LINUX_SETUP_UPDATE_CONFIGS=agents bash $REPO_ROOT/setup.sh"

grep -qx confirm "$GUM_LOG" ||
	fail "an environment-provided update target did not request confirmation"

printf 'PASS: explicit update targets skip only the redundant confirmation\n'
