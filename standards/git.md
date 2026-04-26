# Git

## Rule: Commit message format

**Do:** Write a short subject line (fits in `git log --oneline`), a blank line, then detailed bullet points.
**Don't:** Use a single-line commit for non-trivial changes, or write a wall-of-text subject.
**Why:** `git log --oneline` stays scannable; the body documents the why.
**Detection:** Commit subject > ~72 chars, or body present without a blank line after subject.

## Rule: Never bypass safety checks

**Do:** Resolve hook/CI failures.
**Don't:** Use `--no-verify`, `git push --force` on shared branches, `git reset --hard` over unfamiliar work, or amend published commits.
**Why:** These actions destroy work or hide failures.
**Detection:** Reviewer sees force-push or no-verify in command logs.


## Rule: Don't modify code another developer recently authored without confirming intent

**Do:** Before changing or reverting a non-trivial block of code, run `git blame` (or check the file history in your IDE). If the change is recent and from another team member, leave a comment on the PR or DM the author asking *why* before you "fix" it. Their change was deliberate; you owe them ten seconds of clarification before overwriting it.
**Don't:** Quietly revert two lines that another developer recently added because they "looked unnecessary" or "Copilot said so". Especially in shared service files (`security.ts`, `service.ts`, middleware) where the change probably encodes a bug fix you don't see.
**Why:** Code that looks redundant in isolation is often load-bearing — it's the fix for a production bug, a security hardening, or a fix for a race condition the new author isn't yet aware of. Silently undoing it re-opens the bug. PR reviewers will catch this *if* the reviewer happens to be the original author; otherwise it ships.
**Example:** If `git blame` shows `NCynkus_cobank` added the lines two PRs ago, your PR description (or a `@`-mention in the description) should say "reverting lines added in #56 — confirmed with @NCynkus_cobank" — or you shouldn't be touching them.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2819506788
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2819531658
**Detection:** A diff that removes/replaces lines whose `git blame` author is someone other than the PR author and whose age is < ~30 days, with no PR-description note explaining the change and no `@`-mention of the original author.
