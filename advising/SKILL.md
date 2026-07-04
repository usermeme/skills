---
name: advising
description: Consult an independent agent for a second opinion before committing to important decisions — reviewing an implementation plan, judging a risky design, adversarially verifying a bug diagnosis or code-review finding, or breaking out of a stuck debugging loop. Use whenever a decision is expensive to reverse, whenever you notice you are uncertain but about to proceed anyway, before large refactors, and before presenting conclusions the user will act on. If the environment supports subagents or multiple agent sessions (Claude Code Task tool, Antigravity Agent Manager), spawn one; otherwise simulate the adversarial pass explicitly.
---

# Advising — Second Opinions from Independent Agents

A single agent reviewing its own work shares all of its own blind spots: the same misreading of the requirement, the same hallucinated API, the same overconfident diagnosis. An independent reviewer with fresh context and an explicit mandate to disagree catches what self-review structurally cannot. This skill is how to use that.

## When to seek advice

Consult a second agent when the **cost of being wrong exceeds the cost of the consultation**:

- **Before committing to a plan** for a large feature or refactor — have the plan critiqued before code exists, when changing course is free.
- **Design forks** — two credible architectures and the choice is hard to reverse later (storage engine, API shape, framework).
- **Verifying findings you will assert** — bug diagnoses, code-review comments, security claims. Plausible-but-wrong findings are the #1 credibility killer for agents.
- **Stuck loops** — you've attempted the same fix twice and it still fails. Your context is now contaminated with a wrong assumption; fresh eyes don't inherit it.
- **Anything security-, data-loss-, or money-adjacent.**

Skip it for routine work, reversible details, and anything a test can answer faster. Advice is a tool for judgment calls, not a tax on every step.

## How to brief the advisor

The consultation's value is determined by the brief. Three rules:

1. **Give complete context, not your conclusion first.** State the problem, constraints, and evidence. If you lead with your preferred answer, you get agreement, not review.
2. **Assign a stance.** "Review this" produces politeness. Effective mandates are directional:
   - *Adversarial*: "Try to refute this diagnosis. Default to 'refuted' if uncertain."
   - *Risk-focused*: "What breaks at 10× scale? What's the worst failure mode?"
   - *Alternative-seeking*: "Propose a materially different approach and argue for it."
3. **Demand a verdict, not vibes.** Ask for a structured answer: verdict (agree / disagree / needs-evidence), the strongest counter-argument, and what evidence would settle it.

**Example brief** (adversarial verification of a finding):

> You are an independent reviewer. Below is a code-review finding I intend to post. Your job is to REFUTE it if possible: read the referenced code, check whether the claimed failure can actually occur, and identify any context that makes it a false positive. Finding: [finding + code excerpt + file paths]. Reply with: verdict (CONFIRMED / REFUTED / UNCERTAIN), your reasoning, and the exact input or state that triggers the bug if confirmed.

## Patterns

- **Plan review** — after drafting an implementation plan, one advisor critiques feasibility against the *actual* codebase (give it file paths to read, not your summary of them).
- **Adversarial verification** — every finding you'll assert gets one refutation attempt. For high-stakes claims, use 2–3 advisors with different lenses (correctness, security, does-it-reproduce) and require majority survival — diverse lenses catch failure modes redundant reviewers can't.
- **Judge panel for wide-open designs** — generate 2–3 independent approaches (each advisor primed differently: simplest-possible, most-scalable, best-for-user), then compare and synthesize from the winner.
- **Fresh-context debugging** — brief a new agent with only the symptoms and the code, *not* your failed attempts, so it doesn't inherit your wrong assumption. Compare its diagnosis with yours.

## Using the advice

- Disagreement is signal, never an obstacle. If the advisor refutes you, check its reasoning against the code before proceeding — do not proceed on the original path just because it was yours.
- Two independent agents agreeing after genuinely separate analysis is strong evidence. Agreement after a leading brief is worthless — if you contaminated the brief, redo it.
- You remain the decision-maker. Advice informs the call; it doesn't outsource it. When you overrule an advisor, tell the user what the dissent was and why you overruled it — that dissent is exactly the risk they'd want to know about.

## Mechanics by environment

- **Claude Code / Fable**: spawn a subagent (Task tool) with the brief; use read-only agents for review work. Multiple advisors can run in parallel in one message.
- **Antigravity**: launch a separate agent in the Agent Manager with the brief as its task; point it at the same workspace so it reads real code. Run advisors alongside your main work rather than blocking on them when possible.
- **No subagent support**: do an explicit adversarial pass yourself — write the refutation brief, then answer it in a genuinely separate pass *before* looking back at your original reasoning. Weaker than true independence, far better than nothing.
