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

## Rule: Don't duplicate config normalization in consumers

**Do:** Centralize trimming, defaulting, casting, and parsing in the config layer. Consumers should treat config values as already-normalized.
**Don't:** Re-`trim()`, re-default, or re-coerce a value that the config layer already handled.
**Why:** Duplicated normalization drifts over time — the consumer and the config layer end up with different rules for the "same" value, hiding bugs.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3076051573
**Detection:** A consumer calling `.trim()` / `?? default` / `Number()` / `Boolean()` on a value sourced directly from a config object.

## Rule: Config getters must not throw

**Do:** Load and return raw (or normalized) config values from getters. Validate at the consumer where the value is actually used, and throw there if the value is missing or invalid.
**Don't:** Throw from a config class getter, property accessor, or module-level constant when a required value is missing.
**Why:** Throwing from a getter is an unexpected side effect from what callers treat as a passive value lookup. It also forces every importer to handle the error even if they don't need that specific field. Validation belongs at the boundary where the value is consumed.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3080004435
**Detection:** `throw` inside a getter, `get` accessor, or top-level `const` initializer in a config/constants module.
