# TypeScript / JavaScript

## Rule: Use `@` path aliasing for all imports

**Do:** Import via the configured `@/...` alias, including from barrel `index.ts` files.
**Don't:** Use long relative paths like `../../../lib/foo`.
**Why:** Aliased paths survive refactors and read clearly.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793735369
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793800590
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795016979
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795022526
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2790080065
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2790113391
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25#discussion_r2790155581
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1#discussion_r2747904113
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

## Rule: Honor optional fields — narrow before passing to code that requires them

**Do:** When a type marks a field optional (`data?: T`, `T | undefined`), treat it as optional everywhere it's read — including before forwarding it to downstream systems (SNS, DB, logs). Either (a) narrow with an explicit check before forwarding (`if (!body.data) { handleMissing(body); return; }`), or (b) tighten the type if the field is in fact always present at this boundary (split into `RawBody` vs `ValidatedBody`, or use a discriminated union per event type so the required fields are required for the variants that need them). Validate at the boundary (the entry of `processEvent`/handler), not deep inside helpers. Apply the same narrowing to _derived_ required fields (e.g. `person.identifier` extracted from an optional source field) before publishing — an unusable downstream message is worse than a clear validation error that gets persisted/retried.
**Don't:** Pass a possibly-undefined field into a function that takes a required parameter (`handler(body.data)` when `data?: T` and `handler` expects `T`). Don't `JSON.stringify` and publish a payload whose business-key field (id, identifier, correlation key) could be `undefined` because every type along the chain marked the underlying source optional. Don't rely on the handler or downstream consumer to throw — the cause becomes a runtime "Cannot read property X of undefined" or a poison message in the queue, instead of a clear validation error tied to the request.
**Why:** Optional-but-assumed-present is one of the most common runtime-failure patterns and the type system is already telling you about it. Narrowing once at the boundary turns a vague late crash (or worse, a silently-published unusable message) into a precise, testable error path and keeps the persisted/ack'd outcome consistent for the caller.
**Examples:**

- Input narrowing: `function processEvent(body: DayforceEventBody) { if (!body.data) { this.handleMissingData(body); return; } const handler = this.eventHandlers[body.type as KnownEventType]; const person = handler ? handler(body.data) : this.handleUnknownEventType(body); … }`
- Output narrowing: before `await this.publishToSNS(JSON.stringify(person));`, assert `if (!person.identifier?.trim()) { throw new AppError('Person.identifier is required for publishing'); }` so the raw event is persisted/retried instead of an unusable message being emitted.
  **Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859888
  **Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859907
  **Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772336
  **Detection:** A property typed as optional (`foo?: T` / `T | undefined`) is read and passed straight into a call site that requires a non-undefined `T`, with no preceding `if`/early-return/assertion narrowing it. Also: a field documented as a required business key (id/identifier/correlation key) is published, persisted, or logged downstream without a non-empty check, when its source type marks it optional.

## Rule: Don't construct heavy services inside per-request controllers

**Do:** Instantiate services that hold reusable resources (AWS SDK clients, DB connections, HTTP keep-alive pools, in-memory caches) once at module load and reuse them. Inject them into controllers via constructor parameters, an IoC container, or a module-level singleton (`export const dayforceEventService = new DayforceEventService();`). Controllers should be thin and cheap to construct.
**Don't:** Call `new HeavyService()` inside a controller's constructor when the framework (e.g. tsoa with default route generation) instantiates a fresh controller per request. Each request will rebuild the SDK clients, re-read config, and discard any in-process cache the service was supposed to hold.
**Why:** Per-request construction of AWS SDK clients (`DynamoDBDocumentClient`, `SNSClient`, etc.) wastes CPU, prevents connection reuse, defeats SDK-level caches/keepalive, and makes warm-path latency look like cold-path latency. It also makes any internal cache (token cache, schema cache) useless because it dies with the controller.
**Example fix:** Move construction to module scope: `// dayforceEventService.ts\nexport const dayforceEventService = new DayforceEventService();` then `constructor() { super(); this.dayforceEventService = dayforceEventService; }` — or accept it as a constructor parameter and wire it up in the composition root.
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/20#discussion_r3112859937
**Detection:** `new SomeService()` (especially services that internally `new` AWS SDK clients, DB clients, or HTTP clients) inside a controller/handler constructor in a framework that creates a controller per request (tsoa default, NestJS `Scope.REQUEST`, Express route handlers that `new Controller()` per call).

