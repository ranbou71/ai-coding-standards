# Copilot Instructions

These instructions come from [`ai-coding-standards`](https://github.com/) — a personal, repo-agnostic system for capturing every code-review lesson as a permanent rule. Treat them as binding.

## How to use this file

- Every rule under [`/standards`](../standards/) applies to all code you generate or modify in this repo.
- When a rule conflicts with a request, surface the conflict; do not silently violate the rule.
- When the user reports a new mistake, propose a new rule (see [`/.github/prompts/extract-rule.prompt.md`](prompts/extract-rule.prompt.md)).

## Rule index

Read these files in full. They are short by design.

- [General](../standards/general.md)
- [Git](../standards/git.md)
- [TypeScript / JavaScript](../standards/typescript.md)
- [React](../standards/react.md)
- [Python](../standards/python.md)
- [Security](../standards/security.md)
- [Infrastructure / CI / Secrets](../standards/infra.md)

## Non-negotiables (quick reference)

- Fix problems with real solutions. Never suppress (`@ts-ignore`, `eslint-disable`, `ignoreDeprecations`, broad `except: pass`, etc.).
- Use `@` path aliasing for every import/export, including in barrel `index.ts` files.
- Never use the word "wrapper" in any identifier.
- Commit messages: short subject, blank line, detailed bullets.
- Never update AWS Secrets Manager via CLI; use the `aws-update-secret-value.yml` workflow.
- Validate untrusted input at system boundaries only — no speculative defensive code internally.
- Don't add docstrings, comments, type annotations, or refactors to code you weren't asked to change.
