# Codex CLI Agent Profile

## Quick Obligations

- Tool or command hangs: if it runs longer than 5 minutes, stop it, capture logs, and check with the user.
- Adding a dependency: research well-maintained options and confirm fit with the user before adding.

## Mindset & Process

- Instead of applying a bandaid, fix things from first principles. Find the source, solve the real problem, and do not stack a cheap patch on top of a broken design just because it is faster today.
- For nontrivial work, ground the outcome in architecture, official sources when they matter, and the current codebase. A useful default shape is:
  1. Think about the architecture.
  2. Research official docs, blogs, or papers on the best architecture.
  3. Review the existing codebase.
  4. Compare the research with the codebase to choose the best fit.
  5. Implement the fix or ask about the tradeoffs the user is willing to make.
- Write idiomatic, simple, maintainable code with readable, nice APIs. Prefer clarity and a clean interface over cleverness or unnecessary complexity. Always ask yourself if this is the most simple intuitive solution to the problem.
- Clean up unused code ruthlessly. If a function no longer needs a parameter or a helper is dead, delete it and update the callers instead of letting the junk linger.
- **Search before pivoting.** If you are stuck or uncertain, do a quick web search for official docs or specs, then continue with the current approach. Do not change direction unless asked.

## Testing Philosophy

- Avoid mock tests; do unit or e2e instead. Mocks are lies: they invent behaviors that never happen in production and hide the real bugs that do.
- Test everything with rigor. Our intent is ensuring a new person contributing to the same code base cannot break our stuff and that nothing slips by. We love rigour.

## Language Guidance

### TypeScript

- Do not use `any`; we are better than that.
- Using `as` is bad, use the types given everywhere and model the real shapes.
- If the app is for a browser, assume we use all modern browsers unless otherwise specified; we do not need most polyfills.

### React & Frontend

- For React work, follow current React best practices. If you are unsure or the codebase is doing something weird, research the current official docs and the repo's existing patterns before changing things instead of guessing or cargo-culting stale advice.
- Keep components small, focused, and reusable. Prefer reusable components, hooks, and helpers in their own files instead of giant multi-purpose components or mega files.
- Prefer composition and clear data flow over prop soup, duplicated state, and clever abstractions that nobody wants to debug later.
- Reuse the repo's existing design system, primitives, and styling patterns first. If there is no design system yet, build one from shared tokens and reusable primitives, and prefer mature accessible building blocks over reinventing common widgets from scratch.

### Playwright & Electron E2E

- Playwright test plumbing should use typed fixtures and app-side test facets over ad hoc helpers that smuggle state through globals. If that path is not obvious, read the official Playwright fixture docs and the repo's existing fixture setup before adding new machinery.
- Do not stuff JavaScript objects or event logs onto `window` to route state between the app and Playwright. Treat that as a design smell. Test code runs in the Playwright/Node environment, `page.evaluate` runs in the page or renderer environment, and Electron main-process state is somewhere else entirely.
- Assert the user-visible app behavior or durable application state that the action should produce. Do not add broad internal event tracking just to prove a click fired, unless the event itself is the product contract.
- If a test must observe an internal event, keep the listener scoped to the single assertion or fixture lifetime. Avoid long-lived global tracking state that survives across windows, projects, or tests.
- For native menus and Electron shell flows, use the real existing UI or an app-side fixture/facet that activates the existing menu item. Do not dynamically create menu items or other UI during tests.
- Keep platform-specific branching in the application or main-process helper that owns the behavior when possible. Playwright specs should ask the app for the right action and assert the result, not duplicate OS logic.
- Keep the diff small. Reuse the original helper when behavior is the same, collapse duplicate code, and inline trivial shape checks instead of creating tiny one-off abstractions that make the test harder to read.

## Environment & Setup

- Most tools on this local system are managed through `mise`; `mise` is the preferred way of managing tools.
- Always use `pnpm`.
