# Security

## Rule: Validate at system boundaries only

**Do:** Validate untrusted input where it enters the system (HTTP handlers, queue consumers, CLI args).
**Don't:** Add defensive checks for conditions that cannot occur internally.
**Why:** Internal defensive code is dead weight and hides real bugs.

## Rule: Watch for OWASP Top 10

**Do:** Treat injection, broken auth, SSRF, insecure deserialization, etc. as blockers.
**Don't:** Concatenate untrusted input into SQL, shell, HTML, or URLs.
**Detection:** String interpolation into `exec`, `eval`, raw SQL, shell calls.

## Rule: Don't log sensitive data; sanitize error messages

**Do:** Log only static, generic messages or carefully sanitized values. If logging an error, extract only safe fields (e.g., `error.message` or a status code).
**Don't:** Log full error objects, environment variables, API responses, request bodies, tokens, or any data that might contain secrets.
**Why:** Error objects can serialize and expose sensitive information embedded in stack traces, response bodies, or custom properties. Logs are often forwarded to external systems or accessed by multiple teams; once logged, secrets are impossible to fully revoke.
**Detection:** Any of: `console.error(error)`, `logger.error(error)`, `console.log(process.env)`, `console.error(response)`, `console.log('...', response)`, `logger.error('...', fullObject)`, or logging variables with names suggesting secrets: `console.log(...bearer_token...)`, `console.log(...password...)`, etc. Look for logging of entire objects/responses/requests, especially in error paths — log only status codes, error.message, or static descriptions instead.
**Example fix (full response):** Replace `console.log('Response:', response)` with `console.error('AuditBoard /controls request failed. Status: ${response.status}, Body: ${errorBody}')` where errorBody is a sanitized text extraction.
**Example fix (token):** Replace `console.log('Bearer Token:', bearer_token)` with `console.log('Using bearer token for AuditBoard /controls request')` — static message, no token value.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453951 and https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453933
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772368
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/253#discussion_r3124609054

## Rule: Don't string-interpolate structured logging objects; pass them as separate arguments

**Do:** Pass structured data (objects, error objects, or the result of a logging helper) as a separate argument to the logger: `logger.error('Message', structuredData)` or `logger.error('Message', convertErrorForLogging(error))`.
**Don't:** Template-interpolate objects into the message: `logger.error(\`Message: ${errorHelper(error)}\`)` or `logger.error(\`Error: ${error}\`)`.
**Why:** String interpolation serializes objects to `[object Object]`, losing all the structured data. Most logging systems (Winston, Pino, Bunyan, etc.) accept multiple arguments and preserve structure in the second+ arguments for proper JSON serialization and querying.
**Detection:** `logger.error(\`...\${...}\`)` or `logger.error('...' + errorHelper(...))` when a helper function returns an object or when logging error data.
**Example fix:** Replace `logger.error(\`${convertErrorForLogging(error)}\`)`with`logger.error('[RuntimeMonitor] TTL exceeded; terminating process.', convertErrorForLogging(error));`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453879

## Rule: Env-var-injected auth headers must be gated to development mode only

**Do:** Wrap any code that reads tokens/credentials from `import.meta.env` / `process.env` and adds them to outgoing request headers in an explicit `if (import.meta.env.MODE === 'development')` (or equivalent) guard. The check is the security boundary — make it impossible to accidentally trigger in prod.
**Don't:** Add `Authorization: Bearer ${import.meta.env.REACT_TOKEN}` headers unconditionally "because the env var won't be set in prod anyway". A misconfigured prod deployment that accidentally inherits a dev env var will silently start sending dev tokens to your prod backend (or worse, prod tokens stored in CI to the wrong target).
**Why:** "The env var won't be set in prod" is a configuration assumption, not a security control. Real auth must come from the production auth flow (cookies, OAuth, IDP); env-var fallbacks exist only for local dev. A mode check makes that intent explicit and auditable.
**Example fix:**

