---
name: git-hygiene
description: Commit, branch, and pull-request discipline — atomic commits with honest messages, branch naming, PR descriptions that reviewers can act on, and the safety rules around history rewriting. Use whenever committing work, writing a commit message, creating a branch, opening or describing a pull request, or performing any git operation that touches shared history (rebase, force-push, reset).
---

# Git Hygiene

Git history is a communication channel with two audiences: the reviewer today and the engineer running `git blame`/`git bisect` at 2am in two years. Every rule here optimizes for those two readers.

**Precedence**: the project's conventions (commit format, merge vs rebase, branch scheme) win. Detect them from `git log` and CONTRIBUTING before applying defaults.

## 1. Atomic commits

One commit = one logical change that builds and passes tests on its own.

- **Never mix refactoring with behavior change** in one commit — the reviewer can't tell which diff lines alter behavior, and `bisect` loses its resolution. Same for formatting sweeps: separate commit, or better, separate PR.
- If describing the commit needs "and", split it. `git add -p` exists precisely to untangle a working tree with two changes in it.
- Don't commit: debug prints, commented-out code, secrets, generated artifacts, or `.env` files. Look at the actual staged diff (`git diff --staged`) before committing — not the file list, the diff.

## 2. Messages — subject says what, body says why

- Subject: imperative mood, ≤ 72 chars, no trailing period — `Add idempotency lock to review webhook`, not `added some fixes`. Follow the project's prefix convention (`feat:`, `fix:` …) if `git log` shows one.
- Body: the **why** — the problem, the constraint that shaped the solution, alternatives rejected. The diff already shows the what; the motivation is the only thing that's lost forever if unwritten.
- Reference the ticket/issue where one exists. Future-you will want the context thread.

## 3. Branches

- Never work directly on `main`/`master` — branch first, even for "quick" fixes; quick fixes are where mistakes ship.
- Names: `type/short-description` (`fix/fork-pr-clone`, `feat/ticket-agent`) or the project's scheme. The name should let a teammate guess the content.
- Keep branches short-lived and focused; a branch tracking three ideas becomes an unreviewable PR.

## 4. Pull requests

A PR description is the reviewer's map. Include:

- **What & why** — one paragraph; link the ticket.
- **How it was verified** — the commands/flows actually run, not "tested locally". Screenshots for UI.
- **What to look at hardest** — point the reviewer at the risky part; you know where it is.
- Anything intentionally out of scope, so it isn't re-litigated in comments.

Keep PRs small enough to review honestly (~400 lines of real change is a common ceiling; beyond that review quality collapses to skimming). A big feature ships as a stack of small PRs, not one monolith.

## 5. History safety

- **Never rewrite shared history**: no force-push to branches others use, and never to protected branches. On your own PR branch, `--force-with-lease` (not `--force`) after a rebase is fine — it aborts instead of overwriting work you haven't seen.
- Fixing mistakes: prefer `revert` on anything already shared (it's append-only and honest); `reset`/`amend` only for strictly local, unpushed work.
- Merge vs rebase: whatever the project does. Don't introduce merge commits into a rebase-only repo or vice versa.
- Before any destructive operation (`reset --hard`, branch delete, `clean`), check what you're about to lose — `git status`, `git stash` as the cheap insurance. As an agent: **don't commit or push at all unless the user asked**, and treat force-push and history rewriting as confirmation-required actions.
