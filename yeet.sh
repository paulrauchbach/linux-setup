#!/usr/bin/env bash

set -euo pipefail

die() {
	printf 'yeet: %s\n' "$*" >&2
	exit 1
}

log() {
	printf '==> %s\n' "$*"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

trim_commit_message() {
	local input_file="$1"
	local output_file="$2"

	sed \
		-e '1{/^```/d;}' \
		-e '${/^```/d;}' \
		-e '/^Here is /Id' \
		-e '/^Commit message:/Id' \
		"$input_file" |
		sed -e '/./,$!d' >"$output_file"
}

push_current_branch() {
	local branch

	if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
		git push
		return
	fi

	branch="$(git branch --show-current)"
	[ -n "$branch" ] || die "cannot push from a detached HEAD without an upstream branch"

	git remote get-url origin >/dev/null 2>&1 || die "no upstream configured and no origin remote found"
	git push -u origin "$branch"
}

require_command git
require_command codex

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

repo_root="$(git rev-parse --show-toplevel)"
conventions_file="$repo_root/docs/issue-tracker.md"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

diff_file="$tmp_dir/diff.txt"
prompt_file="$tmp_dir/prompt.txt"
raw_message_file="$tmp_dir/raw-message.txt"
message_file="$tmp_dir/message.txt"

log "Reading repository changes"
{
	printf '# Staged changes\n\n'
	git -C "$repo_root" diff --cached --no-ext-diff --no-color
	printf '\n# Unstaged changes\n\n'
	git -C "$repo_root" diff --no-ext-diff --no-color
	printf '\n# Untracked files\n\n'
	git -C "$repo_root" ls-files --others --exclude-standard
} >"$diff_file"

if [ ! -s "$diff_file" ] || git -C "$repo_root" diff --quiet --cached --exit-code &&
	git -C "$repo_root" diff --quiet --exit-code &&
	[ -z "$(git -C "$repo_root" ls-files --others --exclude-standard)" ]; then
	die "no changes to commit"
fi

{
	cat <<'EOF'
Generate a concise Git commit message for the repository changes below.

Rules:
- Output only the commit message.
- Use the repository conventions if they are provided.
- Prefer a single subject line unless the change needs a short body.
- Do not wrap the message in markdown fences.

EOF

	if [ -r "$conventions_file" ]; then
		printf 'Repository conventions from docs/issue-tracker.md:\n\n'
		cat "$conventions_file"
		printf '\n\n'
	fi

	printf 'Repository changes:\n\n'
	cat "$diff_file"
} >"$prompt_file"

log "Generating commit message with Codex"
codex exec \
	-C "$repo_root" \
	--sandbox read-only \
	--ask-for-approval never \
	--color never \
	--output-last-message "$raw_message_file" \
	- <"$prompt_file" >/dev/null

trim_commit_message "$raw_message_file" "$message_file"
[ -s "$message_file" ] || die "Codex did not generate a commit message"

log "Commit message"
sed 's/^/  /' "$message_file"

log "Staging changes"
git -C "$repo_root" add --all

git -C "$repo_root" diff --cached --quiet --exit-code && die "no staged changes to commit"

log "Creating commit"
git -C "$repo_root" commit -F "$message_file"

log "Pushing"
push_current_branch