```ts
if (import.meta.env.MODE === "development") {
  if (import.meta.env.REACT_TOKEN) {
    headers.set("Authorization", `Bearer ${import.meta.env.REACT_TOKEN}`);
  }
}
```

**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081270
**Detection:** A `headers.set('Authorization', ...)` / `headers.set('x-auth-...', ...)` whose value comes from `import.meta.env.*` / `process.env.*`, with no surrounding `MODE === 'development'` (or equivalent dev-only) guard.

## Rule: Authorization-bearing route handlers must be rate-limited

**Do:** Apply a rate-limiting middleware (project-standard: `express-rate-limit` configured at the app level, or per-route with stricter limits for sensitive endpoints) to every HTTP route that performs authentication or authorization. The rate limiter is part of the auth surface, not a "nice to have".
**Don't:** Ship a new authenticated route (`@Security('jwt')`, tsoa-generated `expressAuthentication`, or hand-rolled `authMiddleware`) without confirming it sits behind the app's rate limiter. Don't dismiss CodeQL "Missing rate limiting" findings without either (a) confirming the route is covered by an upstream limiter (gateway, app-level middleware) and adding a code comment + a CodeQL suppression with justification, or (b) adding the limiter.
**Why:** Authenticated endpoints are the highest-value brute-force target — credential stuffing, token-guess loops, enumeration of valid IDs. Without a limiter, an attacker can issue thousands of requests/second using stolen creds before lockout. CodeQL's "performs authorization but is not rate-limited" alert exists for this exact reason; ignoring it on every PR creates alert fatigue and ships the gap.
**Example fix:** At the app entry point: `app.use(rateLimit({ windowMs: 60_000, limit: 100, standardHeaders: 'draft-7' }));` _and_ a stricter limiter on sensitive routes (`app.use('/api/v1/auth', rateLimit({ windowMs: 60_000, limit: 10 }));`). For tsoa-generated routes, configure the limiter on the Express app _before_ the generated routes are registered.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2718757135
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2718757141
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2718757144
**Detection:** A new route registration (`@Get`/`@Post`/`@Put`/`@Delete` decorator, `app.get(...)`, `router.post(...)`, generated `RegisterRoutes(app)`) on an app whose entry point has no `rateLimit` / `express-rate-limit` / `express-slow-down` middleware registered. Or: an open CodeQL "Missing rate limiting" alert on a route whose PR doesn't add a limiter or a justified suppression.


## Rule: New request handlers must declare auth annotations matching their peers

**Do:** When you add a new route to an existing controller, copy the auth/security decorators from the controller's other endpoints unless you have an explicit reason not to. Read the existing handlers once (`@Security('bearerAuth')`, `@Security('m2mAuth', ['scope'])`, `requireAuth` middleware, etc.) and apply the same set to the new route. If the new route is intentionally public, write a one-line comment justifying it.
**Don't:** Add a new `@Post('/people/search')` handler to a controller whose other endpoints all carry `@Security('bearerAuth')` and leave the new route undecorated. Generated route files (tsoa, NestJS) will register an _unauthenticated_ endpoint that exposes whatever the handler returns — and code review easily misses the omission because the new file is large and the missing line is elsewhere.
**Why:** Auth-by-omission is the most common way an internal endpoint accidentally ships public. Tooling won't always flag it (the route is "valid"), and the leak surfaces only when someone discovers it externally. Mirroring the controller's existing auth pattern is the cheap, mechanical defense that catches it at PR time.
**Example fix:** `@Security('bearerAuth') @Post('/search') public async searchPeople(...)`. If the route is intentionally public: `// Public: used by the unauthenticated landing page health probe — see SEC-123` directly above the decorator block.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872556
**Detection:** A new `@Get`/`@Post`/`@Put`/`@Delete`/`@Patch` decorator on a method whose sibling methods in the same controller class all carry `@Security(...)` (or equivalent middleware), and the new method has none. Equivalent for non-tsoa frameworks: a new `router.<verb>(...)` registration that omits the auth middleware its neighbors include.

