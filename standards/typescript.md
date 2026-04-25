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
