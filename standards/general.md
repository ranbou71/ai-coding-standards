# General

Language-agnostic rules. Apply everywhere unless a topic file says otherwise.

## Rule: Fix problems properly, never suppress them

**Do:** Use the correct API, updated syntax, or real fix.
**Don't:** Mask errors with `ignoreDeprecations`, `@ts-ignore`, `eslint-disable`, `# type: ignore`, broad `try/except: pass`, etc.
**Why:** Suppressions hide regressions and rot the codebase.
**Detection:** Grep for ignore/disable directives in diffs.

## Rule: No "wrapper" naming

**Do:** Name things by what they are or do (`HttpClient`, `withRetry`, `RetryingFetcher`).
**Don't:** Use the word "wrapper" in any identifier — files, classes, functions, variables.
**Why:** "Wrapper" describes mechanism, not purpose; it hides intent.
**Detection:** `grep -i wrapper` on changed files.

## Rule: Don't over-engineer

**Do:** Implement only what the task requires.
**Don't:** Add speculative helpers, abstractions, comments, docstrings, or type annotations to code you didn't change.
**Why:** Scope creep makes diffs hard to review and introduces unrequested behavior.
**Detection:** Reviewer flags additions outside the stated change.
