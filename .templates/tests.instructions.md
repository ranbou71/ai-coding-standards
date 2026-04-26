---
applyTo: "src/**/__tests__/**/*.test.ts"
---

# Test file pattern

Unit tests live in a sibling `__tests__/` folder. All tests use Jest with mocks for external dependencies.

## Rules

- Test file location: `src/<feature>/__tests__/<feature>.test.ts` (alongside source, never in same folder).
- Use `@`-aliased imports matching the test's Subject Under Test (SUT).
- Mock external dependencies via `jest.mock()`: axios, SecretsService, logger, loggerCommon, date/time functions.
- Structure: `describe` (suite) → `describe` (feature) → `it` (assertion). One logical assertion per `it` block.
- Use `.toHaveBeenCalledWith()` to verify mock calls; avoid over-specified matchers that make tests brittle.
- Mock data should be realistic (copy-paste from actual API responses when possible).
- Clean up mocks in `beforeEach()` / `afterEach()` to avoid test pollution.

## Don'ts

- Don't put test files in the same folder as the SUT.
- Don't mock the SUT itself — mock only external dependencies.
- Don't test implementation details (private methods, internal state). Test behavior.
- Don't use hardcoded dates; mock `Date.now()` or pass time as a constructor parameter.
- Don't commit `.only` or `.skip` on `it` or `describe` blocks.
