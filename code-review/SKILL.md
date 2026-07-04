---
name: code-review
description: How to review code changes — verified findings over plausible guesses, severity-ranked comments, judgment about what's worth raising vs letting go, and spec/ticket coverage checks. Use whenever reviewing a pull request, a diff, a branch, or a teammate's/agent's proposed change; whenever asked to "look over", "check", or "give feedback on" code; and before approving or merging anything. For the security dimension of a review, also read references/security.md.
---

# Code Review

A review has two jobs, in strict priority order: **catch what would hurt in production** (bugs, data loss, security, broken contracts), and **protect the codebase's long-term shape** (conventions, patterns, maintainability). Everything else — phrasing, style opinions, cleverness — is noise that dilutes those two signals.

**Precedence**: the project's own conventions define "correct style" here. Review against what the codebase establishes ([code-standards](../code-standards/SKILL.md) where the project has no opinion), not against personal preference.

## 1. Verify before asserting — the cardinal rule

A plausible-but-wrong finding costs more than a missed one: the author burns time refuting it, and your next ten findings get skimmed. Before posting any claim:

- **Read beyond the diff.** Open the surrounding function, the callers, the type definitions. Most false positives come from reviewing hunks in isolation — the "missing null check" is three lines above the hunk.
- **Construct the failure scenario.** A real finding names concrete inputs or state that produce the wrong outcome ("if two webhooks arrive within the TTL window, both pass the lock check because…"). If you cannot construct the scenario, you have a suspicion, not a finding — phrase it as a question instead.
- For high-stakes claims (security, data loss, "this will corrupt X"), run an adversarial pass: genuinely try to refute your own finding, or have an independent agent try — see [advising](../advising/SKILL.md). Post only what survives.

## 2. Severity — rank it, and don't cry wolf

Attach a severity to every finding so the author knows where to spend attention:

- **critical** — data loss or corruption, security vulnerability, broken payment/money paths, crash on a common path. Merge should stop.
- **major** — incorrect behavior users will actually hit, missing error handling on a likely failure, a race with a realistic trigger, breaking an API contract.
- **minor** — real defect with limited blast radius, convention violation, maintainability smell.

Inflating severity to get attention works exactly once. A review whose criticals are real gets its criticals read.

## 3. What's worth a comment — and what to let go

**Raise:**
- Bugs and edge cases (empty, concurrent, oversized, malformed, unauthorized) with their failure scenario.
- Missing or swallowed error handling on paths that can realistically fail.
- Security issues — walk [references/security.md](references/security.md) for any diff touching input handling, auth, queries, secrets, or file/network access.
- **Reinvention**: the change introduces a new pattern or utility where the codebase already has one. Cite the existing one by path — that citation is what makes the comment actionable rather than an opinion.
- Contract drift: the diff doesn't do what the PR/ticket says, does only part of it, or silently does more. State what's missing or extra explicitly.
- Missing tests for the new behavior — and weak tests: assertions that can't fail, mocks verifying mocks ([testing](../testing/SKILL.md)).

**Let go:**
- Style a formatter/linter should own. If it matters, the fix is CI config, not a review comment.
- Subjective preference where the project has no convention and both forms are fine.
- Hypothetical purity ("what if someday…") with no realistic trigger.
- Pre-existing issues unrelated to this diff — file them separately instead of scope-creeping the review.

A ten-comment review where three matter teaches authors to skim. Cap the nits; keep the signal.

## 4. Writing the finding

- Anchor to the exact file and line; one finding per comment.
- Structure: **what's wrong → concrete failure scenario → suggested fix**. A finding with a proposed diff or direction gets fixed; a finding that only points gets debated.
- When uncertain, ask the specific question rather than asserting: "Is `installationId` guaranteed present for fork PRs? If not, this throws at line 42."
- Say what's good when it's load-bearing (a clean abstraction worth keeping, a test that catches something subtle) — it tells the author what *not* to change in the next revision, which is information, not flattery.
- The summary leads with the verdict and the criticals. Never bury a data-loss finding under formatting notes.

## 5. Review the whole change, not just the lines

- **Tests**: do they exercise the new behavior and its edges, or just inflate coverage?
- **Migrations/config/infra** files in the diff get the same scrutiny as code — a bad migration is the most expensive line in most PRs (see [sql-and-migrations](../sql-and-migrations/SKILL.md) if present).
- **Blast radius**: who calls the changed function? Does the diff change behavior for callers not visible in it?
- **Docs and contracts**: if the change alters an API/event shape, are the schema, docs, and consumers updated?
