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

## Rule: Don't add speculative try/catch in the middle of code paths

**Do:** Let errors propagate so they're visible and debuggable. Add try/catch only at system boundaries (API handlers, command-line entry points, worker job runners) where you have a real recovery strategy.
**Don't:** Wrap operations in try/catch "just in case" (e.g., wrapping `JSON.stringify()`, `parseInt()`, or method calls you didn't write) and then convert the error to a placeholder message like `'[unserializable]'`.
**Why:** Speculative catch blocks hide errors and make them worse: when the catch fires, you lose the original error details, making debugging harder. If the operation is safe enough for production, trust it. If you're unsure, use a safer alternative or validate inputs up front.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3080030571
**Detection:** `try { … } catch { … data = '[unserializable]'|'[error]'|placeholder }` or similar fallback without a real recovery strategy.

## Rule: Use the framework's centralized cache instead of duplicating with module-level caches

**Do:** Store cached data (tokens, API responses, computed values) in your framework's built-in cache layer with TTL support. All consumers share the same cache and refresh logic.
**Don't:** Create module-level or service-level cache variables (e.g., `cachedAccessToken`, `cachedResponse`) when a centralized cache mechanism already exists.
**Why:** Duplicate caching drifts — different modules may refresh at different times or use different TTL logic, causing stale-data bugs. Centralized caching keeps all consumers in sync, reduces maintenance burden, and makes the caching strategy visible and auditable in one place.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3076239350
**Detection:** Multiple module-level `const` or `let` variables storing cached data (tokens, responses, computed values) when a framework or library cache layer with TTL support is available.
