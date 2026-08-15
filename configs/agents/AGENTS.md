# Person AGENTS.md by Paul

I'm Paul. You're my agent. We will be working together a lot, so I thought it would be worth introducing myself.
I am a native german, though fluent in english. Still aim to provide your answers as simple and clear as possible. Im law, as well as cs educated. I'm not a trained software engineer. I've taught software development myself. I've never worked somewhere where I had to write code. Thus I'n unfamiliar with most 'developer slang'.
I love to build. I focus on building complex things as simple as possible. I love to find ways to reduce complexity when solving problems.
I wanted to share some of my preferences here so we can be more aligned as we work together.

Treat these instructions as solid, high-yield defaults. User instructions in active prompts override both global defaults and repository configs.

## Coding

- Keep things simple. Channel "YAGNI" (You Aren't Gonna Need It) energy unless explicitly directed otherwise. Do not over-engineer or add premature abstractions.
- Typesafety is essential.
- Do not start long-running dev servers by default. Assume the user may already have one running unless the task specifically requires it.
- Always prefer quick, targeted verification scripts (e.g., `typecheck`, `lint`, or focused unit tests) over full builds.
- Run full production builds only when necessary to verify changes, when requested by the user, or when no cheaper reliable check exists.
- A main goal should always be creating code which is understandable, easy to maintain and well documented.

### Typescript

- Do not write loose or lazy TypeScript that looks like Python rewritten in JS syntax.
- Avoid `any` unless there is no reasonably typed alternative or the user explicitly requests it.
- Avoid one-line functions or helper wrappers that exist solely to force-cast types.
- Write clean, expressive TypeScript in ways that Matt Pocock would be proud of.
- Don't be scared to propose bold architectural or code simplify ideas if they can meaningfully benefit our work.

### Visual & UI Design Rules

- Keep orchestration logic pure and UI components dumb and focused.
- Prototype or stand up UI in isolated preview states or minimal contrasts first; do not break production components.
- Ensure components adapt fluidly to containers and screens. Avoid hardcoded static pixel heights/widths or excessive nested card abstractions.

### Preferred Technologies

If tech choices are not already specified in the repository context, prefer:

- Next.js or React as frameworks
- mise for tool-versioning
- pnpm as a package manager
- monorepos, setup with turbo
- local-first solutions which can be self-hosted
- uv for python

### Pull Request & Git Workflow

- Before creating a PR, check whether a PR for the current branch already exists.
- Review local diffs against `origin/main` to verify all content aligns cleanly with the user's intent.
- Match PR title conventions (e.g. `feat(...)`, `fix(...)`, `perf(...)`). Write clear descriptions focusing on user value rather than file inventory lists.
- when asked to review a PR use the babysit-pr skill. This skill defines how the review should be done, i.e. using comments.

## Additional Tips

- A question is a request for an answer and analysis—**not** for code or state changes.
- never use subagents without the user explicitly asking for it.
- When multiple agents run concurrently, state explicit file/directory ownership up front so sub-agents do not collide on the same files.
- Don't verify with browsers or computer use unless the user explicitly agrees or requests it.
