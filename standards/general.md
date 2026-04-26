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

**Do:** Load and return raw (or normalized) config values from getters. Validate at the consumer where the value is actually used, and throw there if the value is missing or invalid. The accepted shape for an env-backed getter is `return process.env.FOO || '';` (or the typed equivalent) — a non-throwing, defaulted lookup.
**Don't:** Throw from a config class getter, property accessor, or module-level constant when a required value is missing. Don't add `validateRequiredEnv()` helpers that promote getters to throwing accessors — that's the anti-pattern this rule exists to prevent.
**Why:** Throwing from a getter is an unexpected side effect from what callers treat as a passive value lookup. It also forces every importer to handle the error even if they don't need that specific field. Validation belongs at the boundary where the value is consumed. This is a team standard — reviewers (including AI) should not flag the empty-string default pattern as a defect.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3080004435
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859825
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112894167
**Detection:** `throw` inside a getter, `get` accessor, or top-level `const` initializer in a config/constants module. Also: a suggestion to _add_ throwing/validation to an existing non-throwing getter — reject it; validate at the consumer instead.

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
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2818069910
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

**Do:** When modifying code logic (adding validation, changing defaults, adding throw statements), update any comments that describe the old behavior. Re-read comments to verify they still match the code. This applies with extra force to _contractual_ documentation — JSDoc/TSDoc/Pydoc summaries, `@throws`/`@returns`/`@param` tags, OpenAPI descriptions, and README "behavior" sections — because tooling, reviewers (human and AI), and consumers all treat them as authoritative.
**Don't:** Leave comments that describe a "default" or "fallback" when you've added a `throw` statement or changed the logic to require a specific value. Don't write JSDoc that promises behavior the code doesn't perform — e.g. `@throws {AppError} If any of FOO/BAR is missing` on a constructor that just reads `AppConfig.FOO` (which defaults to `''`) and never validates or throws. If the validation actually lives elsewhere (entry point, DI bootstrap), say so explicitly and link to it; don't claim the current method does it.
**Why:** Stale comments are more misleading than no comment. They create false assumptions during code review, maintenance, and debugging. Reviewers and future maintainers trust comments and will be misled if they don't match the code. JSDoc lies are the worst of these: they survive refactors, propagate into IDE tooltips, and Copilot/AI reviewers will flag them on every PR until either the doc or the behavior is fixed.
**Example fix options for a misleading `@throws`:**

- Make the doc true: add the validation + throw in the constructor.
- Make the doc honest: rewrite to "Reads validated config; required env vars are validated at the entry point (`src/index.ts`). This constructor does not throw."
  **Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453753
  **Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3113065954
  **Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/77#discussion_r2843720966
  **Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/77#discussion_r2843720986
  **Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2818750322
  **Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2818750339
  **Detection:** Comment mentions "default X minutes" but code throws if that value is invalid/missing. Or comment says "Priority: A > B" but logic changed to require A. Or JSDoc has `@throws` / "validates" / "requires" language for a method whose body contains no validation, no `throw`, and no call into a validator.

## Rule: Clean up existing resources before overwriting them

**Do:** When a method creates or overwrites resource handles (timers, intervals, connections, listeners), guard against re-entrance by checking if the resource already exists and stopping/clearing it first.
**Don't:** Blindly overwrite a resource handle without cleaning up the previous one (e.g., `this.interval = setInterval(...)` when `this.interval` might already be active).
**Why:** Overwriting without cleanup leaks the old resource and causes duplicate operations. If a method can be called multiple times, the second call will create a new timer while the old one keeps running, causing checks to fire twice or preventing proper cleanup.
**Example fix:** Before `this.interval = setInterval(...)`, add `if (this.interval) this.stop();` or `if (this.interval) clearInterval(this.interval);`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453802
**Detection:** Assignment to a resource handle (`this.interval = setInterval`, `this.connection =`, `this.listener =`) in a public method without a preceding guard or cleanup call.

## Rule: New behavior must ship with unit tests

**Do:** When introducing new logic (retry loops, branching, error handling, state transitions, side effects like delete/increment/log), add focused unit tests that exercise each branch. Mock external dependencies (SNS, DynamoDB, HTTP clients) so tests are fast and deterministic. If the existing code isn't testable, refactor to inject dependencies (e.g., export a typed `Dependencies` object the function accepts) before adding the behavior.
**Don't:** Merge new behavior with no tests because "the code is small" or "it's hard to mock". Don't rely solely on existing integration tests to cover newly added branches.
**Why:** Untested behavior regresses silently — a future refactor or dependency upgrade breaks it and no one notices until production. Per-branch tests also document intent: a reviewer can read the test names to understand what each new code path is supposed to do.
**Example:** A new `retryFailedEvents()` that scans retryable records, deletes on success, increments `retryCount` on failure, and logs when a retry limit is exceeded needs at least one test per branch (success path, failure path, retry-limit-exceeded path), with `SNSService` and `DynamoDbDocumentService` mocked.
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/15#discussion_r3094669654
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13#discussion_r2801465217
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707719
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707731
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872510
**Detection:** A PR adds a new exported function, branch, or side effect with no corresponding `*.test.ts` / `*.spec.ts` (or language equivalent) changes in the same diff.

## Rule: Explain non-obvious patterns at the point of use

**Do:** When using a pattern that isn't immediately obvious from the syntax — dependency injection via default parameter values, currying, factory functions, higher-order functions, branded types, etc. — add a brief comment at the function/parameter declaration explaining _what_ the pattern is and _why_ it's used (e.g., "Dependencies injected as defaults to allow overrides in tests"). Prefer naming that telegraphs intent (`deps`, `injected`, `*ForTest`) and group injected dependencies into a single typed object when there are more than two.
**Don't:** Ship code that uses an unfamiliar pattern (especially DI via default-valued parameters that shadow real implementations) with no comment, no type alias name that hints at the intent, and no test demonstrating the override. Don't make reviewers ask "what is this function?" before they can review the logic.
**Why:** If a reviewer has to stop and ask what a parameter list is doing, the code is under-documented. The fix isn't always a comment — sometimes a typed `Dependencies` object, a factory function, or a clearer name removes the question entirely. The goal is that a reader unfamiliar with the pattern can understand the _shape_ of the code on first read.
**Example:** Instead of `function retryFailedEvents(getFailedEvents = getFailedEventsImpl, publishToSNS = publishToSNSImpl, ...)` with no context, either (a) accept a single `deps: RetryFailedEventsDependencies = defaultDeps` parameter, or (b) add a one-line comment: `// Dependency injection via defaults — override in tests to mock SNS/DynamoDB.`
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/15#discussion_r3095226294
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/15#discussion_r3095384065
**Detection:** A function signature uses default parameter values that reference other module-level identifiers (the DI-via-defaults pattern), or any other non-idiomatic pattern, with no nearby comment, no descriptive type alias, and no test exercising the override.

## Rule: Make boundary validation discoverable from the consumer

**Do:** When a class/service relies on validation performed elsewhere (typically the entry point — `index.ts`, a Lambda handler, a CLI bootstrap), make that fact discoverable from the consumer. Pick one of: (a) a one-line comment at the consumer pointing to the validation site (`// Required env vars are validated in src/index.ts before construction.`), (b) accept the validated values as constructor parameters instead of reading `AppConfig.*` directly, or (c) use a typed "validated config" object/branded type that can only be produced by the validation function.
**Don't:** Read `AppConfig.FOO` (which defaults to `''`) directly in a constructor while documenting in a docstring that "FOO is validated and an error is thrown when missing" — without saying _where_ it's validated. Reviewers (human and AI) will flag the mismatch between the docstring promise and the code, and the author will have to repeat "this is already handled in `index.ts`" on every PR.
**Why:** Boundary validation is correct (see "Config getters must not throw"), but if the consumer gives no hint that validation has already happened, every reviewer has to re-derive it. The cost is paid on every PR forever. A single comment, a typed parameter, or a branded "ValidatedConfig" type pays that cost once.
**Example:** Instead of `constructor() { this.snsTopicArn = AppConfig.SNS_TOPIC_ARN; … }` with a misleading docstring, prefer either `constructor(config: ValidatedAppConfig) { … }` or add `// SNS_TOPIC_ARN / SNS_TOPIC_NAME / DYNAMO_DB_TABLE_NAME validated in src/index.ts via assertRequiredEnv().` directly above the field assignments. Then update the docstring so it matches: "Reads validated config; the entry point is responsible for failing fast on missing values."
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859856
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3113215955
**Detection:** A constructor or top-level service reads `AppConfig.*` / `process.env.*` values whose getters default to `''` and a docstring/comment claims those values are "validated" or "required", but there's no pointer (comment, typed parameter, or branded type) to where that validation lives.

