---
applyTo: "src/services/**/index.ts"
---

# Service barrel files

Applies to `src/services/**/index.ts` (per-feature barrels and the top-level `src/services/index.ts`).

## Rules

- A barrel only re-exports — no logic, no instantiation, no side effects on import.
- Use `@`-aliased paths even inside the barrel: `export { AuditBoardService } from '@/services/auditBoard/auditBoardService';`.
- Do not re-export the same symbol twice (causes ambiguous imports). One canonical export per symbol per barrel.
- Match the existing export style of the barrel (named `export { … }` here — don't mix in `export default` or `export *`).
- The top-level `src/services/index.ts` re-exports from each per-feature barrel only. Consumers import from `@/services` whenever possible.
