#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
FAKE_BIN="$TEST_ROOT/bin"
SETTINGS_LOG="$TEST_ROOT/gsettings.log"
WALLPAPER="$TEST_ROOT/wallpaper.jpg"

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

mkdir -p "$TEST_HOME" "$FAKE_BIN"
printf 'test wallpaper\n' >"$WALLPAPER"

cat >"$FAKE_BIN/gsettings" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
	list-schemas) exit 0 ;;
	list-keys) printf 'accent-color\n' ;;
	set) printf '%s\n' "$*" >>"$GNOME_TEST_LOG" ;;
	*) exit 1 ;;
esac
EOF

cat >"$FAKE_BIN/gnome-extensions" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
destination=""
while [ "$#" -gt 0 ]; do
	if [ "$1" = -o ]; then
		destination="$2"
		break
	fi
	shift
done
[ -n "$destination" ]
cp "$GNOME_TEST_WALLPAPER" "$destination"
EOF
chmod +x "$FAKE_BIN/gsettings" "$FAKE_BIN/gnome-extensions" "$FAKE_BIN/curl"

HOME="$TEST_HOME" \
	PATH="$FAKE_BIN:$PATH" \
	NO_COLOR=1 \
	XDG_CURRENT_DESKTOP=GNOME \
	GNOME_TEST_LOG="$SETTINGS_LOG" \
	GNOME_TEST_WALLPAPER="$WALLPAPER" \
	GNOME_BACKGROUND_URL="file://$WALLPAPER" \
	GNOME_BACKGROUND_SHA256="$(sha256sum "$WALLPAPER" | cut -d' ' -f1)" \
	LINUX_SETUP_INSTALL_DIR="$REPO_ROOT" \
	bash "$REPO_ROOT/setup.sh" update gnome >/dev/null

grep -qx "set org.gnome.desktop.session idle-delay 0" "$SETTINGS_LOG" ||
	fail "GNOME idle timeout was not preserved"
grep -qx "set org.gnome.desktop.wm.keybindings switch-input-source @as \[\]" "$SETTINGS_LOG" ||
	fail "GNOME input-source shortcut was not cleared"
grep -qx "set org.gnome.desktop.interface gtk-theme Yaru-purple-dark" "$SETTINGS_LOG" ||
	fail "GNOME theme was not configured"
grep -q "custom0/ binding <Super>space" "$SETTINGS_LOG" ||
	fail "Ulauncher GNOME shortcut was not configured"
cmp -s "$WALLPAPER" "$TEST_HOME/.local/share/backgrounds/tokyo-night.jpg" ||
	fail "GNOME wallpaper was not installed"

printf 'PASS: GNOME settings, shortcuts, and wallpaper are reproducible\n'