## Rule: Error messages, log messages, and source-location fields must agree with the code

**Do:** Keep all three of (a) the human-readable message, (b) any "detail" / category field, and (c) source-location fields (`functionName`, `module`, `file`) consistent with the actual failing condition and the actual call site. If a check covers multiple inputs (`!SNS_TOPIC_ARN || !SNS_TOPIC_NAME || !DYNAMO_DB_TABLE_NAME`), the message must name _all_ of them — or, better, the message should name _which one_ is missing. If the check runs in `src/index.ts` during startup, `functionName` must be `'index.ts'` / `'startup'`, not the name of the service that _would have been_ constructed.
**Don't:** Copy/paste an error or `functionName` from another module and leave it pointing at the wrong source. Don't write `'SNS topic configuration is missing'` for a check that also validates DynamoDB. Don't tag a startup-validation error with the constructor name of the downstream service — incident triage will look in the wrong file.
**Why:** Mismatched messages and source-location metadata send on-call engineers to the wrong file, hide which env var actually caused the outage, and erode trust in the logs. The cost is paid in minutes-to-mitigate on every incident.
**Example fix:**

```ts
// in src/index.ts startup
const missing = [
  !LocalAppConfig.SNS_TOPIC_ARN && "SNS_TOPIC_ARN",
  !LocalAppConfig.SNS_TOPIC_NAME && "SNS_TOPIC_NAME",
  !LocalAppConfig.DYNAMO_DB_TABLE_NAME && "DYNAMO_DB_TABLE_NAME",
].filter(Boolean);
if (missing.length) {
  logger.error(`Required configuration is missing: ${missing.join(", ")}`, {
    ...loggerCommon("index.ts"),
    functionName: "startup",
    extraFields: { missing },
  });
  throw new AppError(
    `Required configuration is missing: ${missing.join(", ")}`,
    String(StatusCodes.INTERNAL_SERVER_ERROR),
    "index.ts:startup",
  );
}
```

**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859967
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3112856493
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3112856518
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872373
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872628
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2977154332
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2977154379
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2977154424
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2977154450
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2988628353
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2988628469
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r3001666461
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r3001666602
**Detection:** A `logger.*` / `throw new *Error(...)` site where (a) the message names a subset of the conditions actually being checked, (b) `functionName` / `module` / source field references a different file or class than the one the code lives in, or (c) the log message and the thrown message disagree on what failed.

## Rule: Don't modify shared root config files to silence AI suggestions

**Do:** Treat root build/test/lint configs as load-bearing project conventions: `tsconfig.json`, `jest.config.js`, `eslint.config.*`, `.prettierrc`, `package.json` `scripts`, root `Dockerfile`, CI workflow files. Changes to these affect every developer and every build. Make changes only when there's a real, verified need, and call them out explicitly in the PR description. When an AI assistant flags something in these files (deprecation warning, "consider…", style suggestion), **default to ignoring it** unless you've confirmed (a) the suggestion is correct for the project's current toolchain version, (b) the team wants the change, and (c) it doesn't break anything else (e.g. removing `baseUrl` because TS 7.0 says it's deprecated will break this team's TS 5.x setup).
**Don't:** Edit `tsconfig.json`, `jest.config.js`, `moduleNameMapper`, ts-jest's `tsconfig` pointer, or similar shared config to make a Copilot/AI warning go away. Don't add a second tsconfig and re-point jest at it. Don't drop `baseUrl` because the IDE warns it's deprecated in a future TS version. The project already works the way it is — speculative cleanup of shared config is the most expensive kind of "while I'm in here" change.
**Why:** Shared config files are the project's contract with every contributor. Changes have invisible blast radius (test discovery, alias resolution, coverage reporting, CI builds). When an AI suggests a change in one of these files, the suggestion was made without knowledge of the team's TS/Node/jest versions, the rest of the toolchain, or the historical reasons the config is shaped the way it is. The right answer is almost always: leave it alone, and if the AI keeps flagging it, add a comment in the file explaining why the "obvious" cleanup is wrong.
**Example fix:** If Copilot flags `"baseUrl": "./src"` as deprecated, leave it. The team's current TypeScript still supports it; removing it cascades into broken `paths` resolution across every tsconfig that extends this one. Same for `moduleNameMapper` in `jest.config.js`, the `tsconfig` field in ts-jest, etc.
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117879554
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117894307
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117902105
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081286
**Detection:** A diff that touches `tsconfig.json`, `jest.config.js`, `eslint.config.*`, root `Dockerfile`, or CI workflow files in a PR whose stated purpose is unrelated (feature work, bug fix, new script). Especially: any change driven by an AI suggestion (deprecation warning, "consider …") with no human-verified justification in the PR description.

## Rule: Spell identifiers out — no abbreviations or acronyms in names

**Do:** Name interfaces, types, classes, variables, functions, and files with the full descriptive word: `ManagerExecutiveCoordinator`, `ExecutiveSupportLeader`, `userSettingsResponse`, `getLeaders`. If an acronym is genuinely the canonical term in the business domain (e.g. "URL", "SNS", "SQL"), keep it but capitalize it idiomatically (`snsClient`, `urlPattern`).
**Don't:** Use ad-hoc shortenings (`Mec`, `Esl`, `Mgr`, `Cfg`, `UsrSvc`) as identifier names. Don't rely on a comment (`// Represents a MEC (Manager, Executive, or Coordinator)…`) to translate the abbreviation — the name should be self-documenting.
**Why:** Abbreviations save a few keystrokes once and cost reading time forever. New contributors, AI assistants, and search-by-symbol all benefit from full names. If a comment is required to explain what the identifier means, the identifier is wrong.
**Example fix:** Rename `interface Mec { … }` → `interface ManagerExecutiveCoordinator { … }` (or, if the same shape is shared across roles, a single `interface Leader { … }` — see "Don't create distinct types for identical shapes").
**Source:** https://github.com/cobank-acb/ama-gems-exp-api/pull/90\#discussion_r2614961121
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772397
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3126831543
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872609
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2755801049
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2977154400
**Detection:** A new `interface`/`type`/`class`/exported function or variable whose name is a 2–4-letter abbreviation that requires a comment to explain.

## Rule: Don't create distinct types for identical shapes

**Do:** When two interfaces/types would have the same fields with the same semantics, define one interface and reuse it. If the data is genuinely the same shape coming from different sources, a single shared type plus a discriminator field (`role: 'manager' | 'executive-support'`) is better than parallel duplicate types.
**Don't:** Define `interface Mec { displayName: string; searchValue: string; }` and `interface Esl { displayName: string; searchValue: string; }` as siblings. Parallel duplicates drift over time — one gets a new field, the other doesn't, and downstream code starts having to know which is which for no real reason.
**Why:** Duplicated types double the maintenance surface and add no expressive power. The type system can't tell `Mec` from `Esl` (they're structurally identical), so the "two types" buy nothing at compile time and cost code review questions, refactors, and drift forever after.
**Example fix:** Replace `Mec` and `Esl` with a single `Leader` interface; if a caller needs to distinguish source, pass the source as a separate argument or add a discriminator field.
**Source:** https://github.com/cobank-acb/ama-gems-exp-api/pull/90#discussion_r2614967290
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2818774595
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2817679659
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2722206946
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2723158771
**Detection:** Two or more `interface`/`type` declarations with the exact same field names and types in the same module/feature. Tooling: `tsc --noEmit` won't catch it; a `jq`/grep over interface bodies will.

## Rule: Don't use template literals for static strings