## Rule: Run `tsc-alias` for every TypeScript project you compile

**Do:** When the build emits more than one TypeScript project (e.g. `tsc && tsc -p tsconfig.cronjobs.json`), run `tsc-alias` once per project so the `@/...` aliases are rewritten in every emitted JS tree. Example: `npm run tsoa && tsc && tsc-alias && tsc -p tsconfig.cronjobs.json && tsc-alias -p tsconfig.cronjobs.json`.
**Don't:** Run `tsc-alias` once with its default project after compiling additional projects. The extra projects will emit JS with literal `@/...` imports, making `dist/<project>/**` non-runnable at runtime.
**Why:** `tsc-alias` only rewrites the project it's pointed at. A multi-project build that calls `tsc-alias` only once produces silent runtime failures (`Cannot find module '@/foo'`) for the unrewritten projects — and it isn't caught by `tsc` (which resolves aliases from tsconfig, not the emitted JS).
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3113843474
**Detection:** A `build` script that invokes `tsc -p <other-tsconfig>` but does not also invoke `tsc-alias -p <other-tsconfig>` for the same project.

## Rule: Validate parsed numeric env vars (NaN, integer, range)

**Do:** When reading a numeric env var, parse and validate in one place. Reject NaN, reject non-integers if the value must be an integer, and clamp/reject out-of-range values. Prefer `Number(value)` + `Number.isInteger(...)` over `parseInt(value, 10)` when "10abc" or "10.5" must be rejected. Always provide an explicit fallback (or throw at the consumer) for invalid input.
**Don't:** Return `parseInt(process.env.FOO ?? '5', 10)` directly from a config getter. `parseInt('', 10)` is `NaN`, `parseInt('10abc', 10)` is `10`, `parseInt('-1', 10)` is `-1` — all of which downstream code will silently misuse (infinite retry loops, zero-iteration loops, division by zero).
**Why:** Numeric env vars are a classic source of silent misconfiguration. Validating once at the source means consumers can trust the value is a usable integer. `parseInt` is permissive (partial parsing, accepts trailing garbage); `Number` + `Number.isInteger` is strict.
**Example:**

```ts
static get RETRY_LIMIT(): number {
  const raw = process.env.RETRY_LIMIT;
  if (raw === undefined || raw === '') return 5;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) return 5; // or: throw at consumer
  return n;
}
```

**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21\#discussion_r3113843541
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21\#discussion_r3113982553
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21\#discussion_r3118712158
**Detection:** A bare `parseInt(process.env.FOO ?? '<default>', 10)` (or `Number(process.env.FOO)`) returned from a getter or assigned to a config field, with no `Number.isNaN` / `Number.isInteger` / range check before use.

## Rule: Run short-lived scripts and cron entrypoints with `tsx`, don't compile them