## Rule: Input validation must fail closed — invalid filter input must reject the request, not silently broaden the query

**Do:** When parsing a search/filter/query input fails (invalid date, unknown operator, non-string value for a `like` operator, malformed structure), throw the project's `InvalidFilterError` (or equivalent 400-mapping error) so the request is rejected. The client must learn that their input was bad; the database must not see a query that asked for "everything" because the filter quietly dropped.
**Don't:** Log a `warn` and `return undefined` from the parser, letting the calling query proceed without that constraint. On a search endpoint, "no constraint" means "match everything within the table", and a single bad filter element can leak the entire dataset. Don't accept `unknown` values into pattern-match operators (`like`, `contains`) and forward them into a `LIKE %${value}%` template — `value` could be `{}` and produce `%[object Object]%`, an unintended pattern that may match millions of rows.
**Why:** Search/list endpoints have an asymmetric failure mode: too-narrow results are visibly wrong (zero rows), too-broad results look like success (rows return). Fail-open input parsing therefore turns "bad input" into "unauthorized data exfiltration via a malformed query". Failing closed is both safer and more useful — the client gets a precise 400 telling them what's wrong, ops gets a clear log entry, and the database never sees the bad query.
**Example fix:** `if (!isValidDate(value)) throw new InvalidFilterError(\`Invalid date for field \${fieldName}\`);` and `if (typeof value !== 'string') throw new InvalidFilterError(\`Operator '\${op}' requires a string value\`);`.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872432
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872534
**Detection:** A filter/query parser that, on parse failure, calls `logger.warn(...)` and `return undefined` / `return null` / `return {}` instead of throwing. A SQL/ORM pattern operator (`Like`, `ILike`, `contains`) called with a value typed `unknown` / `any` with no preceding `typeof value === 'string'` check.

## Rule: Validate pagination inputs before using them in offset arithmetic

**Do:** Before computing `skip = (page - 1) * limit` (or any offset/limit math), validate that `page >= 1` and `limit > 0` and `limit <= MAX_PAGE_SIZE`. Throw `InvalidFilterError` (or equivalent 400) with the offending values. If the project already has a `calculatePagination(page, limit)` helper that does this, use it — don't re-implement.
**Don't:** Compute `skip = (page - 1) * limit` with raw `page` / `limit` from the request body. `page = 0` produces `skip = -limit` (negative offset, undefined behavior across DBs), `page = -1` produces a positive skip with the wrong semantics, `limit = 0` returns no rows but still pages forward forever, and `limit = 1_000_000` lets a single request load the entire table into memory.
**Why:** Pagination math is a small attack surface with a big blast radius. Negative offsets either crash the query or silently misbehave (Postgres rejects, MySQL clamps to 0, SQLite returns the whole table from offset 0). Unbounded `limit` is a one-line DoS. The validation is three lines; skipping it is a security and reliability bug.
**Example fix:** `const { skip, take } = calculatePagination(page, limit);` — and inside `calculatePagination`: `if (!Number.isInteger(page) || page < 1) throw new InvalidFilterError('page must be >= 1'); if (!Number.isInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) throw new InvalidFilterError(\`limit must be 1..\${MAX_PAGE_SIZE}\`);`.
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203#discussion_r2949872495
**Detection:** A `(page - 1) * limit` (or `page * limit`, `offset = ...`) expression in a request handler/service with no preceding range check on `page` and `limit`. A `take`/`limit` value passed to a query builder without an upper bound. A new pagination call site that doesn't reuse the project's existing `calculatePagination` helper.


## Rule: Sanitize user-controlled values before logging them — log injection is a real CodeQL finding

