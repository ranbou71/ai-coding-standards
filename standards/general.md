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

## Rule: Centralize configuration defaults in one authoritative layer

**Do:** Define defaults in a single, explicit location (config class, environment override, or a constants module). Make it clear which source is the source of truth.
**Don't:** Scatter defaults across multiple locations (variables.ts declares one default, env var is also checked, constructor has another). This creates confusion about which default is "active" in production vs. local dev.
**Why:** Multiple default sources lead to deployments where the "active" default is unclear. Developers end up unsure whether they're hitting the declared default, the env var, or a constructor parameter. If a bug arises from the wrong value being used, it's hard to trace back.
**Pattern:** Validation at the boundary + explicit error. Example: `const ttlMs = config.getTtlMinutes() * 60 * 1000; if (!ttlMs || ttlMs <= 0) throw new Error('TTL_MINUTES must be set and > 0 in config');`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3030085762
**Detection:** Multiple config sources for the same value (constants file, `process.env`, constructor parameter) without clear priority or documentation of which takes precedence.

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

## Rule: Multiple try/catch blocks are OK if each handles a distinct failure mode; flatten, don't nest them

**Do:** Use separate, sequential try/catch blocks when each one handles a distinct failure mode tied to a specific API or requirement (e.g., `new URL()` throws on invalid input, `.fetch()` throws on network errors, header validation throws). Flatten them; avoid deep nesting.
**Don't:** Nest multiple try/catch blocks speculatively "just to be safe". If you have multiple legitimate failure modes, sequence them horizontally, not vertically.
**Why:** Each try/catch should have a clear reason. When they're flattened, the code is easier to read, debug, and audit. Nested try/catches obscure which failure mode each one is handling and make error traces harder to follow.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3076253621
**Detection:** Deep nesting (3+ levels) of try/catch blocks, or multiple try/catches in one block without a documented reason tied to a distinct API or security requirement.

## Rule: Document error propagation paths through call chains

**Do:** When an error propagates up through multiple layers (e.g., validation error → handler method → caller → outer catch block), add a comment at the source that traces the propagation path or extract into a named error handler with a clear boundary.
**Don't:** Rely on the reader to trace through a chain of functions to figure out where errors are caught and what happens to them.
**Why:** Implicit error propagation causes reviewers to worry about edge cases (e.g., "Will this error cause a crash? A loop? Unhandled promise rejection?"). Making the path explicit prevents confusion and accelerates code review.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3080735542
**Detection:** Multiple async/sync function calls in sequence where one might throw, and the catch block is 2+ levels up the stack, with no comment explaining the propagation.

## Rule: Update comments when code behavior changes

**Do:** When modifying code logic (adding validation, changing defaults, adding throw statements), update any comments that describe the old behavior. Re-read comments to verify they still match the code.
**Don't:** Leave comments that describe a "default" or "fallback" when you've added a `throw` statement or changed the logic to require a specific value.
**Why:** Stale comments are more misleading than no comment. They create false assumptions during code review, maintenance, and debugging. Reviewers and future maintainers trust comments and will be misled if they don't match the code.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453753
**Detection:** Comment mentions "default X minutes" but code throws if that value is invalid/missing. Or comment says "Priority: A > B" but logic changed to require A.

## Rule: Clean up existing resources before overwriting them

**Do:** When a method creates or overwrites resource handles (timers, intervals, connections, listeners), guard against re-entrance by checking if the resource already exists and stopping/clearing it first.
**Don't:** Blindly overwrite a resource handle without cleaning up the previous one (e.g., `this.interval = setInterval(...)` when `this.interval` might already be active).
**Why:** Overwriting without cleanup leaks the old resource and causes duplicate operations. If a method can be called multiple times, the second call will create a new timer while the old one keeps running, causing checks to fire twice or preventing proper cleanup.
**Example fix:** Before `this.interval = setInterval(...)`, add `if (this.interval) this.stop();` or `if (this.interval) clearInterval(this.interval);`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453802
**Detection:** Assignment to a resource handle (`this.interval = setInterval`, `this.connection =`, `this.listener =`) in a public method without a preceding guard or cleanup call.
