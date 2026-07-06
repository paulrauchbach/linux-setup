---
name: subagent-codex
description: Run Codex CLI subagents for coding, implementation, debugging, tests, code review, or multi-step repository work. Codex is strongest when the subagent must reason through code, edit files, run tests, and return a defensible implementation or review. Always use GPT 5.5 and set reasoning effort to low, medium, high, or xhigh based on task difficulty. Use this skill when delegating work to a Codex subagent, including worktree setup when isolation is needed.
---

# Codex Subagents

Use Codex for implementation, debugging, tests, refactors, reviews, and other medium or hard repo tasks. It can edit files, run commands, and verify its work.

Always use GPT 5.5. Set `model_reasoning_effort` by difficulty: `low` for simple lookups, `medium` for ordinary edits, `high` for debugging or cross-file changes, and `xhigh` for complex architecture, risky refactors, or difficult failures.

Run from the target repo:

```sh
codex exec --cd /path/to/repo --dangerously-bypass-approvals-and-sandbox -m gpt-5.5 -c model_reasoning_effort="high" - <<'PROMPT'
You are a Codex subagent. Implement the requested change.

Task:
- ...

Rules:
- Keep changes scoped.
- Do not revert unrelated user changes.
- Run relevant tests and report exact commands/results.

Return:
- Summary of changes
- Files changed
- Tests run
- Risks or follow-ups
PROMPT
```

Add `--search` only when current external facts are required.

## Worktree Isolation

Use a worktree when the subagent may edit files and you want to avoid collisions with the main working tree.

```sh
git worktree add ../repo-codex-subagent -b subagent/codex-task
codex exec --cd ../repo-codex-subagent --dangerously-bypass-approvals-and-sandbox -m gpt-5.5 -c model_reasoning_effort="high" - <<'PROMPT'
Implement the task in this worktree. Keep commits unmade unless asked.
...
PROMPT
```

After the subagent finishes:

```sh
git -C ../repo-codex-subagent status --short
git -C ../repo-codex-subagent diff
```

Review and merge manually from the worktree. Remove it only after the work is no longer needed:

```sh
git worktree remove ../repo-codex-subagent
```
