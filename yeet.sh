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

run_pre_commit_hook_if_present() {
	local hook_path

	hook_path="$(git -C "$repo_root" rev-parse --git-path hooks/pre-commit)"
	[ -x "$hook_path" ] || return 0

	log "Running pre-commit hook"
	(cd "$repo_root" && "$hook_path") >/dev/null 2>&1
	pre_commit_hook_ran=1
}

generate_commit_message() {
	local err_file="$1"

	case "$yeet_cli" in
	codex)
		codex exec \
			-C "$repo_root" \
			-m "$yeet_model" \
			--color never \
			--output-last-message "$raw_message_file" \
			- <"$prompt_file" >/dev/null 2>"$err_file"
		;;
	claude | agy)
		(cd "$repo_root" && "$yeet_cli" --print --model "$yeet_model") \
			<"$prompt_file" >"$raw_message_file" 2>"$err_file"
		;;
	esac
}

yeet_cli="${YEET_CLI:-agy}"
case "$yeet_cli" in
codex) yeet_model="${YEET_MODEL:-gpt-5.4-mini}" ;;
claude) yeet_model="${YEET_MODEL:-haiku}" ;;
agy) yeet_model="${YEET_MODEL:-Gemini 3.5 Flash (Low)}" ;;
*) die "unknown YEET_CLI: $yeet_cli (use codex, claude, or agy)" ;;
esac

require_command git
require_command "$yeet_cli"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

repo_root="$(git rev-parse --show-toplevel)"
conventions_file="$repo_root/docs/issue-tracker.md"
pre_commit_hook_ran=0

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

diff_file="$tmp_dir/diff.txt"
prompt_file="$tmp_dir/prompt.txt"
raw_message_file="$tmp_dir/raw-message.txt"
message_file="$tmp_dir/message.txt"

if git -C "$repo_root" diff --quiet --cached --exit-code &&
	git -C "$repo_root" diff --quiet --exit-code &&
	[ -z "$(git -C "$repo_root" ls-files --others --exclude-standard)" ]; then
	die "no changes to commit"
fi

git -C "$repo_root" add --all

run_pre_commit_hook_if_present

git -C "$repo_root" add --all

git -C "$repo_root" diff --cached --quiet --exit-code && die "no staged changes to commit"

git -C "$repo_root" diff --cached --no-ext-diff --no-color >"$diff_file"

{
	cat <<'EOF'
Generate a concise Git commit message for the repository changes below.

Rules:
- Output only the commit message.
- Use the repository conventions if they are provided.
- Prefer a single subject line unless the change needs a short body.
- Do not wrap the message in markdown fences.

DONT read any files, do any actions, just generate a commit message based on the information provided below.
EOF

	if [ -r "$conventions_file" ]; then
		printf 'Repository conventions from docs/issue-tracker.md:\n\n'
		cat "$conventions_file"
		printf '\n\n'
	fi

	printf 'Repository changes:\n\n'
	cat "$diff_file"
} >"$prompt_file"

log "Generating commit message ($yeet_cli)"
cli_err_file="$tmp_dir/cli-err.txt"
if ! generate_commit_message "$cli_err_file"; then
	cat "$cli_err_file" >&2
	die "$yeet_cli failed to generate a commit message"
fi

trim_commit_message "$raw_message_file" "$message_file"
[ -s "$message_file" ] || die "Codex did not generate a commit message"

if [ "$pre_commit_hook_ran" -eq 1 ]; then
	git -C "$repo_root" commit --no-verify -F "$message_file" >/dev/null
else
	git -C "$repo_root" commit -F "$message_file" >/dev/null
fi

log "Pushing"
push_current_branch >/dev/null 2>&1

printf '\n'
cat "$message_file"