**Do:** For scripts, cron entrypoints, one-off CLI utilities, and other short-lived TypeScript that isn't part of the deployed service bundle, execute the `.ts` file directly with `tsx` (or `ts-node` if the project standardizes on it). Keep the source in the repo as `.ts` and run `tsx path/to/script.ts`.
**Don't:** Add a second tsconfig (`tsconfig.cronjobs.json`), a second build step (`tsc -p tsconfig.cronjobs.json && tsc-alias -p tsconfig.cronjobs.json`), `.gitignore` rules for emitted `.js`, jest coverage entries for the script tree, or jest exclusions for it. Each of those is friction (and one more thing reviewers have to ask about) when `tsx scripts/foo.ts` would just work.
**Why:** Compiling a one-off script multiplies build complexity (extra tsconfig, extra tsc-alias pass, extra dist tree, extra `.gitignore` rule, extra jest config) for no runtime benefit — `tsx` runs the source directly with full TypeScript type-stripping. The build complexity also creates drift: when the main tsconfig changes, the cronjobs tsconfig has to be updated in lockstep or it breaks silently.
**Example:** In `package.json`: `"retry": "tsx cronjobs/entrypoint.ts"` (no `prebuild`, no separate tsconfig, nothing in `.gitignore`, nothing extra in `jest.config.js`).
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117889110
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117899353
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117905038
**Detection:** A new `tsconfig.<name>.json` whose only purpose is to compile a `scripts/`, `cronjobs/`, `tasks/`, or similar non-deployed tree, _and_ a corresponding new build step / `.gitignore` rule for the emitted JS. Prefer `tsx <file>.ts` and delete the extra config.

## Rule: Test files live in `src/**/__tests__/` only

**Do:** Co-locate Jest tests under `src/**/__tests__/<thing>.test.ts` next to the code under test. Configure `jest.config.js` to discover tests only under `src/`.
**Don't:** Put `*.test.ts` files under `cronjobs/`, `scripts/`, `tools/`, repo root, or any other top-level tree. Don't add new `collectCoverageFrom` entries pointing at non-`src` trees.
**Why:** A single test root keeps Jest config small, keeps coverage reporting honest, and prevents a future `cronjobs/foo.test.ts` from being silently excluded by a stale jest config. If the code being tested lives elsewhere, move the unit-testable logic into `src/` and re-export it; keep the non-`src` tree thin (entrypoint only).
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3117896801
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2723154328
**Detection:** A `*.test.ts` / `*.spec.ts` file outside `src/`, or a `collectCoverageFrom` / `testMatch` / `roots` entry in `jest.config.js` referencing a non-`src` path.

## Rule: Name return-type shapes that cross module boundaries

**Do:** Define a named `interface`/`type` for any function return shape that crosses module boundaries (service ↔ controller, library ↔ caller, exported APIs). Export the type alongside the function so callers can declare matching variables and tests can mock it.
**Don't:** Return inline object types like `Promise<{ mecs: Mec[]; esls: Esl[] }>` from a service method that a controller will consume. The controller now has to either re-declare the shape (drift risk), import an unnamed inferred type, or fall back to `unknown`/`any` in its own signature.
**Why:** Inline structural types are fine for one-off callbacks; for cross-module APIs they're an anti-pattern. A named type is a single source of truth: tooling can rename across the codebase, callers get accurate IntelliSense, and reviewers can see the contract in one place.
**Example fix:** Replace `public async getLeaders(): Promise<{ mecs: Mec[]; esls: Esl[] }>` with `export interface LeadersResponse { mecs: Leader[]; esls: Leader[]; }` and `public async getLeaders(): Promise<LeadersResponse>`.
**Source:** https://github.com/cobank-acb/ama-gems-exp-api/pull/90\#discussion_r2614972911
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2818075811
**Detection:** A `public`/`export`ed function or method whose return annotation is an inline object type (`Promise<{ … }>` or `: { … }`) and whose return value is consumed by another module.

## Rule: Controller response types must match the service they delegate to

