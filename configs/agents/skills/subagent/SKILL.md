---
name: subagent
description: Run a fused subagent workflow that uses agy for quick read-only research and repository exploration, and Codex for implementation, debugging, tests, refactors, or any task that may change files. Use this skill as the single front door for both lightweight scouting and deeper repo work.
---

# AGY + Codex Subagents

Use this skill when you want one subagent entry point that routes to the right tool automatically:

- Use agy for easy, read-only research, exploration, summarization, and quick second opinions.
- Use Codex for implementation, debugging, tests, refactors, reviews, or any task that may edit files or needs stronger multi-step repo reasoning.
- If the task is ambiguous, default to Codex unless it is clearly inspection-only.

## Read-Only Scout: agy

Use agy as a lightweight scout for finding files, mapping flows, and gathering evidence. It should not implement changes.

Always run agy with its newest available model, `gemini-3.6-flash-high`, and skipped permissions. The CLI expects its lowercase model ID, not its display name:

```sh
agy --model gemini-3.6-flash-high --dangerously-skip-permissions --print-timeout 10m --print '
You are a read-only research subagent.

Task:
- Explore <topic> and report what the main agent needs to know.

Rules:
- Do not modify files.
- Do not run formatting, install, build, migration, or cleanup commands.
- Use inspection commands such as rg, ls, sed, and git status/diff.
- Separate observed facts from guesses.

Return:
- Key files with short explanations
- Relevant functions, classes, config keys, or commands
- Open questions or risks
- Suggested next steps for the main agent
'
```

## Implementation Subagent: Codex

Use Codex when the task may change files, run tests, debug behavior, or needs a more capable repo worker. Keep the scope tight and ask it to report exact commands and results.

Always use GPT 5.6 Sol. Set `model_reasoning_effort` by difficulty: `low` for simple lookups, `medium` for ordinary edits, `high` for debugging or cross-file changes, and `xhigh` for complex architecture, risky refactors, or difficult failures.

Run from the target repo:

```sh
codex exec --cd /path/to/repo --dangerously-bypass-approvals-and-sandbox -m gpt-5.6-sol -c model_reasoning_effort="high" - <<'PROMPT'
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

## Worktrees

When using a worktree, store it under `~/dev/.worktrees` and run the subagent
from the worktree root.