**Do:** Use plain string literals (`'foo'` / `"foo"`) for any string that contains no interpolation. Reserve template literals for strings that actually splice in `${expr}` or that need multi-line content.
**Don't:** Write `` `{ "$or": [ … static JSON … ] }` `` when there's no `${…}` inside. The backticks add no value, complicate escaping, and trip linters/grep.
**Why:** Template literals signal "this string is dynamic" — using them for static content lies to the reader and to static analysis. Plain quotes also play better with JSON-like content because you don't have to think about backtick escaping.
**Example fix:** ``const where = `{ "$or": [...] }`;`` → `const where = '{ "$or": [...] }';`
**Source:** https://github.com/cobank-acb/ama-gems-exp-api/pull/90\#discussion_r2615147341
**Detection:** A backtick-delimited string in a `.ts`/`.tsx`/`.js`/`.jsx` file that contains no `${`. Lint rule: `quotes: ['error', 'single', { allowTemplateLiterals: false }]` plus `prefer-template` off.

## Rule: Search the codebase for existing patterns before adding new helpers

**Do:** Before introducing a new utility file, hook, type, helper, or filter-mapping function, search the codebase (and ask the team / check recent PRs) for an existing solution. Reuse it, extend it, or move it to a shared location. If a teammate already wrote `useServerFilter`, a `LeadersResponse`, a column operator filter, or a date-range filter, build on that.
**Don't:** Write a parallel implementation because grep didn't surface it on the first try, because it's "just easier to start fresh", or because the AI didn't suggest the existing helper. Don't ship a feature PR that includes a brand-new util file when an in-repo equivalent already exists. Don't replicate filtering or formatting from one page when the other page has it abstracted.
**Why:** Parallel helpers double the maintenance surface, drift apart over time, and make consolidating later painful. Reviewers will reliably ask "didn't Saki/Bob/Alice already write this?" — it's faster to look first.
**Example fix:** Before adding `src/utils/filterUtils.ts`, search for existing `filters/`, `grid/`, `operators` modules. If you find one, extend it; if not, mention in the PR description that you searched and didn't find one.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874873105
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874882354
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874882999
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874885226
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2878957635
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2880737661
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2880745687
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/38#discussion_r2842401667
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/38#discussion_r2842403377
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817896991
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817906345
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2818763013
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/77#discussion_r2847733801
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/77#discussion_r2847921939
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2819509164
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2829963959
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2817743659
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793819488
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793908403
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2790097032
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2790107608
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124648095
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3126900115
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872588
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747945503
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747951191
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747951570
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747963355
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2991458691
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2991489420
**Detection:** A PR adds a new `utils/`/`hooks/`/`helpers/` file or a new exported helper that overlaps semantically with code already present in another feature folder.

## Rule: Don't change unrelated code in a feature PR

**Do:** Keep PRs focused. If you spot drive-by improvements (import-style cleanups, type-system tweaks, tsconfig changes, formatting), open a separate PR. State the PR's scope in the description.
**Don't:** Reformat imports in `client.ts`, change `moduleResolution` in `tsconfig.json`, or restructure unrelated types in the middle of a feature PR. Each unrelated change forces reviewers to re-derive whether it's safe and bloats the diff.
**Why:** Unrelated changes are review-hostile: they obscure the actual feature change, multiply blast radius, and make `git blame`/revert noisy. The right time to refactor unrelated code is in a refactor PR.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874877866
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874890895
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081286
**Detection:** A PR titled/described as a feature change touches files unrelated to the feature (formatting, import style, tsconfig, unrelated type definitions).

## Rule: Don't construct defensive fallbacks against your own backend's response shape

**Do:** Type the backend response accurately. If `meta.total`, `meta.page`, and `meta.limit` are required, declare them as required in the response type and trust them. Validate at the actual edge if you must (e.g., a runtime parser at the API client boundary), once.
**Don't:** Sprinkle `response.meta?.total ?? response.data.length`, `response.success ?? true`, `response.meta?.page ?? currentPage()` in feature code. These fallbacks paper over response-shape uncertainty that should be resolved at the type/API boundary, and they hide real backend bugs by silently substituting plausible values.
**Why:** Defensive fallbacks against your own backend mean "I don't trust the API contract." If you don't trust it, fix the contract (or add one parser at the client) — don't scatter ternaries across every consumer. The fallbacks also drift: a future backend change will be silently absorbed by the `??` and never raise an error.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2878991207
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2879085086
**Detection:** Multiple `?? <derived-value>` / `<field> ?? true` / `<field> ?? defaultLength` against fields of an object you fetched from your own backend in the same PR.

## Rule: Files should declare their purpose at the top

**Do:** Add a brief module-level comment (1–3 lines) at the top of any non-trivial new file explaining what it's for and where it sits in the architecture. "Maps MUI DataGrid filter operators to backend API operators" is enough.
**Don't:** Ship a 200+ line utility/hook/component file with no header comment, forcing every reviewer (and future reader) to scroll and infer purpose from contents. If a reviewer has to ask "what is this file for?", the file is missing its header.
**Why:** A one-paragraph header pays for itself the first time a reviewer asks "wait, what does this do?". It also gives the AI/IDE useful context for future suggestions.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2879004935
**Detection:** A new file > ~50 lines with no leading `//` or `/** */` comment describing its purpose.

## Rule: Extract a helper for repeated derived values, especially off-by-one math

**Do:** When the same derived expression appears more than twice — `paginationModel.page + 1`, `value.toLowerCase().trim()`, `new Date(x).getTime()` — extract it to a named local helper at the top of the function or a small util. Naming the derivation makes the intent obvious and prevents drift.
**Don't:** Sprinkle `paginationModel.page + 1` (or `?? 1`, or `?? 0`) across queryFns, queryKeys, and request bodies. The first time someone "fixes" one site without the others, the off-by-one returns.
**Why:** Repeated bare expressions hide the question "why +1?" at every call site. A named helper (`const currentPage = () => (paginationModel?.page ?? 0) + 1;`) answers it once and gives every caller the same answer.
**Example fix:** `const currentPage = () => (paginationModel?.page ?? 0) + 1;` then use `currentPage()` everywhere. Bonus: easier to mock/override in tests.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/38#discussion_r2842399247
**Detection:** The same non-trivial expression (especially arithmetic on optional fields, or `?? default` with a magic constant) appears 3+ times in one file.

## Rule: No hardcoded user/business identifiers in feature code

**Do:** Pull user identity from the auth/user store (`useUserStore((state) => state.user)`, the session, the request context). Read business identifiers (employeeId, accountId, organizationId) from the same source, never as inline string literals.
**Don't:** Ship `const employeeId = '12345'` or `accountId: 'TEST_ACCOUNT'` in feature code, even temporarily. The placeholder will reach production and silently scope every user to one account.
**Why:** Hardcoded identifiers are the most-cited "leftover from local testing" bug. They pass type checks, pass tests (because the test data uses the same constant), and silently cause cross-tenant data leaks or single-user-only behavior in prod.
**Example fix:** `const user = useUserStore((state) => state.user); const employeeId = user?.employeeId;` — and gate the query on `employeeId` being defined (`enabled: !!employeeId` for react-query).
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081274
**Detection:** A string literal that matches an identifier-like pattern (`/^[A-Z0-9_-]{3,}$/`, `/^\d{5,}$/`) assigned to a variable named `employeeId` / `userId` / `accountId` / `organizationId` / `tenantId` in a non-test file.

## Rule: Don't add unrelated dependencies in a feature PR; choose `dependencies` vs `devDependencies` correctly

**Do:** Only add a dependency in the PR that introduces its first usage. When adding it, classify correctly: code that ships to the user → `dependencies`; build/test/dev tooling → `devDependencies`. Call out the addition in the PR description with the use case.
**Don't:** Add `puppeteer`, `lodash`, `moment`, or any large package as a `dependencies` entry in a feature PR that doesn't import it. Don't add a build/test tool as `dependencies` (it bloats the production bundle).
**Why:** Unused deps inflate `node_modules`, lockfile churn, and supply-chain risk. Wrong-classification deps inflate the production bundle (or break CI when the feature relies on a `devDependency` not installed in prod). Reviewers can't tell intent from a bare `package.json` diff — the PR description must justify it.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18\#discussion_r2807081285
**Detection:** A `package.json` diff adds a top-level entry under `dependencies` or `devDependencies` and the rest of the diff has no `import`/`require` of that package. Or: a clearly dev-only tool (`puppeteer`, `playwright`, `vitest`, `eslint-*`) added under `dependencies`.

## Rule: Document special-case skips and "default behavior" magic at the call site

