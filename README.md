# Skills Monorepo

A collection of agent skills reflecting the engineering standards and patterns of a senior software engineer. Compatible with any agent that supports the `SKILL.md` format (Claude Code, Gemini CLI, Antigravity, etc.).

## Repository Structure

- `code-standards/` — Foundational coding standards (SOLID, clean code, naming, modularity, error handling) when writing new modules, components, or APIs. Language- and framework-specific guidance lives in its references, loaded on demand:
  - `references/typescript.md` — strict typing, interfaces vs types, type guards, discriminated unions.
  - `references/react.md` — component architecture, hook ordering, predictable hooks and state.
  - `references/slot-based-layout.md` — slot-based UI composition for layouts and dashboards (React & Vue).
- `agentic-workflow/` — Operating discipline for autonomous coding agents (clarify, plan, track, verify, report) at the start of ambiguous or multi-file tasks.
- `advising/` — Second-opinion protocol using an independent agent on the smartest available model for hard-to-reverse design choices, adversarial verification, or stuck loops.
- `testing/` — Test design, boundary mocking, level selection, and flakiness prevention when writing, modifying, or reviewing tests. Stack specifics load on demand:
  - `references/typescript.md` — Vitest/Jest, fake timers, MSW at the network boundary, React Testing Library, supertest + real-DB integration patterns, snapshot discipline.
- `debugging/` — Systematic root-cause debugging (reproduce, observe, hypothesize, falsify) when investigating bugs, flaky tests, or failed fix attempts.
- `code-review/` — Code review methodology with verified failure scenarios, severity ranking, and security checks when reviewing PRs, diffs, or branches.
  - `references/security.md` — attack-scenario checklist: injection, authn/authz and IDOR, secrets and log leaks, SSRF, unbounded work, XSS/CSRF, TOCTOU, crypto and dependency risk.
- `git-hygiene/` — Commit, branch, pull-request, and history-safety discipline when committing, branching, opening PRs, or rewriting history.
- `worktree/` — Automated management of bare git worktrees, `.env`/config file syncing, and devcontainer overrides (`usermeme/devcontainer-features`).
- `sql-and-migrations/` — Database discipline for zero-downtime migrations (expand/migrate/contract), DDL locks, schema constraints, and production queries.
- `refactoring/` — Behavior-preserving code restructuring with characterization tests, small reversible steps, and strict separation from behavior changes.

## Design

Standards are consolidated into a single `code-standards` skill instead of one skill per language/framework. One skill means one trigger for writing new code, no duplicated or conflicting rules across files, and progressive disclosure: the agent loads only the reference relevant to the code it is writing.

The same logic applies across skills: `critical-thinking` was merged into `agentic-workflow` because both fired on the same situations (ambiguous tasks, unverified assumptions, weak plans) — two overlapping triggers make the agent's skill selection worse, not better. Each skill's frontmatter `description` is kept to two concise sentences (`<what it covers>. Use when <distinct triggers>.`) so the always-loaded catalog stays lightweight and multiple skills do not co-activate unnecessarily.

## Installation

**Claude Code** — copy or symlink the skill folders into `.claude/skills/` (project scope) or `~/.claude/skills/` (user scope).

**Antigravity** — copy or symlink the skill folders into `~/.agents/skills/` (or `.agents/skills/` in a workspace), or reference them from `AGENTS.md`:

```markdown
Before starting any non-trivial task, read and follow ~/skills/agentic-workflow/SKILL.md.
For second opinions on plans, diagnoses, and findings, follow ~/skills/advising/SKILL.md.
```

**Via the `skills` utility:**

```bash
npx skills add usermeme/skills
```
