---
applyTo: "src/services/**/*Service.ts"
---

# Service file pattern

Services encapsulate integration with external APIs and business logic. Each service is a class with HTTP client initialization and core methods.

## Rules

- One service class per upstream system or logical integration.
- Constructor initializes an `AxiosInstance` with baseURL and headers; throw bare `Error` if required env vars are missing.
- Use `@`-aliased imports for all internal paths (`@/config`, `@/services`, `@/types`, `@/utils`).
- Call `SecretsService.getClientSecretMapAsync()` to fetch credentials at runtime; cache aggressively to avoid repeated lookups.
- Log every API request/response at `info` or `error` level. Always spread `...loggerCommon('<service>.ts')`.
- Prefer throwing bare `Error` for startup validation (missing env vars, bad config). Production errors are caught by the top-level IIFE or middleware.
- Export the class from a barrel `index.ts` in the same directory.

## Don'ts

- Don't call `process.env` directly; always read through `AppConfig`.
- Don't store `SecretsService` results in instance fields without caching strategy — secrets are fetched on first use and cached.
- Don't mix concerns: a service handles one upstream system, not multiple unrelated APIs.
- Don't inline credentials in config; always use `SecretsService`.
