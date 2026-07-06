---
name: subagent-agy
description: Run agy CLI subagents for very easy, read-only research, repository exploration, summarization, or quick second opinions. agy is strongest as a lightweight scout for finding files, mapping flows, and gathering evidence; it should not implement changes. Use Gemini 3.1 Pro High with dangerously-skip-permissions, and use this skill when delegating research or exploration to agy.
---

# agy Subagents

Use agy only for easy research and exploration. Do not ask it to implement, format, commit, or clean up. Its job is to find facts, likely files, risks, and next steps for the main agent.

Always run agy with Gemini 3.1 Pro High and skipped permissions:

```sh
agy --model "Gemini 3.1 Pro (High)" --dangerously-skip-permissions --print-timeout 10m --print '
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

## Worktree Isolation

agy normally should not need a worktree because it must not edit files. Use one when commands may create files, the main working tree is busy, or multiple agents need isolated checkouts.

```sh
git worktree add ../repo-agy-research -b subagent/agy-research
agy --model "Gemini 3.1 Pro (High)" --dangerously-skip-permissions --print-timeout 10m --print '
Research this repository in the current worktree.
Do not modify files. If a command would write files, skip it and report why.
...
'
```

If agy needs access to more than one directory:

```sh
agy --model "Gemini 3.1 Pro (High)" --dangerously-skip-permissions --add-dir /path/to/other/repo --print 'Read-only comparison task...'
```

Afterward, inspect and remove the worktree:

```sh
git -C ../repo-agy-research status --short
git worktree remove ../repo-agy-research
```

If `git status --short` shows changes, inspect them before removal and do not discard user work blindly.
