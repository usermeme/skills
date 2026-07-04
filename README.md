# Skills Monorepo

A collection of agent skills reflecting the engineering standards and patterns of a senior software engineer. Compatible with any agent that supports the SKILL.md format (Claude Code, Gemini CLI, etc.).

## Repository Structure

- `code-standards/` — Foundational engineering standards: SOLID, clean code, naming, module organization, and error handling. Language- and framework-specific guidance lives in its references, loaded on demand:
  - `references/typescript.md` — strict typing, interfaces vs types, type guards, discriminated unions.
  - `references/react.md` — component architecture, hook ordering, predictable hooks and state.
  - `references/slot-based-layout.md` — slot-based UI composition for layouts and dashboards (React & Vue).
- `critical-thinking/` — Engineering mindset: verify before acting, challenge weak plans, surface inconsistencies.
- `agentic-workflow/` — Operating discipline for autonomous coding agents, modeled on Claude Code / Fable 5: clarify with structured questions before assuming, plan-then-approve, visible task tracking, end-to-end verification before claiming done, outcome-first reporting, safety rails around destructive actions. Includes Antigravity-specific mappings (implementation-plan artifacts, task lists, browser verification).
- `advising/` — Second opinions from independent agents: when to consult (expensive-to-reverse decisions, stuck loops, findings you'll assert), how to brief an advisor without contaminating it, adversarial-verification and judge-panel patterns, environment mappings (Claude Code subagents, Antigravity Agent Manager).
- `testing/` — Tests that catch real regressions: behavior-first testing through public interfaces, what deserves a test, mocking only at boundaries, unit/integration/e2e selection, determinism and flakiness elimination, honest assertions. Stack specifics load on demand:
  - `references/typescript.md` — Vitest/Jest, fake timers, MSW at the network boundary, React Testing Library, supertest + real-DB integration patterns, snapshot discipline.
- `debugging/` — Systematic root-cause debugging: reproduce first (as a failing test), read the actual evidence instead of pattern-matching, one hypothesis per experiment, bisection, no shotgun fixes, and a stuck-loop protocol that hands off to fresh-context advising after two failed attempts.
- `code-review/` — Reviewing changes: verify findings before asserting (construct the failure scenario), severity taxonomy, what's worth a comment vs what to let go, reinvention detection with citations, ticket-coverage checks, reviewing tests and migrations too.
  - `references/security.md` — attack-scenario checklist: injection, authn/authz and IDOR, secrets and log leaks, SSRF, unbounded work, XSS/CSRF, TOCTOU, crypto and dependency risk.
- `llm-engineering/` — Building on LLMs: escalate architecture only when needed (call → chain → agent → multi-agent), tool design where the description is the interface, schema-enforced structured outputs, context budgeting and cache-friendly prompt layout, reliability and cost telemetry, evals before prompt-tweaks, prompt-injection defense via capability limitation.
- `git-hygiene/` — Atomic commits (never mix refactor with behavior change), messages whose body explains why, branch discipline, PR descriptions reviewers can act on, and history-safety rules around rebase and force-push.
- `sql-and-migrations/` — Database discipline ordered by blast radius: expand/migrate/contract migrations, DDL lock awareness, constraints in the database, honest column types, N+1 and indexing, keyset pagination, tight transactions, destructive-statement safety rails.
- `refactoring/` — Behavior-preserving restructuring: characterization tests before touching untested code, small always-green reversible steps, strict refactor/behavior separation, scope control, and strangler pattern for restructurings too big to slice.

## Design

Standards are consolidated into a single `code-standards` skill instead of one skill per language/framework. One skill means one trigger for "writing code", no duplicated or conflicting rules across files, and progressive disclosure: the agent loads only the reference relevant to the code it is writing.

## Installation

**Claude Code** — copy or symlink the skill folders into `.claude/skills/` (project scope) or `~/.claude/skills/` (user scope).

**Antigravity** — copy the skill folders into Antigravity's skills directory if your version exposes one (check Settings → Agent). Otherwise, reference them from `AGENTS.md` in the workspace, which Antigravity always reads:

```markdown
Before starting any non-trivial task, read and follow ~/skills/agentic-workflow/SKILL.md.
For second opinions on plans, diagnoses, and findings, follow ~/skills/advising/SKILL.md.
```

**Via the `skills` utility:**

```bash
npx skills add usermeme/skills
```