**Do:** When code intentionally _omits_ a parameter because the backend treats it as a default (e.g., "don't send `op` when it's `'eq'`, since `'eq'` is the API's default"), add a one-line comment at the conditional explaining the contract: `// Default behavior is 'eq', so only send billingYearOp for non-equality comparisons.`
**Don't:** Write `if (options?.billingYearOp && options.billingYearOp !== 'eq')` with no comment. The reader has to load the API contract into their head to understand why `'eq'` is special, and the next refactor will "fix" the perceived bug by including it.
**Why:** Implicit defaults are invisible — they're a contract between this code and a remote API, and they're not enforced anywhere. A comment is the minimum fix; a named constant (`const DEFAULT_BILLING_YEAR_OP = 'eq';`) is better; a typed mapping function that knows the defaults is best.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081289
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2817650712
**Detection:** A conditional that _excludes_ a specific value from being sent/processed (`x && x !== 'eq'`, `x !== 0 && x`, `value && value !== DEFAULT`) with no comment explaining the special case.

## Rule: Don't wrap a static value in a parameterless function

**Do:** Export a `const` (or, for a value that never changes per call, a top-level `const`) when the value has no parameters and no per-call work. `export const REIMBURSEMENT_COLUMNS: GridColDef[] = [ … ];`
**Don't:** Define `export function getReimbursementColumns(): GridColDef[] { return [ … ]; }` and call it on every render. The function adds no value (no params, no caller-specific logic) and creates a new array every call, defeating any downstream `===` reference comparisons.
**Why:** Parameterless getters that always return the same value are an anti-pattern: they look like they might do something dynamic but don't, and they're a magnet for unnecessary `useMemo` calls in the consumer to "fix" the new-array-every-call problem.
**Example fix:** `export function getReimbursementColumns(): GridColDef[] { return [ … ]; }` → `export const reimbursementColumns: GridColDef[] = [ … ];`. If parameters genuinely come later, accept them then (`getReimbursementColumns(planTypes: PlanType[])`); don't pre-emptively wrap.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817863530
**Detection:** An exported function with `()` (zero parameters) whose body is `return <static-literal>;` or returns a value computed only from module-scope constants.

## Rule: Response-shape changes are breaking API changes — describe them as such and coordinate with consumers

**Do:** When a PR moves response fields between locations (e.g., `total/page/limit` from top level into `meta`), adds a new required field to a response (`success: boolean`), renames a field, or changes a field's type, treat it as a breaking API change. Call it out explicitly in the PR title/description ("Breaking: …" or a "Breaking changes" section), update OpenAPI/swagger in the same PR, and notify/version every consumer (frontend repos, downstream services, mobile apps).
**Don't:** Frame a breaking response-contract change as an "interface correction", "type cleanup", or "swagger fix" in the PR description. Don't merge a response-shape change without naming the consumers and confirming they're updated or the endpoint is versioned.
**Why:** "Interface change" sounds like a TypeScript-only edit; "response shape change" is a wire-protocol break. The TypeScript compiler in _this_ repo can't see the frontend that deserializes the response, the mobile app, or the analytics pipeline reading the same JSON. The PR description is the only place reviewers can learn that this is a coordinated change — if it lies (or omits), the break ships.
**Example:** PR description should include: "**Breaking:** moves `total`, `page`, `limit` from response root into `response.meta`; adds required `success: boolean`. Frontend consumer: cobank-acb/ama-cell-reimbursement-ui PR #N (merged together). No other known consumers."
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/77#discussion_r2843720997
**Detection:** A diff that (a) adds/removes/renames fields on an exported response interface or DTO, (b) moves fields between nested objects, or (c) changes a field from optional to required — combined with a PR description that doesn't contain the words "breaking", "consumer", "frontend", or a coordinated PR link.

## Rule: Variable names must describe the value, not the conceptual end-state of the transformation

**Do:** Name a variable for what it actually holds at that point in the code. If `groups.find((g) => MAP[g])` returns the matching _group key_, call it `matchedGroup` (or `groupWithPlanType`), not `planTypeName`. Reserve `planTypeName` for the value you get _after_ `MAP[matchedGroup]`.
**Don't:** Name an intermediate value after the downstream thing it will eventually be used to look up. `const planTypeName = groups.find((g) => GROUP_TO_PLAN_TYPE_MAPPING[g]);` lies — `planTypeName` is the _AD group string_, the plan type comes one step later.
**Why:** Misnamed intermediates poison every later edit. The next maintainer reads `planTypeName` and assumes it's a plan type — they pass it to a function expecting a plan type, format it for display, log it as a plan type, and the bug ships. The variable name _is_ the local API; making it match the value is free.
**Example fix:** `const matchedGroup = groups.find((g) => GROUP_TO_PLAN_TYPE_MAPPING[g]); if (matchedGroup) { const mappedPlanTypeName = GROUP_TO_PLAN_TYPE_MAPPING[matchedGroup]; ... }`
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2818750261
**Detection:** A variable initialized from `array.find(predicate)` / `Object.keys(map).find(...)` whose name matches the value the _predicate_ tests for, not the value `find` returns. Or any `const X = lookup(key)` where `X` is named after `lookup`'s domain rather than its codomain.

## Rule: JSDoc `@example` blocks are code — keep them syntactically valid and use distinct identifiers

**Do:** Treat every `@example` block as a small TypeScript snippet. Use unique variable names per declaration, valid syntax, and accurate output comments. If you copy-paste an example, rename the variables.
**Don't:** Write two `const validStatus = ...` lines in the same `@example` block, or leave `// Returns 'Approved'` next to a call that now returns `'Sent for Payment'`. Doc-tooling, IDE tooltips, and AI reviewers all parse these — invalid examples generate noise on every PR until fixed.
**Why:** `@example` is the most-quoted part of a function's docs; it's what people copy into their code. A duplicate `const` is a copy-paste bug that immediately propagates into callers' code. A wrong `// Returns ...` comment is a lie that survives the next refactor.
**Example fix:** `* const validStatus = validateStatusValue('Approved'); // Returns 'Approved'` followed by `* const invalidStatus = validateStatusValue('Foo'); // Throws ValidateError`.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2818750365
**Detection:** A JSDoc/TSDoc `@example` block (between `* @example` and the next `*/` or `* @`) that declares the same identifier with `const`/`let` more than once, or whose `// Returns ...` / `// Throws ...` annotations don't match the function body.

## Rule: Don't hardcode in source code what already lives in the database

**Do:** When the data store already has the values (plan types, statuses with metadata, role definitions, lookup tables, max amounts), read them from the database. Add a repository method, cache the result if hot, and let the database remain the single source of truth.
**Don't:** Create a TypeScript `enum`, `const` object, or `Map` that mirrors a database table — especially when it has to mirror columns like `max_amount` that are owned by the data team. Two sources of truth drift the moment someone updates one without the other.
**Why:** Hardcoded mirrors of database data create a quiet maintenance debt: every schema/data change requires a coordinated code release, and the discrepancy is invisible until a customer reports the wrong dollar amount. The "but I need the AD group → plan mapping somewhere" answer is to model that mapping in the database too (a join table), not to hardcode it.
**Example fix:** Move `GROUP_TO_PLAN_TYPE_MAPPING` from `src/constant/planType.ts` into a `plan_type_groups` table; the repository looks up the plan type by AD group at runtime.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2819515638
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2819517350
**Detection:** A new `enum`, `const` object, or `Map` in `constant/`, `constants/`, `enums/`, or `lookups/` that duplicates fields the project's database schema clearly owns (currency amounts, status display names with metadata, role hierarchies, plan tiers).

## Rule: Don't silently delete existing log statements in an unrelated PR

**Do:** When you remove a `logger.debug` / `logger.info` / `logger.warn` call, justify it in the PR description (or commit message) — "removed because it logs every request and overwhelms Splunk". If the log is too noisy, downgrade the level or add a sample rate; don't delete it.
**Don't:** Quietly strip `logger.debug(...)` lines as part of a feature PR or "cleanup". They were added by another developer who needed them to diagnose a real production issue, and the next time that issue recurs the on-call engineer will be flying blind.
**Why:** Logs are debugging infrastructure that someone paid for with their on-call time. Silent removal in an unrelated PR loses that investment. The reviewer can't tell from a `-logger.debug(...)` line whether you considered the trade-off or just deleted it because the function felt cluttered.
**Example fix:** Keep the log; if you've changed the surrounding code such that the log message is now wrong, update the message instead of deleting the line.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2829954561
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2829954943
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2829965150
**Detection:** A diff that removes one or more `logger.*` / `log.*` / `console.*` lines without adding equivalent ones, in a PR whose stated purpose is unrelated to logging/observability.

