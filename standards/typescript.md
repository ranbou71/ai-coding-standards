# TypeScript / JavaScript

## Rule: Use `@` path aliasing for all imports

**Do:** Import via the configured `@/...` alias, including from barrel `index.ts` files.
**Don't:** Use long relative paths like `../../../lib/foo`.
**Why:** Aliased paths survive refactors and read clearly.
**Detection:** Regex `from ['"]\.\.\/\.\.\/` in changed `.ts`/`.tsx` files.

## Rule: Barrel exports must also use `@` aliasing

**Do:** Inside `index.ts`, re-export with `export * from '@/feature/x'`.
**Don't:** Use relative re-exports in barrels.
**Why:** Consistency; avoids hidden coupling to file layout.
**Detection:** Relative path inside `index.ts`.

## Rule: Unref timers/intervals so they don't block process exit

**Do:** After creating a `setInterval()` or `setTimeout()` that should not block the process from exiting, call `.unref()` on the returned handle. This is especially important for background monitors, periodic checks, or "nice-to-have" background work.
**Don't:** Leave timers active without `.unref()` if the timer is not critical to keeping the process alive.
**Why:** By default, `setInterval()` and `setTimeout()` keep the Node.js event loop alive, preventing graceful shutdown. If a job finishes naturally and the caller forgets to call `stop()`, the process hangs indefinitely waiting for the timer. `.unref()` allows the process to exit once all critical work is done.
**Example:** `const interval = setInterval(...); interval.unref();`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453858
**Detection:** `setInterval()`, `setTimeout()`, or similar timer creation in a service/monitor class without a corresponding `.unref()` call immediately after.

## Rule: If you fetch a required value, use it in the API call; don't drop it during refactoring

**Do:** When refactoring API calls, audit the headers and parameters to ensure all required fields are still present and being sent. If code fetches a value via `await getCredentials()` or from configuration, it must be included in the request.
**Don't:** Fetch a required header/parameter value (like `application_id`, auth token, or API key) but then omit it from the actual request, especially when refactoring from one implementation to another.
**Why:** Silent omission of required headers causes API calls to fail or succeed with partial results, and the bug is invisible because the code "looks correct" at each layer. The value is fetched but not sent — a clear sign of incomplete refactoring.
**Detection:** Code fetches a value (e.g., `const { bearer_token } = await this.getCredentials()`) but the subsequent fetch/request doesn't include it in headers or query params.
**Example fix:** If `getCredentials()` returns `{ bearer_token, application_id }`, ensure both are sent in the `Authorization` and `X-Application-Id` headers (or appropriate headers for that API).
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453909
