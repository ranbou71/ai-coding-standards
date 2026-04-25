# Standards

Each file is a topic. Each `## Rule:` heading is one enforceable rule.

## Rule anatomy

```markdown
## Rule: <short imperative title>

**Do:** <what to do>
**Don't:** <what not to do>
**Why:** <reasoning, ideally citing the PR/comment that birthed this rule>
**Source:** <link to the PR comment, if any>
**Detection:** <pattern, regex, or AST hint a reviewer/AI can use to spot violations>
```

Keep rules atomic. If a comment yields multiple lessons, write multiple rules.

## Files

- [general.md](general.md) — language/framework-agnostic
- [git.md](git.md) — commits, branches, PRs
- [typescript.md](typescript.md)
- [python.md](python.md)
- [security.md](security.md)
- [infra.md](infra.md) — IaC, CI/CD, secrets

Add a new file when a new topic emerges. Update [/.github/copilot-instructions.md](../.github/copilot-instructions.md) so consumers pick it up.