## Rule: "No data" cases with business meaning must log a warning with diagnostic context

**Do:** When a function returns `null` / empty / "not found" because of a business condition the support team will care about ("user is not enrolled in the program", "no plan type matched the user's AD groups"), log a `warn`-level entry with the inputs the support engineer will need to triage: user ID, AD group list, lookup key, etc.
**Don't:** Silently `return null` from `getPlanTypeForUser(user)` when the user has no matching group. The next ticket — "why doesn't the page load for employee 12345?" — has no breadcrumb in the logs, and the on-call engineer has to attach a debugger to find out.
**Why:** "No data" is the most common failure mode in real systems and it's the one that tests rarely cover. A warning log with the right context turns "we have no idea why this user sees the enrollment page" into a single Splunk query. The level matters: `error` would page on every unenrolled user (they're a normal case), but a silent return loses the diagnostic. `warn` is the right shelf.
**Example fix:** `if (matchedGroup === undefined) { logger.warn('No plan-type group matched for user', { userId: user.id, groups: user.groups }); return null; }`
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2829958576
**Detection:** A function that `return null` / `return undefined` / `return []` from a "not found" / "no match" branch with no preceding `logger.warn` (or equivalent) and no comment justifying the silence. Especially when the branch corresponds to a known business state (unenrolled, missing role, no data yet).

## Rule: Don't reduce response payloads to bare IDs that force a client follow-up call when the server already has the data

**Do:** When the server already loaded the data needed to render the immediate UI (display name, max amount, plan type details), include those fields in the response. One round-trip with the data the client needs to render is better than two round-trips that artificially separate "lookup ID" from "fetch details".
**Don't:** Return `{ planTypeId: 7 }` and require the client to immediately call `GET /plan-types/7` to render the page, when the original handler already had the full plan-type record in memory. That's an N+1 pattern in the client, doubles the latency, and complicates client error handling (now both calls can fail independently).
**Why:** "Just return the ID and let the UI look it up" sounds clean (smaller payload, normalized) but it ignores that the server _already paid_ for the lookup to satisfy the current request. Throwing that data away forces the client to repeat work the server just did. The right shape is dictated by what the immediate caller needs to render, not by REST normalization purity.
**Example fix:** Return `{ planType: { id, name, maxAmount, ... } }` from the user/profile endpoint; the UI renders directly from the response.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2829999396
**Detection:** A response DTO that contains only foreign-key IDs (`planTypeId`, `roleId`, `managerId`) when the corresponding handler/service has already loaded (or trivially has access to) the joined record, and the known immediate caller's first action is to fetch that record by ID.

## Rule: Adding a field to a schema/contract requires populating it in the same PR

**Do:** When you add a field to an OpenAPI/swagger schema, a TypeScript DTO/interface, a generated routes file, or any other published response contract, also update the producer (the service `mapToDto` / mapper / serializer) to actually populate that field — and the consumers (tests, mocks, frontend types) — in the _same_ PR.
**Don't:** Add `planTypeName: string` to the `ReimbursementDto` interface and the swagger schema while leaving `ReimbursementService.mapToDto` returning the old object shape. The contract now claims a field that the runtime never produces; clients written against the contract will see `undefined` and fail in unrelated ways.
**Why:** A schema is a promise to clients. Adding a required field to the schema without a producer is a silent lie — `tsc` is happy because the new field is on the _interface_ but the producer's return type still satisfies it (or worse, is widened by the cast/compile shape and the missing field goes undetected). Test suites won't catch it because the mocks were updated to _match_ the schema, not the actual producer output. The bug surfaces at integration time, in another team's repo.
**Example fix:** In the same diff that adds `planTypeName: string` to `ReimbursementDto`, update `mapToDto`: `return { ..., planTypeName: entity.planType?.name ?? '' };` _and_ update every test mock that constructs a `ReimbursementDto` to include the field.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462022
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462060
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462074
**Detection:** A diff that adds a field to a `*Dto` / `*Response` / `*Schema` interface or a `swagger.json` / `openapi.yaml` schema, with no corresponding write of that field in any `map*ToDto` / `serialize*` / `to*Response` / mapper function in the same diff. Also: a DTO field added without a parallel update to mocks/fixtures in `__tests__/`.

## Rule: PR description must match the diff — don't claim work the diff doesn't include

**Do:** Before submitting/updating a PR, re-read the description against the diff. Every bullet in the description should correspond to actual changes; every meaningful change in the diff should be reflected in the description. If you split work to a follow-up, edit the description to say so ("Test mock updates moved to follow-up PR #N").
**Don't:** Leave "Update all test mocks to include `planTypeName`" in the PR description when no test files are touched. Don't ship a description generated from the original ticket without verifying it still describes the diff after refactors and review changes.
**Why:** The PR description is the reviewer's contract for what to look for. A description that promises work the diff doesn't include is worse than no description: reviewers read "test mocks updated" and don't check the test files, the missing update merges, and CI failures (or worse, runtime failures) appear in the next PR. AI reviewers (like Copilot) will keep flagging the discrepancy on every push until it's fixed.
**Example fix:** If the test mock update was deferred, change the description from "Update all test mocks to include `planTypeName` field" to "Test mock updates tracked in #N (follow-up)". If the mocks should have been updated but weren't, update them in this PR.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462060
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462074
**Detection:** A PR description bullet that says "update X", "fix Y", "rename Z" with no corresponding diff hunks. Or: substantive diff changes (new files, deleted endpoints, breaking interface changes) that are not mentioned in the description.

## Rule: Follow the project's established folder structure — repositories under `database/`, not co-located with handlers

**Do:** Place new files in the folder the project already uses for that concern. In a typical layered TypeScript API: controllers in `src/api/<resource>/controller.ts`, services in `src/api/<resource>/service.ts`, repositories in `src/database/repositories/<resource>.ts`, interfaces in `src/interfaces/<resource>.ts`, validators in `src/util/validation.ts`. Look at existing resources (`faq`, `reimbursement`) before creating a new one.
**Don't:** Drop a `repository.ts` inside `src/api/planType/` because "it's only used here". Don't put DTOs in `src/api/<resource>/types.ts` when the rest of the project keeps them in `src/interfaces/`. Don't invent a parallel folder structure for one feature.
**Why:** Folder structure is the project's index. When every resource follows the same shape, a new contributor finds the repository for `reimbursement` exactly where they expect it. One off-pattern feature poisons the convention — the next person copies it ("planType does it this way") and the divergence spreads.
**Example fix:** Move `src/api/planType/repository.ts` → `src/database/repositories/planType.ts`. Update imports (use `@` aliases). Verify the new file matches the pattern of `src/database/repositories/reimbursement.ts` (extends the same base class, exports the same shape).
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17\#discussion_r2722204321
**Detection:** A new file under `src/api/<resource>/` whose name (`repository.ts`, `dto.ts`, `entity.ts`, `migration.ts`) is conventionally placed in a different top-level folder (`src/database/`, `src/interfaces/`, `src/migrations/`).

## Rule: REST routes use plural, lowercase, kebab-case resource names

**Do:** Name HTTP resource routes using the plural form, all lowercase, with kebab-case for multi-word resources: `/api/v1/plan-types`, `/api/v1/reimbursements`, `/api/v1/employee-roles`. Apply the same convention to the path segment whether it's a controller decorator (`@Route('plan-types')`) or a manual route (`router.get('/plan-types', …)`).
**Don't:** Ship `/api/v1/planType` (camelCase + singular), `/api/v1/PlanTypes` (PascalCase), or `/api/v1/plan_types` (snake*case). Don't ship one route as `/reimbursement` and another as `/plan-types` — the entire API surface should follow one rule. When you change one route, update the related child/sub-routes (`/plan-types/:id`, `/plan-types/:id/groups`) to match.
**Why:** Resource naming is a public-API convention with two costs when it's wrong: every existing client integration breaks on the rename, \_and* future endpoints inherit the wrong shape. Plural-lowercase-kebab-case is the standard recommended by every major REST style guide (Google, Microsoft, Stripe) — picking it once means future contributors don't have to debate it per endpoint.
**Example fix:** `@Route('planType')` → `@Route('plan-types')`. Audit sibling routes in the same controller and any `/api/v1/<resource>` registrations elsewhere; rename them in the same PR (with the OpenAPI/swagger regeneration) so consumers see one coordinated change instead of a slow drift.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2723155143
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2728524655
**Detection:** A route path string in `@Route(...)`, `@Get(...)`, `app.METHOD(...)`, `router.METHOD(...)`, or an OpenAPI `paths:` key that contains an uppercase letter, an underscore, or a singular noun where a collection is being addressed (e.g., `/planType`, `/Reimbursement`, `/employee_role`).