**Do:** When a controller forwards a service's response to the client, its declared response type must be the same named type the service returns. If the service returns `LeadersResponse`, the controller signature is `Promise<ApiResponse<LeadersResponse>>`. Keep the chain typed end-to-end.
**Don't:** Type a controller return as `Promise<ApiResponse<unknown>>` (or `any`) "to make TypeScript happy" while the underlying service returns a specific named type. Don't widen the response type at the boundary just because the controller layer doesn't import the service's types.
**Why:** Widening to `unknown` at the controller layer breaks generated OpenAPI/tsoa schemas, breaks client SDK generation, and hides shape mismatches. The whole point of the controller→service split is end-to-end typing; throwing it away at the seam defeats the architecture.
**Example fix:** `public async getLeaders(): Promise<ApiResponse<unknown>>` → `public async getLeaders(): Promise<ApiResponse<LeadersResponse>>`, importing `LeadersResponse` from the service module (or a shared interfaces barrel).
**Source:** https://github.com/cobank-acb/ama-gems-exp-api/pull/90#discussion_r2614971333
**Detection:** A controller method that calls `this.someService.someMethod()` and returns the result, but whose declared return type uses `unknown`/`any`/inline shape while the service's return type is a named, exported interface.

## Rule: Match assertions on object payloads with `expect.objectContaining` (or align both sides)

**Do:** When asserting on an argument that includes optional/`undefined` keys, either (a) align the test fixture exactly with the implementation's emitted shape, or (b) use a partial matcher (`expect.objectContaining({ … })`, `expect.toMatchObject(…)`). Pick one strategy per file and stick with it.
**Don't:** Write `expect(client.fetch).toHaveBeenCalledWith({ filter: { employeeId, billingYear: undefined, billingYearOp: undefined }, page, limit })` when the implementation conditionally spreads `billingYear` (so the actual key is absent, not `undefined`). The strict deep-equal fails on the `undefined` key vs missing key distinction.
**Don't:** Build the implementation to _include_ `undefined`-valued keys (`{ ...base, sortBy, sortOrder }` when both are undefined) just to make tests pass. Conditionally spread instead: `{ ...base, ...(sortBy && { sortBy }), ...(sortOrder && { sortOrder }) }`, and keep tests aligned.
**Why:** `{}` and `{ x: undefined }` are deep-equal in Jest's matcher set but not always in other contexts (JSON.stringify, network serialization). The asymmetry between "key present with undefined value" vs "key absent" is the most common cause of flaky-looking but actually-deterministic test failures, and reviewers (including AI) will flag every one.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090109
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090133
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090175
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090190
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090294
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090310
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090321
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090393
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090406
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2874090421
**Detection:** A `toHaveBeenCalledWith` / `toEqual` assertion that lists keys with `undefined` values in the expected fixture, _or_ a request-builder that always includes keys with `undefined` values rather than conditionally spreading them.

## Rule: Use library-provided enums/constants instead of magic string literals

**Do:** Import the enum/constant the library exports: `GridLogicOperator.And`, `GridLogicOperator.Or`, `StatusCodes.INTERNAL_SERVER_ERROR`, `Method.GET`. Pass those, not string literals.
**Don't:** Pass `'and'`/`'or'` as `logicOperator: 'and'` when the library exports `GridLogicOperator`. Don't hardcode `500` when `StatusCodes.INTERNAL_SERVER_ERROR` exists.
**Why:** Library-provided constants survive library version changes (the maintainer can rename the underlying value), give you autocomplete, fail at compile time when misspelled, and document intent at the call site. String literals do none of these.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63\#discussion_r2880850174
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2817662104
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2817710600
**Detection:** A string literal passed as a value where the same library exports a typed enum/constant for that field (commonly: MUI `GridLogicOperator`, `GridFilterOperator`, axios `Method`, http `StatusCodes`).

## Rule: Barrel files must not re-export the same symbol twice

**Do:** Each symbol gets exactly one re-export in a barrel `index.ts`. When you add a new `@/...`-aliased export, remove any duplicate relative re-export of the same symbol.
**Don't:** Have both `export { default as Admin } from '@/pages/Admin/Admin';` and `export { default as adminViewColumns } from './Admin.Columns';` (with another import of the same column file aliased) in the same barrel. The duplicate re-exports cause "ambiguous export" errors or, worse, silently use the wrong one.
**Why:** Duplicate barrel exports compile-but-confuse: tools may resolve to either path, refactors break unpredictably, and the file becomes a hidden source of truth for what the module exposes.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2879432119
**Detection:** A barrel `index.ts` with two `export … from` lines pointing at the same source file (or two `export { X }` lines for the same identifier).

