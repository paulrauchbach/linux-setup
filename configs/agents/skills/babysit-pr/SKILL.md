---
name: babysit-pr
description: Monitor a pull request through review and CI. Use when the user asks to monitor, watch, or babysit a PR.
---

# Babysit PR Skill (`babysit-pr`)

## Philosophy
All the repos I work in run various AI reviews and automated checks. They're helpful, even if they are not always right.

---

## Instructions

1. **Harness Monitoring & Polling:**
   - If your harness offers native tools to monitor a PR, use them so you can respond when comments arrive.
   - Otherwise, poll the PR for new comments and CI checks using `gh pr view` and `gh pr checks`.

2. **Evaluating Comments & Checks:**
   - Only act on checks and comments newer than the latest push.
   - Verify every finding against the source code before making changes.
   - Fix real findings and genuine CI failures. Distinguish repository failures from infrastructure flakes.

3. **Rebasing & Obsolete PRs:**
   - Keep an eye on changes to `main` and rebase when needed (`git rebase origin/main`).
   - If an overlapping PR makes this one obsolete, stop monitoring, report it to the user, and ask before closing the PR unless closure was explicitly authorized.

4. **Replying on Behalf of User:**
   - If a review bot leaves feedback you believe is invalid or not worth addressing, reply and resolve the comment.
   - Format comments left on Theo's behalf using the exact header prefix:
     ```text
     [<MODEL-SLUG>] RESPONDING ON BEHALF OF PAUL:

     <Your clear, polite explanation or resolution>
     ```

5. **Prevent Scope Creep:**
   - Do not let review feedback expand the PR beyond the user's original goal. Address real shortcomings, but avoid scope creep.
