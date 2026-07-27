#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
REMOTE="$TEST_ROOT/remote.git"
SOURCE="$TEST_ROOT/source"
INSTALL_DIR="$TEST_ROOT/install"
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

git init --quiet --bare "$REMOTE"
git clone --quiet "$REMOTE" "$SOURCE"
git -C "$SOURCE" config user.name "Linux Setup Test"
git -C "$SOURCE" config user.email "linux-setup@example.test"

cp "$REPO_ROOT/linux-setup" "$SOURCE/linux-setup"
# The generated script must expand its own positional argument, not this test's.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "old:%%s\\n" "$1"\n' >"$SOURCE/setup.sh"
chmod +x "$SOURCE/linux-setup" "$SOURCE/setup.sh"
git -C "$SOURCE" add linux-setup setup.sh
git -C "$SOURCE" commit --quiet -m initial
git -C "$SOURCE" branch -M main
git -C "$SOURCE" push --quiet -u origin main
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main

git clone --quiet --depth=1 "file://$REMOTE" "$INSTALL_DIR"
mkdir -p "$TEST_HOME"

# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "new:%%s\\n" "$1"\n' >"$SOURCE/setup.sh"
git -C "$SOURCE" add setup.sh
git -C "$SOURCE" commit --quiet -m intermediate-update
# Advance twice so a depth-one fetch cannot connect the installed shallow tip
# to the new remote tip through the commit graph.
printf '# final update\n' >>"$SOURCE/setup.sh"
printf '# refreshed launcher\n' >>"$SOURCE/linux-setup"
git -C "$SOURCE" add linux-setup setup.sh
git -C "$SOURCE" commit --quiet -m final-update
git -C "$SOURCE" push --quiet

output="$(
	HOME="$TEST_HOME" \
		LINUX_SETUP_INSTALL_DIR="$INSTALL_DIR" \
		bash "$INSTALL_DIR/linux-setup" agents
)"

case "$output" in
	*"new:agents"*) ;;
	*) fail "launcher did not execute the refreshed setup.sh" ;;
esac

grep -q '^# refreshed launcher$' "$TEST_HOME/.local/bin/linux-setup" ||
	fail "launcher did not refresh its installed executable"

[ "$(git -C "$INSTALL_DIR" rev-parse HEAD)" = "$(git -C "$SOURCE" rev-parse HEAD)" ] ||
	fail "managed checkout did not move to the remote snapshot"

printf 'local change\n' >>"$INSTALL_DIR/setup.sh"
if HOME="$TEST_HOME" LINUX_SETUP_INSTALL_DIR="$INSTALL_DIR" \
	bash "$INSTALL_DIR/linux-setup" agents >/dev/null 2>&1; then
	fail "launcher accepted a checkout with local changes"
fi

printf 'PASS: launcher refreshes before execution and preserves local changes\n'
