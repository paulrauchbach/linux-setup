#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
CALLS=()

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

record() {
	CALLS+=("$1")
}

# shellcheck source=lib.sh
source "$REPO_ROOT/lib.sh"
# shellcheck source=recipes.sh
source "$REPO_ROOT/recipes.sh"

HOME="$TEST_HOME"
export HOME

install_claude() { record claude; }
install_antigravity_cli() { record agy; }
install_grok_cli() { record grok; }
install_opencode() { record opencode; }
install_mise() { record mise; }
run_quiet() {
	local message="$1"
	shift

	case "$message" in
		"Ensuring Node.js is available") record node ;;
		"Installing pnpm") record pnpm ;;
		"Installing @openai/codex") record codex ;;
		"Installing @google/gemini-cli") record gemini ;;
		"Installing Pi") record pi ;;
		*) fail "unexpected command: $message" ;;
	esac
}

install_agent_harnesses

expected="claude agy grok opencode mise node pnpm codex gemini pi"
actual="${CALLS[*]}"
[ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
[ -d "$TEST_HOME/.local/bin" ] || fail "agent harness install did not create ~/.local/bin"

printf 'PASS: agent-harnesses installs every supported CLI\n'