## Rule: UI option lists must round-trip through the backend mapping

**Do:** When you expose a UI option (filter operator, dropdown value, sort field) that will be sent to the backend, ensure every option has a corresponding entry in the request-builder/mapping function. Add a unit test that iterates over the UI option list and asserts each one maps to a non-throwing API value.
**Don't:** Allow `'isAny'` in your MUI Grid `singleSelectOperators` filter when `toApiOperator()` doesn't have a case for `'isAny'`. The user will pick the option and the API call will silently send the wrong (or default) operator, returning wrong data.
**Why:** UI/API drift is invisible: the option appears in the dropdown, the user picks it, no error fires, and the results are quietly wrong. Round-trip tests catch this at PR time.
**Example fix:** Either remove `'isAny'` from the allowed operators, or add `case 'isAny': return FilterOperators.IN;` to `toApiOperator()` and a test: `for (const op of allowedOperators) expect(() => toApiOperator(op.value)).not.toThrow();`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874090365
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2807081281
**Detection:** A UI option list (filter operators, sort fields, dropdown values) defined in the same PR as a mapping function (e.g. `toApiOperator`), where the option list contains a value not handled by the mapping function.

## Rule: No `any` in tests — use real types from the SUT or library

**Do:** Type test fixtures, mock functions, and mock implementations with the real types from the system under test or the library being mocked. Import `CbDataGridProps`, `AxiosResponse<T>`, your service's `LeadersResponse`, etc. and use them in `vi.fn()` / `jest.fn()` signatures.
**Don't:** Type mock parameters as `any` because "it's just a test". `any` defeats the purpose of TypeScript exactly where it matters most — verifying that the test still compiles when the real type changes.
**Why:** A test typed with `any` will keep "passing" after the SUT's types drift, hiding broken contracts until production. Real types in tests turn type-level regressions into compile errors at PR time.
**Example fix:** Replace `vi.mock('lib', () => ({ Foo: (props: any) => …}))` with `import type { FooProps } from 'lib';` and `vi.mock('lib', () => ({ Foo: (props: FooProps) => … }))`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13#discussion_r2801465224
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13#discussion_r2801465247
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2818756952
**Detection:** `: any` (or `as any`) inside `*.test.ts`/`*.spec.ts`/`*.test.tsx` files, especially in `vi.mock`/`jest.mock` factories or `vi.fn()`/`jest.fn()` generic args.

## Rule: Check for `null`/`undefined` explicitly when `0`/`false`/`''` are valid values

**Do:** Use `value === null || value === undefined` (or `value == null` if you accept the loose-equality idiom) when guarding numeric, boolean, or string fields where the falsy values (`0`, `false`, `''`) carry meaning.
**Don't:** Use `!value` to mean "missing" for amount/count/percent/boolean fields. `!0`, `!false`, and `!''` are all true — your `valueFormatter` will render `$0.00` as blank, your conditional will treat `false` as missing, and your "is set?" check will fail for empty-but-valid strings.
**Why:** Falsy checks conflate "absent" with "zero/false/empty". For domain values like dollar amounts, retry counts, "is approved" flags, and required-but-empty inputs, the distinction matters and the bug is silent.
**Example fix:** `if (!value) return '';` → `if (value === null || value === undefined) return '';` for a currency `valueFormatter`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13\#discussion_r2801465235
**Detection:** A `!value` / `if (!foo)` / `value || default` guard where the field's type includes `number`, `boolean`, or where `''` is a meaningful value.

## Rule: Narrow union types properly — don't cast through `as` to one branch

