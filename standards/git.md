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
