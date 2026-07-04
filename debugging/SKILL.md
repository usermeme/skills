---
name: debugging
description: Systematic root-cause debugging — reproduce first, read the actual evidence, falsify one hypothesis at a time, never shotgun-fix. Use whenever investigating a bug, a failing or flaky test, an error message, unexpected behavior, a production incident, or whenever a fix attempt didn't work and you're about to try another. Especially applies when you feel confident you already know the cause — that's when pattern-matching substitutes for evidence.
---

# Debugging

Debugging is hypothesis-driven search, not fix-guessing. The loop:

**reproduce → observe → hypothesize → run the cheapest falsifying experiment → fix → verify + regression-test**

Every shortcut around this loop has the same failure mode: a change that makes the symptom disappear without anyone knowing why — which means the bug is still there, wearing a different symptom.

## 1. Reproduce before anything else

A bug you can't trigger on demand can't be verified as fixed. First deliverable is a **minimal, deterministic reproduction** — ideally a failing test, because it doubles as the regression test later ([testing](../testing/SKILL.md)).

- Shrink it: remove every input, flag, and step that doesn't change the outcome. The smaller the repro, the fewer places the bug can hide.
- Can't reproduce? That is itself evidence — the trigger lives in the difference between your environment and the failing one (data, timing, config, version, concurrency). Enumerate those differences and test them; don't fix blind.

## 2. Read the actual evidence

Most wrong diagnoses come from reading the error's *shape* instead of its *content*.

- Read the whole error and the **first** failure in the log, not the last — cascading errors bury the cause under consequences.
- Read stack traces to the deepest frame in *your* code; note the exact values in the message, not just the exception type.
- Look at what the code **actually says**, not what you remember it saying. Re-read the function the trace points at, even if you wrote it an hour ago.
- Check the obvious environmental suspects early — wrong branch, stale build, cached dependency, different config — they cause a disproportionate share of "impossible" bugs.

A symptom that pattern-matches a familiar failure often has a different cause. Familiarity is a hypothesis to test, not a diagnosis.

## 3. One hypothesis, cheapest falsifying experiment

State the hypothesis precisely enough to be wrong: "the cache returns stale entries after a write from another process" — not "something's wrong with the cache". Then design the *cheapest* experiment that can prove it false: a log line at the boundary, an assertion, a narrower test, one value printed.

- **Change one variable per experiment.** Two changes with a green result later leaves you not knowing which mattered — that's a superstition, not knowledge.
- **Bisect when the search space is large.** Over history: `git bisect` with the repro as the predicate. Over code: disable half the pipeline, then half again. Over input: shrink the payload until the failure disappears, then look at the last thing removed. Halving beats staring — every time.
- Instrument rather than re-read: a well-placed log of the actual runtime value beats another ten minutes of imagining what the value probably is.

## 4. No shotgun fixes

If a change makes the symptom vanish and you cannot articulate *why*, do not keep it. You now have an undiagnosed bug **plus** a cargo-cult change that will mislead the next reader. Revert, understand, then fix deliberately.

The fix is complete when you can answer: what was the defect, why did it produce exactly these symptoms, and why does this change eliminate the cause (not the symptom)?

## 5. Stuck-loop protocol

Two failed fix attempts is the tripwire. At that point your context is contaminated — some assumption you've already accepted is wrong, and further attempts inherit it. Stop and:

1. Revert to a clean state (uncommitted experiments out).
2. Write down what you *know* (observed) vs what you've *assumed* (never verified). Test the assumptions — the bug usually lives in that second column.
3. Bring in fresh eyes with clean context: brief an independent agent with the symptoms and the code only — **not** your failed attempts or your theory — and compare its diagnosis with yours. See [advising](../advising/SKILL.md), fresh-context debugging.
4. Widen the frame: is the bug actually upstream of where you're looking (bad input accepted earlier, wrong data written long before it's read)?

## 6. After the fix

- **Regression test first-class**: the repro from §1, checked in, failing before the fix and passing after.
- **Look for siblings**: the same mistake usually exists wherever the same pattern was copied. Search for them now, while you understand the defect exactly.
- **Record the non-obvious**: if the root cause was surprising (a library quirk, an environmental trap), persist it where the next person will find it — `AGENTS.md`, the runbook, a comment at the trap site stating the constraint.
- Report faithfully: what the root cause was, what changed, how it was verified. "It seems to work now" is not a debugging outcome.