**Do:** Narrow `string | Date` (or any union) with a runtime check before applying branch-specific APIs: `value instanceof Date ? value : new Date(value)`. For `string | number`, use `typeof value === 'string'`. For discriminated unions, switch on the discriminator.
**Don't:** Write `new Date(value as string)` when the type is `string | Date`. The cast tells the compiler to shut up, but at runtime the `Date` branch goes through the `Date(Date)` constructor — which works by coincidence today and breaks the moment the underlying value's serialization changes.
**Why:** `as` casts are an escape hatch from the type system; using them to silence a union compile error converts a type-system warning into a latent runtime bug. The fix is always a runtime check, not a cast.
**Example fix:** `valueGetter: (value: string | Date) => (value ? (value instanceof Date ? value : new Date(value)) : null)`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13\#discussion_r2801465261
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13\#discussion_r2801465272
**Detection:** `value as <one-branch-of-union>` where the source type is a union and the cast is applied so a branch-specific API can be called (`new Date(x as string)`, `(x as number).toFixed(2)`, etc.).
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58#discussion_r2818750307
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806462088
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/52#discussion_r2806593537
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772298

## Rule: Components must be exported via a barrel `index.ts`; consumers import from the barrel

**Do:** Every component folder gets an `index.ts` that re-exports its public surface. Consumers import from the folder (`import { Reimbursement } from '@/pages/Reimbursement';`), not from the deep file path.
**Don't:** Import a component from its concrete file (`@/pages/Reimbursement/Reimbursement`). Don't ship a component folder without an `index.ts`. Don't have some imports go through the barrel and others bypass it for the same component.
**Why:** Barrel files are the public API of a folder. Deep imports couple consumers to internal file layout — renaming or splitting `Reimbursement.tsx` becomes a breaking change for every consumer instead of a localized refactor.
**Example fix:** Add `src/pages/Reimbursement/index.ts` containing `export * from '@/pages/Reimbursement/Reimbursement';` (also see "Barrel exports must also use `@` aliasing"). Update consumers to `import { Reimbursement } from '@/pages/Reimbursement';`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13#discussion_r2804625682
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2722225116
**Detection:** An `import` statement whose path ends in a concrete component filename (`/Reimbursement/Reimbursement`, `/DataGrid/DataGrid`) instead of the folder. Also: a component folder with no `index.ts`.

## Rule: Match the existing export pattern within a barrel file

**Do:** Read the file you're editing and follow its existing export pattern. If the rest of the barrel uses `export * from '@/feature/x';`, your new export uses `export *`. If the file uses `export { default as Foo } from '@/feature/foo';`, follow that.
**Don't:** Mix `export *`, `export { default as X }`, and `export { X }` in the same barrel. Don't import the AI-suggested style ("named exports are best practice") and apply it to a file that consistently uses default re-exports.
**Why:** A consistent barrel is scannable and easy to extend. Mixed styles force every reviewer and AI to ask "is there a reason for the difference?" and create churn when the next person re-aligns the file.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13\#discussion_r2804617487
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/17#discussion_r2722225116
**Detection:** A barrel `index.ts` PR diff adds a re-export whose syntax (`export *` vs `export { default as X }` vs `export { X }`) differs from the surrounding lines in the same file.

## Rule: Never import from a `node_modules/...` relative path