## Rule: TODO comments must reference a tracked task or be removed before merge

**Do:** Write `// TODO(JIRA-1234): wire up real auth check before launch` — naming a ticket, an owner, or a specific follow-up condition. If the work is unblocked and small, do it in this PR. If it's intentionally deferred, the ticket reference makes the deferral auditable.
**Don't:** Ship `// TODO: fix this`, `// TODO: revisit`, `// FIXME`, or a vague `// TODO: refactor`. These are notes-to-self that survive every refactor, accumulate forever, and pollute the codebase with "is this still true?" questions.
**Why:** A vague TODO is a permanent marker that someone _thought_ something was wrong but didn't say what or who would fix it. The next reader either ignores it (and the bug ships) or wastes time investigating a stale concern. A ticket-referenced TODO is a deferral; a free-text TODO is a confession.
**Example fix:** `// TODO: handle this case` → `// TODO(REIMB-512): handle multi-month requests once the backend supports it.` If you can't write that one-liner, the TODO doesn't belong in the diff.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772347
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872663
**Detection:** A new line in the diff matching `// TODO` / `// FIXME` / `// XXX` that does _not_ contain `(JIRA-`, `(#`, a ticket key (`PROJ-123`), a username (`@user`), or a specific date.

## Rule: Apply a constants-extraction convention uniformly within a feature

**Do:** Pick one rule per feature/folder for which string/number constants get extracted: either (a) all user-facing strings and magic values live in a single `constants.ts` (or `<feature>.constants.ts`), or (b) they all stay inline at the point of use. Document the choice in the folder's README (or follow the project-wide convention) and apply it to every value in the feature.
**Don't:** Extract `VALUE_NOT_FOUND_FALLBACK` to `constants.ts` while leaving `BEFORE_15TH_OF_MONTH`, `AFTER_15TH_OF_MONTH`, and `CELL_PHONE_REIMBURSEMENT_FOR` defined inline in their using files. The asymmetry begs the question "why this one?" on every PR and forever after.
**Why:** Inconsistent extraction makes each new constant a debate: "do I add it to `constants.ts` or inline it?" The half-extracted state also defeats the reason for extraction in the first place — single source of truth. Pick one and apply uniformly; future PRs follow the precedent without discussion.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795191314
**Detection:** A folder/feature that contains _both_ a `constants.ts` (or `*.constants.ts`) file with some `UPPER_SNAKE_CASE` exports _and_ sibling `.tsx`/`.ts` files defining `const UPPER_SNAKE_CASE = …` at module scope.

## Rule: Identifier names must be spelled correctly

**Do:** Spell every identifier (function names, variables, file names, exports, props, type members) using the correct English spelling. When in doubt, look up the word — most editors have a spell-check extension that flags identifiers in camelCase/PascalCase. Fix typos as soon as they're noticed; a typo'd export name propagates to every import site.
**Don't:** Ship `getAvaliableMonths`, `createReimburesementRequest`, `formatedDate`, `recieveData`. Don't leave a typo in place "because rename is expensive" — every later reader/searcher pays the cost forever, and the longer the typo lives the more files reference it.
**Why:** Typo'd identifiers break grep/search ("why doesn't `Available` find anything?"), make autocomplete useless (the developer types the correct spelling and gets nothing), get copy-pasted into more files, and signal carelessness in code review. They're the cheapest possible fix _now_ and the most expensive fix _later_.
**Examples:** `getAvaliableMonths` → `getAvailableMonths`. `createReimburesementRequest` → `createReimbursementRequest`. `formatNameFirstlast` → `formatNameFirstLast`. Rename the file _and_ all call sites in the same commit.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2789924868
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2789924923
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2789924955
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2789924979
**Detection:** Any identifier or file name that fails a standard English dictionary check. High-frequency offenders: `Avaliable`, `Reimburesement`, `Recieve`, `Seperate`, `Occured`, `Existance`, `Refered`. Run a camelCase-aware spell-checker (e.g., `cspell`) over identifiers in changed files.

## Rule: Every log entry must carry source-location context (file, class, function)

