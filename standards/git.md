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

**Do:** Before changing or reverting a non-trivial block of code, run `git blame` (or check the file history in your IDE). If the change is recent and from another team member, leave a comment on the PR or DM the author asking _why_ before you "fix" it. Their change was deliberate; you owe them ten seconds of clarification before overwriting it.
**Don't:** Quietly revert two lines that another developer recently added because they "looked unnecessary" or "Copilot said so". Especially in shared service files (`security.ts`, `service.ts`, middleware) where the change probably encodes a bug fix you don't see.
**Why:** Code that looks redundant in isolation is often load-bearing — it's the fix for a production bug, a security hardening, or a fix for a race condition the new author isn't yet aware of. Silently undoing it re-opens the bug. PR reviewers will catch this _if_ the reviewer happens to be the original author; otherwise it ships.
**Example:** If `git blame` shows `NCynkus_cobank` added the lines two PRs ago, your PR description (or a `@`-mention in the description) should say "reverting lines added in #56 — confirmed with @NCynkus_cobank" — or you shouldn't be touching them.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2819506788
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2819531658
**Detection:** A diff that removes/replaces lines whose `git blame` author is someone other than the PR author and whose age is < ~30 days, with no PR-description note explaining the change and no `@`-mention of the original author.

## Rule: PR descriptions and templates must be fully completed

**Do:** Fill in all required sections of the PR template with concrete details:

- Link the associated Azure DevOps story/task/bug
- Write a clear summary of what changed and why
- Describe how it meets acceptance criteria
- Document testing performed
- Complete all checklist items before marking ready for review

**Don't:** Leave placeholder text like "XXXXXX", "TODO", or blank sections in PR descriptions. Don't submit with unchecked checklist items without explanation.

**Why:** Complete PR context enables faster, better reviews. Blank sections hide dependencies, testing gaps, and acceptance criteria—leading to rework, missed bugs, or incomplete deployment verification.

**Detection:** PR description contains "PLACEHOLDER", "TODO", "XXXXXX", or required template sections are left blank.

## Rule: Branch and PR names must follow semantic versioning + issue tracking

**Do:** Name branches, PRs, and first commits with this format:

- `[type]-[issue-number]-[what-it-does]`
- Example: `feat-123456-implement-health-check`
- Where type = feat/fix/chore/docs, issue number = Azure DevOps story/task/bug identifier

**Don't:** Use vague names like `update-code`, `fixes`, or omit issue numbers. Don't use uppercase or underscores in the action description.

**Why:** Since commits are squashed, the first commit message becomes permanent history. Full traceability to Azure DevOps enables deployment tracking and rollback context.

**Detection:** Branch/PR/commit missing semantic type, Azure DevOps identifiers, or description; or using inconsistent separators.