**Do:** Import from the package name as published: `import { expressAuthentication } from '@cobank-acb/shd-api-common-lib';`. If a code generator (tsoa, openapi-typescript, etc.) emits a `node_modules/...` relative path, fix the generator config / templates so the generated import uses the package name.
**Don't:** Write `import { expressAuthentication } from '../../node_modules/@cobank-acb/shd-api-common-lib/dist/...';`. Relative `node_modules` paths bypass Node's module resolution, depend on the on-disk layout (which differs between npm/yarn/pnpm and between dev and Docker builds), and break the moment the package is hoisted differently or the file is bundled.
**Why:** Package-name imports are the supported public API. Relative `node_modules` paths reach into a package's _implementation_ — they survive on the developer's machine and crash in CI or in the production container where the layout differs. They also defeat tree-shaking and break when the package republishes with a different internal structure.
**Example fix:** If `tsoa` is generating `from '../../node_modules/@cobank-acb/shd-api-common-lib/dist/...'`, update the tsoa controller/route templates (`tsoa.json` `routes.middlewareTemplate` / `controllerPathGlobs` plus the import declaration) so the generated routes file imports from the package name. Then re-run `tsoa routes`.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-exp-api/pull/58\#discussion_r2818750291
**Detection:** Any `import` / `require` / `export from` whose path string contains `node_modules` (regardless of relative depth). Includes generated files (`src/routes/routes.ts`, `src/generated/...`).

## Rule: Component test mocks must match the real component's prop signature

**Do:** When mocking a child component (`vi.mock('./Foo', () => ({ default: ({ a, b }: any) => <div>… </div> }))`), destructure exactly the props the real `Foo` accepts. Read the real component's signature first; if you change the real component's props, update every mock that imports it in the same PR.
**Don't:** Write a mock that destructures `{ onClose, onSubmit }` when the real component only accepts `{ show, onEdit, reimbursementRequest }`. The mock will silently render with `undefined` for the props that don't exist, hiding integration bugs and producing test output that suggests events the real component never fires.
**Why:** A mock with the wrong prop signature is _worse_ than no mock — it gives false confidence that the parent ↔ child contract works. A future change to the real component's props won't break the mock, the test stays green, and the runtime breakage ships.
**Example fix:** Before mocking, copy the real component's props interface into the mock. Or: skip the mock and render the real child if it's cheap enough.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772357
**Detection:** A `vi.mock` / `jest.mock` factory function whose destructured prop names don't appear in the real component's props interface or default export signature. (Catchable via a code search: for each `vi.mock('./Foo', …)`, the mock's destructured names should be a subset of `Foo`'s declared props.)

## Rule: `vi.mock`/`jest.mock` paths must match the import path used in the SUT