**Do:** Include enough context fields on every `logger.*` call that an on-call engineer reading the log entry in isolation can locate the source line: file name, class name (when the code lives in a class), and function/method name. Use the project's structured-logging helper consistently (e.g., `...loggerCommon('peopleEventService.ts')`, `className: 'PeopleEventService'`, `functionName: 'processMessage'`). Apply this to _every_ log call in a method — not just the error path.
**Don't:** Emit `logger.warn('Missing field')` with no `fileName`/`className`/`functionName` extras. Don't include the context on the error log but skip it on the warn/info logs in the same method. Don't rely on the log message string alone to identify the source — messages get copied between services and the aggregator can't index them reliably.
**Why:** Logs are read in aggregators (Splunk, Datadog, CloudWatch Insights), not in your IDE. Without structured source-location fields, the engineer has to grep the entire codebase for the message string, hope it appears once, and even then can't filter by class/method in queries. Consistent context fields make every log entry searchable, filterable, and dashboardable. Skipping it on a single line is a paper cut every future incident pays.
**Example fix:** `logger.warn('CDC message missing SNS message content', { ...loggerCommon('peopleEventService.ts'), functionName: 'processMessage', className: 'PeopleEventService', extraFields: { subject } });`
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124602833
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124603789
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124604758
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124609924
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124613855
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124614618
**Detection:** Any `logger.*(` / `log.*(` call whose options object lacks `fileName`/`className`/`functionName` (or the project's equivalent helper spread, e.g. `...loggerCommon(...)`). Especially: a method where some log calls have the context spread and others don't.

## Rule: Don't introduce dead code in the same PR that adds it

**Do:** Wire new code into the call graph in the same PR that introduces it. If a new class field, method, function, or module isn't called yet, either (a) include the call site in the same PR, (b) leave it out until the call site is ready, or (c) explicitly document why it ships unused (and link a follow-up ticket). Lint rules like `@typescript-eslint/no-unused-vars` exist for a reason — don't disable them, satisfy them.
**Don't:** Land a class with a `private personRepository: PersonRepository` that's assigned in the constructor and never read, or a `private async handlePersonEvent()` method that nothing calls. Don't add a TODO and merge — the next reader can't tell whether the code is intentional or forgotten, and tree-shaking won't help (the constructor still pulls in the dependency).
**Why:** Dead code on arrival pollutes the diff (reviewers can't tell what's in scope), pulls in unused dependencies (the unused `PersonRepository` still has to be constructed and possibly hits the DB), and rots fast — six months later, no one knows whether to delete it or wire it up. Either commit to the call site or wait until you have it.
**Example fix:** Either remove `personRepository` from the class until `handlePersonEvent` actually uses it, or implement `handlePersonEvent` and call it from `processMessage` in the same PR.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3112856480
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3112856558
**Detection:** A new diff that adds a class field, method, function, or module export with zero references in the changed code. `@typescript-eslint/no-unused-vars` / Pylint `unused-variable` warnings on the changed lines. A constructor that takes/stores a dependency the class never reads.

## Rule: A `catch` that only logs and rethrows is dead weight — remove it

**Do:** Use `try/catch` only when the catch block does something the outer caller can't do equally well: convert to a domain error (`throw new AppError(...)`), trigger a compensating action (rollback, mark-as-failed in DB), retry with backoff, or _stop_ the propagation (return a default, swallow with a warn log). If the catch only adds a `logger.error` and rethrows the same error, delete it — the outer handler / framework will log once with the same context, and your duplicate log just doubles the noise in the aggregator.
**Don't:** Wrap every method body in `try { ... } catch (e) { logger.error('Error in X', { error: e }); throw e; }`. Don't write a `catch -> log -> throw` chain that the next layer also wraps in `catch -> log -> throw`. Each layer adds an entry to the log aggregator for the same incident; the on-call engineer sees the error N times and has to figure out which layer is the "real" failure.
**Why:** Defensive try/catch with no behavior beyond logging _looks_ careful but actively harms operability: it multiplies log entries per incident (paying ingest cost), hides where the error actually originated (every layer's "Error in X" message looks like a fresh failure), and makes it impossible to set a "1 alert per error" threshold. A single uncaught exception in the entry-point handler — logged once by the framework with full stack — is more useful than five "I caught it, here it is again" lines.
**Example fix:** Replace `try { await this.handlePersonEvent(payload); } catch (e) { logger.error('Error handling person event', e); throw e; }` with `await this.handlePersonEvent(payload);` — let the outer SQS handler / Express middleware / Lambda runtime log it once. Keep a catch only if you do something concrete: `catch (e) { await this.markEventFailed(payload.id); throw new AppError('Failed to process person event', '500', payload.id); }`.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3127047663
**Source:** https://github.com/cobank-acb/shd-notification-service/pull/12#discussion_r1817016420
**Detection:** A `catch` block whose body is exactly: zero or more `logger.*` / `console.*` calls, followed by `throw` (with the original error or a trivial rethrow). Especially: the same try/catch shape repeated across siblings in a service, or a nested chain where each layer logs and rethrows.

## Rule: Don't ship commented-out code

**Do:** Delete code you don't intend to run. Git keeps the history; the next reader doesn't need a tombstone in the source. If a snippet is genuinely useful as documentation (rare), put it in a comment block with a clear "EXAMPLE" / "REFERENCE" marker explaining _why_ it's there and what would make it active again.
**Don't:** Leave `// import { WhereService } from '../../old/path';`, `// .filter(x => x.kind === 'foo')`, or `/* old version of the function */` blocks in the file. Don't merge a PR that introduces new commented-out lines, even temporarily — they always stay.
**Why:** Commented-out code is unverifiable: the reader can't tell whether it was load-bearing, abandoned, a half-finished refactor, or kept "just in case". It rots silently (the surrounding code drifts, the dead snippet doesn't), it makes search results lie ("yes, `WhereService` is referenced here"), and it costs reviewer attention on every future PR that touches the file. Git history serves the same purpose without any of these costs.
**Example fix:** Delete the line(s). If the deleted code is genuinely valuable to recover later, write a one-line comment saying so and link the issue/PR where it lives: `// Removed eager filter — see #1234 for context if reintroducing`.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872341
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872480
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872649
**Detection:** Any added line that starts with `//` (or `#` in Python, `--` in SQL) and contains code-shaped tokens (`import `, `function `, `class `, `=>`, `(`, etc.). Also: any added `/* … */` block whose body parses as code rather than English.

## Rule: Throw the project's typed errors in request handlers, not bare `Error`

**Do:** When a request-handler-layer check fails (missing field, invalid filter, not found, forbidden), throw the project's domain error class that the central error middleware already maps to the correct HTTP status (`InvalidFilterError`, `NotFoundError`, `AppError(message, '400', context)`, etc.). Read the existing error middleware once to learn the catalogue and use it consistently.
**Don't:** `throw new Error('filter is required')` from a controller. The generic `Error` doesn't extend `BaseAssociateError` (or whatever the project's tagged base class is), so the error handler treats it as an unhandled exception and returns 500 — when the client should have gotten a 400. Don't return `res.status(400).json(...)` ad-hoc either; that bypasses the central handler and produces inconsistent error envelopes.
**Why:** Centralized error handling only works if every error-throwing site uses a class the handler can recognize. A bare `Error` triggers the "unknown failure" branch (500, generic message, alert page) and hides what should have been a clean client-facing 4xx. Worse, integration tests that assert `expect(response.status).toBe(400)` start passing only by accident, then break when the handler rewires.
**Example fix:** `if (!body.filter) throw new InvalidFilterError('Request body must include a filter array');` — the error middleware maps this to 400 with a typed envelope.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872577
**Source:** https://github.com/cobank-acb/shd-notification-service/pull/12#discussion_r1817272574
**Detection:** A `throw new Error(...)` (or equivalent) inside a controller / route handler / middleware in a project that defines a tagged base error class (`BaseAssociateError`, `AppError`, etc.). Also: a route handler that calls `res.status(4xx)` directly instead of throwing through the central handler.

## Rule: Accept a single canonical shape at the API boundary; don't accept "T or T[]"

**Do:** Pick one shape for each request field — almost always the array form when more than one value is conceptually possible — and require it at the API boundary. Document and validate that shape in the swagger/OpenAPI/tsoa schema. Convert internally only if you need a different shape for processing.
**Don't:** Accept `filter: PersonFilter | PersonFilter[]` "to be flexible". The flexibility costs you: every consumer has to remember which forms are accepted, every internal helper has to handle both ("if not array, wrap it"), every test needs both shapes, the swagger doc becomes a union the client codegen has to discriminate, and the next maintainer can't tell whether single-object callers actually exist or it's just defensive scope creep.
**Why:** Boundary polymorphism is a cost you pay forever. Each accepted shape multiplies the test matrix, the docs surface, the type union depth, and the chance of subtle bugs (e.g., a single object that itself contains arrays, where the "is it an array?" check picks the wrong branch). The "convenience" benefit lives only at the very first call site; every subsequent reader pays the cost. Converging at the boundary makes every internal helper, log line, and schema simpler.
**Example fix:** API contract: `filter?: PersonFilter[]` (always an array, optional). Internal helper signature changes from `buildFindOptionsWhere(filter?: PersonFilter | PersonFilter[])` to `buildFindOptionsWhere(filter: PersonFilter[] = [])`. The "wrap if not array" logic disappears.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2991450321
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2991465537
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2991469887
**Detection:** A request DTO field typed as `T | T[]` (or `Foo | Foo[]`). A handler/service whose first action on a parameter is `Array.isArray(x) ? x : [x]`. A swagger/OpenAPI schema with `oneOf: [Foo, array of Foo]` for the same field.

## Rule: Public exports of a shared library must carry JSDoc covering usage, gotchas, and examples

**Do:** Every type, interface, class, function, and config field _exported from a shared library_ must have a JSDoc block that says (a) what it's for, (b) any non-obvious constraint a consumer needs to know ("don't include trailing slashes", "URL must be HTTPS in prod"), and (c) at least one `@example` for non-trivial APIs. Keep the JSDoc next to the export so editor tooltips show it at every call site.
**Don't:** Publish a library where `interface ClientConfig { baseUrl: string; token?: string; ... }` has no JSDoc on the fields. The consumer reads the type signature in their IDE, sees no guidance, and either guesses or opens the source — both of which produce inconsistent integrations and bug reports the library author has to triage.
**Why:** In an _application_, a missing JSDoc costs one team a search-and-grep. In a _library_, it costs every consuming team forever. The library author writes the JSDoc once; without it, every consumer pays the cost of figuring out the API on their own, and every behavior change becomes a "why is this broken?" issue. Library JSDoc is documentation _and_ contract — it's how you tell consumers what you're promising not to change.
**Example fix:** `/** Base URL of the People API. Do not include a trailing slash. Example: 'https://people.dev.example.com'. */ baseUrl: string;` and on the constructor: `/** Creates a People API client. Token resolution: if config.token is provided, it is used as-is (M2M). Otherwise the client calls getSession() from shd-api-common-lib at request time to read the signed-in user's bearer token. @example const client = new PeopleApiClient({ baseUrl: AppConfig.PEOPLE_API_URL }); */`.
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747907465
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747931170
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747938379
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747967940
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747969460
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747970970
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747971794
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747972573
**Detection:** An exported `class` / `interface` / `type` / `function` / `const` from a library's `src/**/index.ts` barrel (or referenced transitively from it) whose declaration has no leading `/** ... */` JSDoc block, or whose JSDoc is just a one-line summary on a non-trivial API (multiple parameters, behavioral choices, side effects).

## Rule: A shared library's defaults must not assume host-application env vars for caller-supplied values

**Do:** When a library exposes a config (URL, token, API key, region), require the caller to pass it in (or supply it through a documented init function). Defaults should be safe and inert — `undefined`, an obvious placeholder that fails fast, or a value derived from a clearly-named library-prefixed env var (`PEOPLE_API_LIB_BASE_URL`, not `BASE_URL`).
**Don't:** Default `client.token` to `process.env.AUTH_TOKEN` (or any unprefixed env var) inside the library. The consumer didn't ask for that variable, doesn't know the library reads it, and has no way to discover the coupling — the library's behavior changes silently based on the host process environment. Worse, a token-shaped value belongs to the request (M2M token from PingOne, or a session-derived bearer), not to a long-lived env var.
**Why:** Hidden env-var defaults make the library a leaky abstraction: integration behavior depends on the consumer's deployment environment, not on what they explicitly pass to the library. Debugging "why does it work in dev and not in prod?" leads to a `process.env` read three layers deep that no one knew existed. For credentials specifically, env-var defaults invite long-lived secrets where a per-call resolver (PingOne M2M, session token) is the actual right shape.
**Example fix:** `constructor(private readonly config: ClientConfig) {}` with `interface ClientConfig { baseUrl: string; token?: string; }` — no env-var default. Token resolution: if `config.token` is set, use it; else call the library's documented `getSession()` extension point at request time. Document the choice in the constructor JSDoc.
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2755767934
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2755772014
**Detection:** A shared library's source contains `process.env.<NAME>` where `<NAME>` is not prefixed with the library's package short name (e.g., `PEOPLE_API_LIB_*`). Especially: `process.env.*` referenced as a default value in a constructor, factory, or config getter for an auth/URL/credential field.

## Rule: Don't add overlapping config knobs that solve the same problem

**Do:** When a library or service already accepts a value via one mechanism (e.g., constructor config), don't add a second mechanism for the same value (a per-method `override` parameter, an env var, a setter). Pick the single shape that gives the consumer the flexibility they need (almost always: pass at construction _or_ resolve per call from a documented source) and document it.
**Don't:** Accept `token` in `ClientConfig` _and_ a `tokenOverride` parameter on every method. Both fields exist to set the auth token for the call; together they create a precedence question (which wins? what if both are set? what if `tokenOverride` is the empty string?), bloat the API surface, and double the test matrix without adding consumer value.
**Why:** Overlapping knobs are a permanent tax: every method signature carries the override; every caller wonders whether to use the constructor field or the method parameter; every test must exercise both. The "flexibility" is illusory — a single well-designed mechanism (constructor token wins; otherwise resolve from session at request time) covers every legitimate use case (M2M, signed-in user, test injection) without the precedence rule.
**Example fix:** Remove the per-method `tokenOverride` parameter. Document the constructor's `token?: string`: "If provided, used as-is for every request (M2M). Otherwise the client calls `getSession()` per request to read the signed-in user's bearer token. To override per-test, construct a new client."
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747926069
**Detection:** A method whose parameter list contains a name like `*Override`, `*Token`, `*Url`, `*Headers` that mirrors a field already defined on the class/config object. Or: documentation that has to explain a precedence rule between two ways to set the same value.

## Rule: A library's peer/runtime dependency versions must match the upstream library it integrates with

**Do:** When publishing a library that integrates with another shared library (e.g., `@cobank-acb/shd-api-common-lib`), read that library's `peerDependencies` (and major `dependencies`) and match the version ranges exactly. Document the alignment in the new library's README ("This library is designed to be installed alongside `shd-api-common-lib@>=0.3.28`; `axios` peer-dep matches that library's range."). If you need a newer version, upgrade the upstream library first.
**Don't:** Pick the latest version of `axios` (or any shared transitive dep) without checking what the upstream library you're co-installing with requires. A consumer who installs both ends up with two copies of `axios` in `node_modules` (different majors, or even different minors of versioned bundle output), interceptors registered on one instance don't fire for the other, and the bug surfaces as "auth headers missing on some requests".
**Why:** When two libraries in the same dependency graph specify incompatible ranges of a shared dependency, npm/yarn/pnpm install both. Stateful libraries (axios interceptors, axios instances, singletons) silently misbehave because each library is talking to a different copy. The fix at consume-time is painful (`overrides` in package.json, hoisting tricks). The fix at publish-time is one line of version alignment.
**Example fix:** If `shd-api-common-lib` declares `"axios": "^1.6.0"` as a peer dep, the new library should declare exactly the same: `"peerDependencies": { "axios": "^1.6.0", "@cobank-acb/shd-api-common-lib": ">=0.3.28" }`. Don't put `axios` in `dependencies` — it must be a peer to share the consumer's installed copy.
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747994704
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2755809782
**Detection:** A new library's `package.json` lists a shared transitive dep (`axios`, `typeorm`, `react`, `zod`, `lodash`) under `dependencies` instead of `peerDependencies`, or under `peerDependencies` with a version range that doesn't intersect the same dep's range in a co-installed `@cobank-acb/*` library. Run `npm ls axios` (etc.) on a consumer install — more than one resolved version is the bug.

## Rule: Don't commit one-shot review/summary/scratch markdown files

**Do:** Keep PR-scratch artifacts (AI-generated summaries, "PR*DESCRIPTION.md", "pull_request_150_summary.md", "NOTES.md", "TODO_BEFORE_MERGE.md", design diaries) outside the repo. If a summary is genuinely useful, paste it into the PR description, an issue, or the design-doc folder where the team agreed such artifacts live. Add the patterns to `.gitignore` so they can't get committed by accident.
**Don't:** Commit `pull_request*<n>_summary.md`, `chat_export.md`, `summary_for_review.md`, or any file whose name encodes a single PR number / a single review session. They have no maintained meaning after the PR merges, accumulate in the root folder, and confuse future readers ("is this still relevant?").
**Why:** PR-scoped scratch files are write-once: useful to the author for an hour, useless to everyone after merge. Once committed they become permanent noise — they show up in folder listings, pollute search results, and survive long after the context that produced them is gone. The right place for ephemeral context is the PR description (which is permanent and tied to the diff) or your local working directory (which doesn't ship).
**Example fix:** Delete the file from the diff. Move the content to the PR description. Add `pull_request__\_summary.md`, `chat_export_.md`, `\*\_NOTES.md`(or your team's convention) to`.gitignore`.
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2984557663
**Detection:** A new top-level `.md`file in the diff whose name references a PR number, a date, "summary", "notes", "scratch", "chat", "export", or "todo". Especially: any`.md`at the repo root that isn't`README.md`/`CONTRIBUTING.md`/`CHANGELOG.md`/`SECURITY.md`/`LICENSE.md`.

## Rule: A function with multiple try/except + nested branches must be decomposed into named steps

**Do:** When a function exceeds ~75 lines and contains multiple `try/except` blocks, multiple nested `if/else` branches, or both, split it along the natural boundaries of its work into named helper functions. Each helper should encapsulate one step that's easy to test in isolation (e.g., `resolve_indices`, `extract_facets_per_index`, `apply_intersection`, `build_response`). The orchestrating function then reads as a short list of step calls — the control flow becomes the documentation.
**Don't:** Land a 200-line route handler / service method with three nested `try/except` blocks, a `for` loop that mutates four collections, an `if indices is None: ... else: ...` branch that duplicates most of the loop body, and inline performance timing. Reviewers can't reason about the failure modes (which `except` catches what?), tests can't exercise individual steps, and the next bug fix will add a fourth nesting level because that's the path of least resistance.
**Why:** Cognitive complexity compounds: each level of nesting and each additional try/except multiplies the number of mental states the reader has to track. Past ~3 levels deep, even careful reviewers miss bugs (a 503 swallowed by an outer `except`, a variable assigned in only one branch, a partial-state outcome the test suite never reaches). Decomposition is the cheapest tool for restoring reviewability — it doesn't change behavior, it just renames the chunks so each one fits in one screen and one test.
**Example fix:** `async def get_facets(...): normalized_indices = await SearchService.resolve_indices(client, alias, indices); facets, failed_indices, empty_indices = await SearchService.extract_facets_per_index(client, normalized_indices); if indices is None and len(facets) > 1: facets = SearchService.apply_intersection(facets); return build_facets_response(facets, failed_indices, empty_indices)`. Each helper is independently testable.
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2991380155
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r2991505287
**Detection:** Any function whose body is longer than ~75 lines, _or_ contains 2+ `try/except` blocks, _or_ contains nested `if/else` past 3 levels deep, _or_ has a cyclomatic complexity score above 10 (most linters report this; e.g., `radon cc -s`, `flake8-cognitive-complexity`, `eslint complexity`).
