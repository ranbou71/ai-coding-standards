---
applyTo: "src/config/AppConfig.ts"
---

# AppConfig

The single source of truth for environment variables in this repo.

## Rules

- Every env var that any service reads must be exposed here as a static getter (or property). Services consume `AppConfig.X`, never `process.env.X`.
- Defaults belong here, not in the consumer. A getter either (a) returns the env value, (b) returns a documented default, or (c) returns `undefined` and the consumer's constructor throws.
- Don't throw from a getter — let the consumer (typically a service constructor) decide whether the missing value is fatal.
- Keep getters synchronous and free of side effects (no network, no file I/O, no `SecretsService` calls). Secret material is loaded at runtime by `SecretsService`, not by `AppConfig`.
- When adding a new env var: add it here, document the expected shape in a one-line comment, and reference it from the consumer's constructor in the same PR.
