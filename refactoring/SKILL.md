---
name: refactoring
description: Behavior-preserving restructuring done safely — characterization tests before touching untested code, small reversible steps that stay green, strict separation of refactoring from behavior change, and scope control. Use whenever refactoring, restructuring, "cleaning up", extracting modules, renaming across a codebase, paying down tech debt, or preparing code for a feature that doesn't fit its current shape.
---

# Refactoring

Refactoring changes structure while preserving behavior — that definition is the entire discipline. The moment behavior changes too, you're doing two risky things at once with the safety rails of neither: tests can't tell your intended change from your accidental one, and the reviewer can't either.

## 1. Before touching anything: a safety net and a goal

- **Tests are the definition of "behavior preserved".** If the code you're about to restructure isn't covered, write **characterization tests first** — tests that pin down what the code *actually does now* (including its quirks), not what it should do. Feed it representative inputs, assert the current outputs. Ugly-but-true tests are the net; without them, "the refactor broke nothing" is a feeling. ([testing](../testing/SKILL.md))
- Bugs discovered while characterizing get *documented* (a test asserting the buggy behavior, marked as such, plus a ticket) — not silently fixed mid-refactor. Fixing it is a behavior change; it ships separately (§3).
- **Define done before starting**: "extract the pricing rules into a pure module with the handler calling it" is a goal; "clean this up" is a random walk. Refactoring without a target endpoint doesn't terminate.
- For a large or risky restructuring, have the plan challenged before executing — [advising](../advising/SKILL.md), plan review.

## 2. Small reversible steps, always green

Work as a sequence of mechanical transforms — rename, extract function/module, inline, move, replace-conditional-with-polymorphism — each one small enough that:

- the tests run green **after every step**, and
- any step can be reverted alone without unwinding the rest.

When a step goes red and the fix isn't obvious in a minute, revert the step — don't debug forward through a broken intermediate state; that's how a refactor becomes a rescue mission. Long-red is the signature of a step that was too big; halve it.

Lean on tooling for the mechanical part: IDE/LSP renames and automated codemods are categorically safer than hand-editing 40 call sites — the tool doesn't get bored on file 37.

## 3. Never mix refactoring with behavior change

The prime rule, worth its own section:

- Separate commits at minimum, separate PRs when the refactor is big ([git-hygiene](../git-hygiene/SKILL.md)). A commit titled `refactor:` must show identical behavior at its boundary — the reviewer verifies structure; the tests verify behavior; neither can do its job on a mixed diff.
- The standard sequence for "this feature doesn't fit the current shape": **refactor first** (green, no behavior change, merge it), **then** the feature lands as a small clear diff on the new shape. "Make the change easy, then make the easy change."

## 4. Scope control

Refactoring generates its own todo list as you go — that's a trap.

- **Fix what you came to fix.** New debt discovered mid-refactor gets a note/ticket, not a detour. Chasing every smell turns a one-day refactor into a three-week branch that conflicts with everyone.
- Boy-scout rule applies *within the diff you're already touching* — better name here, dead branch removed there — not as license to wander into adjacent modules.
- Long-lived refactoring branches rot: rebase pain grows with every teammate's merge. Land in slices; a refactor that can't be sliced into independently-mergeable green steps needs a different strategy (strangler pattern: build the new shape alongside, migrate callers incrementally, delete the old at the end).

## 5. Boundaries and cleanup

- Changing a public interface isn't pure refactoring — it has consumers. Migrate callers in the same change if internal; version/deprecate first if external.
- **Delete dead code; never comment it out.** Git remembers everything — the commented block just lies to every future reader about being potentially needed.
- After the refactor: names still honest? Docs/comments referencing the old shape updated? `AGENTS.md`/module docs mention the new home if the move is non-obvious?
- Verify beyond the unit tests before calling it done — run the real flow the code serves ([agentic-workflow](../agentic-workflow/SKILL.md) §6); structure moved, wiring is where refactors actually break.
