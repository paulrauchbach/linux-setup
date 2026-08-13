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

### Good Description Example:
> My "new worktree" default was ignored when starting new threads on existing worktrees. Super unintuitive. Now your preferences always apply.

### Bad Description Example:
> Removed implicit workspace carry-over from every "new thread" entry point (cmd+n, sidebar buttons, command palette). Deleted contextualThreadOptions, startNewThreadInProjectFromContext, and seed-context machinery.

---

## Verification Before Filing

Run repository typechecks or lints (`pnpm typecheck`, `bun check`) to ensure CI + pre-commit hooks will pass cleanly upon filing.
