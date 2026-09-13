---
name: file-pr
description: File a concise pull request. Use when the user asks to open, file, or submit a PR for changes.
---

# File PR Skill (`file-pr`)

## Workflow & Pre-Flight Checks

1. **Check Existing PRs:** Before filing, check whether a pull request for this branch already exists using `gh pr list --head <branch-name>`.
2. **Local Diff Audit:** Review the diff locally against `origin/main` (`git diff origin/main`) to make sure its contents match the user's explicit goal.
3. **Commit & Title Conventions:**
   - PR titles usually become commit messages. Follow the repository's title conventions (e.g., `feat(ui): ...`, `fix(server): ...`, `perf(websocket): ...`).
   - Prefer a concise, human-readable title that explains *why* the change matters.

### Examples of Good Titles:
- `perf(server): negotiate permessage-deflate on the websocket`
- `fix(workspace): retain project context when switching threads`

### Examples of Bad Titles:
- `updated files`
- `fix bug in components`

---

## PR Description Guidelines

- Open the description with a simple explanation of the problem based on the user's original prompt.
- Briefly explain the solution.
- **Do NOT** end with an exhaustive implementation inventory of modified lines/files.
- **Do NOT** create the PR as a draft unless the user explicitly requests it.

### Good Description Example:
> My "new worktree" default was ignored when starting new threads on existing worktrees. Super unintuitive. Now your preferences always apply.

### Bad Description Example:
> Removed implicit workspace carry-over from every "new thread" entry point (cmd+n, sidebar buttons, command palette). Deleted contextualThreadOptions, startNewThreadInProjectFromContext, and seed-context machinery.

---

## Images & Screenshots

Add screenshots when a change is visible (UI, widgets, generated images). GitHub has no API or `gh` command for uploading images to a PR. Drag and drop in the browser uploads them, but needs the user's browser session, so don't try it without their consent. Instead, put the images on a separate branch that is never merged, and link to them.

1. **Before publishing, look at every image.** Pushing makes them visible to everyone who can read the repository (in a public repo: everyone). Check for private data, and crop to the relevant part (e.g. `magick in.png -crop 700x590+314+542 +repage out.png`).
2. **Create the branch without touching the working tree or the current branch.** Git plumbing builds a commit that holds only the images and has no parent:
   ```sh
   tree=$(for f in shots/*.png; do
     printf '100644 blob %s\t%s\n' "$(git hash-object -w "$f")" "$(basename "$f")"
   done | git mktree)
   commit=$(git commit-tree "$tree" -m "Screenshots for PR #<number>, not for merging")
   git push origin "$commit:refs/heads/screenshots/pr-<number>"
   ```
   To add or replace images later, run it again with all images and push with `--force`.
3. **Check that every linked file exists** on the branch: `gh api "repos/<owner>/<repo>/contents/<file>?ref=screenshots/pr-<number>" -q .size`.
4. **Link them with `blob/...?raw=true`.** GitHub keeps this link as it is, and the reader's browser loads the image with their GitHub login, so in a private repository only people with access see it. `raw.githubusercontent.com` links to a private repository return 404 without a token, so don't use them there.
   ```markdown
   <img src="https://github.com/<owner>/<repo>/blob/screenshots/pr-<number>/<file>.png?raw=true" width="320">
   ```
   `width` keeps large screenshots readable. A table puts variants side by side (e.g. light and dark mode).
   Whether the images load can't be checked from the command line: github.com pages don't accept `gh`'s token and answer 404. After posting, ask the user to open the comment once and confirm the images show.
5. **Post them in a comment** (`gh pr comment <number> --body-file <file>`), so the description stays short, and mention the comment in the description. Say in the comment that the branch is only for the images and must not be merged.
6. **After merging:** deleting the branch (`git push origin --delete screenshots/pr-<number>`) breaks the images in the comment. Only delete it if they are no longer needed, and tell the user.

---

## Verification Before Filing

Run repository typechecks or lints (`pnpm typecheck`, `bun check`) to ensure CI + pre-commit hooks will pass cleanly upon filing.