**Do:** Before passing any value that originated from a request (URL params, query string, body, headers, cookies) into a `logger.*` call, run it through a sanitizer that strips/escapes CR (`\r`), LF (`\n`), and other control characters. The shared lib's `sanitizeMessageForLogging(value)` (or equivalent) is the standard helper. Apply this even to fields you "trust" — request validation runs at a different layer and sanitization is cheap.
**Don't:** `logger.info(\`New statement received on topic ${topic} with body ${message}\`)` where `topic` / `message` came from `req.body` or `req.query`. An attacker can submit `topic = "foo\n2026-04-26 12:00:00 ERROR [auth] User admin logged in"` and the log file (or aggregator query) shows two entries — the second crafted to mislead an on-call engineer or to evade a SIEM rule.
**Why:** Log injection is a distinct threat from "don't log secrets". The attacker isn't trying to read your logs — they're trying to _write_ to them. Forged log entries pollute incident timelines, hide real attacks, evade alert keywords, and on some pipelines can corrupt downstream parsers (e.g., a planted JSON brace breaks a JSON-line ingestion). CodeQL flags this under "Log injection" / `js/log-injection`; treat the alert as a real finding, not a false positive.
**Example fix:** `logger.info(\`New statement received: ${sanitizeMessageForLogging(topic)} with message ${sanitizeMessageForLogging(message)}\`);`. For very high-noise inputs, drop them from the log entirely or use `extraFields` so the log aggregator stores them as structured data (where the fields are escaped per the sink's encoding) rather than as part of the message string.
**Source:** https://github.com/cobank-acb/shd-notification-service/pull/12#discussion_r1815666316
**Detection:** Any `logger.*(...)` / `console.*(...)` template literal whose `${...}` interpolation references a value reachable from `req.*` / `request.*` / `event.*` / `ctx.*` / framework parameters typed `@Body`/`@Query`/`@Path`/`@Header` without an intervening `sanitizeMessageForLogging(...)` (or equivalent) call. Also: any open CodeQL "Log injection" / `js/log-injection` / `py/log-injection` alert on a route handler.


## Rule: Don't catch upstream availability errors and convert them into success responses

**Do:** Distinguish "per-item failure" (one of N requested resources couldn't be fetched — partial-success endpoints can report it in the response body and return 200) from "service-level failure" (the upstream itself is unreachable, timing out, or returning 5xx — the request hasn't really succeeded). Let availability errors propagate as the equivalent client-facing 5xx (502/503/504). For partial-success endpoints, narrow the `except` to the specific failure modes you intend to absorb (`HTTPException(status_code=404)`, `NotFoundError`, etc.) and `raise` everything else.
**Don't:** `except HTTPException as e: failed_indices.append({"index": idx, "reason": "error"})` and return 200. That converts an OpenSearch outage (`status_code=503`), a timeout, a transport error, into a successful response with a `failed_indices` entry. Health checks pass, dashboards stay green, alerts don't fire — and clients silently get incomplete data on every request until someone notices the failure rate by hand.
**Why:** HTTP status codes are the contract for monitoring, retry behavior, circuit breakers, and SLO measurement. A 200 with `failed_indices: [...]` is invisible to all of that infrastructure. The on-call dashboard shows 100% success rate while OpenSearch is down. The client's retry middleware doesn't retry (200 isn't retryable). The SLO burn rate doesn't fire. Convert the request to its honest status code so the rest of the system behaves correctly.
**Example fix:** `except HTTPException as e:
    if e.status_code in (502, 503, 504):
        raise  # service unavailable — propagate
    if e.status_code == 404:
        failed_indices.append({"index": idx, "reason": "not_found"})
    else:
        raise  # unknown HTTPException — don't silently absorb`. Same for transport-layer exceptions: catch `ConnectionError`/`ConnectionTimeout`/`TransportError` and raise `HTTPException(503)`; let them propagate even from inner per-item loops.
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150\#discussion_r2977154359
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150\#discussion_r3001666502
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150\#discussion_r3001666630
**Detection:** A `try/except` whose `except` matches a broad type (`HTTPException`, `Exception`, transport-library base) inside a route handler and whose body unconditionally appends to a `failed_*` list / sets a partial-status flag without checking the underlying status code or exception type. Especially: per-item loops in "best effort" handlers that lack any `raise` branch.