**Do:** Mock the exact module specifier the system-under-test imports. If the SUT does `import { numberToMonth } from '@/utils';` (the barrel), mock `'@/utils'` — not `'@/utils/monthConversions'`, not `'../../utils/monthConversions'`. Copy the import line from the SUT into the mock factory.
**Don't:** Mock `'../../utils/reimbursementRequestlogic'` when the component under test imports from `'@/utils'`. The mock won't intercept the call (different module specifiers resolve to different module records in vitest/jest's module graph), the test still uses the real implementation, and you're left with green tests that prove nothing.
**Why:** Module mocks are keyed on the _import specifier string_, not the resolved file. Two paths that resolve to the same file (a barrel re-export and the deep path) are different keys to the mock system. A mismatched mock looks like coverage but produces zero — the worst kind of test.
**Example fix:** Read the SUT's import: `import { numberToMonth } from '@/utils';`. Mock with the same string: `vi.mock('@/utils', async () => { const actual = await vi.importActual<typeof import('@/utils')>('@/utils'); return { ...actual, numberToMonth: vi.fn() }; });`.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772406
**Detection:** A `vi.mock(path, …)` / `jest.mock(path, …)` whose `path` doesn't appear verbatim in any `import` statement of the file it tests (or of the files the SUT transitively imports). Especially: relative paths in mocks while the SUT uses `@`-aliased imports.

## Rule: Don't `new` an entity/model class to extract its keys at runtime — use the ORM's metadata API

**Do:** When you need the column/property names of an entity at runtime (for filter parsing, projection, validation, etc.), ask the ORM for them. TypeORM exposes `dataSource.getMetadata(Entity).columns.map(c => c.propertyName)` (and relation metadata for joins). Sequelize, Prisma, Drizzle, Mikro-ORM all have equivalent reflection APIs. Compute the list once at module load and cache it.
**Don't:** Write `private static readonly entra = new Entra();` and then `Object.keys(this.entra)` to discover the entity's shape. Instantiating an ORM entity outside the ORM lifecycle constructs a partial object (no DB defaults, no decorators applied at instance level, no relations loaded), wastes memory and CPU on every module load, and silently misses any field that is set via property initializer or relation rather than as a class field.
**Why:** Decorators (`@Column`, `@PrimaryGeneratedColumn`, `@ManyToOne`, etc.) are the source of truth for what the ORM considers a column. `Object.keys(new Entity())` only sees runtime-initialized fields, so optional columns, lazy relations, and default-only fields are missing — your filter parser silently rejects valid queries. The metadata API is the supported, decorator-aware way to introspect, and it's what the ORM itself uses internally.
**Example fix:** Replace `private static readonly person = new Person(); … Object.keys(PersonFilterService.person)` with `private static readonly personFields = AppDataSource.getMetadata(Person).columns.map(c => c.propertyName);` (or `dataSource.getMetadata(Person).ownColumns` if you want to exclude inherited columns).
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203\#discussion_r2991459641
**Source:** https://github.com/cobank-acb/ama-associate-api/pull/203\#discussion_r2991508429
**Detection:** Any `new <EntityName>()` outside an `ormRepository.create(...)` / `ormRepository.save(...)` / test fixture. Especially: `new SomeEntity()` followed by `Object.keys(...)` / `Reflect.ownKeys(...)` on the same instance. Equivalent in Prisma: `Object.keys(new PrismaClient().<model>.fields)` instead of using the model's `_dmmf` metadata.

## Rule: A library's public API must not leak the underlying ORM/data-source types

**Do:** When publishing a shared library that wraps a database/data source, define your own minimal interfaces/types for what consumers need to pass in (sort options, find criteria, filter shapes) and keep the underlying ORM (TypeORM, Prisma, Sequelize, Mongoose, etc.) as an internal implementation detail. Consumers should be able to depend on the library without installing the ORM, knowing it exists, or matching its version.
**Don't:** `import { FindOptionsOrder, FindManyOptions } from 'typeorm';` in a public-facing type from a shared library, list `typeorm` in `dependencies` (or worse, `peerDependencies`), or re-export ORM types from the library's barrel. Once an ORM type is on your public API, every consumer is locked to that ORM, must install a compatible version, and sees the upstream's type evolution as a breaking change.
**Why:** A shared library's job is to encapsulate the implementation. Leaking ORM types defeats the encapsulation: consumers who don't use TypeORM still pay the dependency cost; consumers who do use it must keep versions in sync to avoid duplicate installs (`typeorm@0.3.20` vs `typeorm@0.3.28` resolved twice in `node_modules`); and any backend rewrite (TypeORM → Prisma) becomes a breaking change for every consumer instead of a no-op. The right shape is a small set of library-owned interfaces that map _internally_ to the ORM.
**Example fix:** Replace `export interface PersonSortBuilder { order: FindOptionsOrder<Person>; }` with library-owned types: `export interface PersonSortOptions { field: PersonSortField; direction: 'asc' | 'desc'; }`. Inside the library's repository implementation, translate `PersonSortOptions` → `FindOptionsOrder<Person>`. Move `typeorm` from `dependencies` to a private internal dependency of the implementation package only.
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1\#discussion_r2747994704
**Source:** https://github.com/cobank-acb/ama-people-api-lib/pull/1\#discussion_r2748006233
**Detection:** A shared library's `package.json` lists an ORM (`typeorm`, `prisma`, `sequelize`, `mongoose`, `mikro-orm`) in `dependencies` or `peerDependencies`. Or: any exported type/interface from the library's `src/**/index.ts` barrel transitively imports from one of those packages. Run `tsc --traceResolution` against a library export and grep for the ORM package name.
