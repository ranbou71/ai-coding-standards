# ai-coding-standards

A personal, repo-agnostic system for teaching Copilot my coding standards. Every code-review comment becomes a permanent rule, so the same mistake never reaches a PR twice.

## How it works

1. **Rules live here** under [`/standards`](standards/), one Markdown file per topic, one `## Rule:` heading per rule.
2. **Consumer repos install this repo as a git submodule** (see [`install.sh`](install.sh)). The submodule's [`.github/copilot-instructions.md`](.github/copilot-instructions.md) and [`prompts/`](.github/prompts/) get symlinked into the consumer's `.github/`, so Copilot in any consumer repo automatically follows the rules.
3. **A reusable GitHub Action** ([`.github/workflows/ai-review.yml`](.github/workflows/ai-review.yml)) runs an AI review on every PR in the consumer repo and posts a comment listing any rule violations. It uses GitHub Models — no extra API keys.
4. **When a PR comment exposes a new mistake**, run the [`extract-rule`](.github/prompts/extract-rule.prompt.md) Copilot prompt locally to draft a new rule and open a PR against this repo. Once merged, every consumer repo gets the new rule on its next `git submodule update --remote`.

```
┌────────────────────┐    submodule + symlink    ┌──────────────────┐
│ ai-coding-standards│ ─────────────────────────▶ │  consumer repo   │
│   /standards/      │                            │  .github/...     │
│   /.github/        │ ◀──── PR adds new rule ─── │  PR comment      │
└────────────────────┘                            └──────────────────┘
           │                                              ▲
           └────── reusable ai-review.yml posts ──────────┘
```

## Set up a consumer repo

From the root of the consumer repo:

```bash
curl -fsSL https://raw.githubusercontent.com/CHANGE-ME/ai-coding-standards/main/install.sh | \
  AI_STANDARDS_REMOTE=git@github.com:CHANGE-ME/ai-coding-standards.git bash
```

This will:

- Add `ai-coding-standards` as a submodule at `.ai-standards/`.
- Symlink `.github/copilot-instructions.md` → submodule.
- Symlink `.github/prompts/` → submodule (only if it doesn't already exist).
- Symlink `standards/` at the repo root for easy reading.
- Add all install paths to `.git/info/exclude` so they stay hidden from
  `git status` and out of any commit. `.git/info/exclude` is local to the
  clone and never pushed, so the install is per-developer and invisible to
  the rest of the team.

This is a **personal install**: do not commit the submodule, symlinks, or
`.gitmodules`. Re-run the install on any new clone where you want the rules.

### Updating to the latest rules

```bash
git submodule update --remote .ai-standards
```

(no commit needed — the submodule reference is excluded locally)

## Add a new rule

When you receive a PR comment that contains a lesson:

1. Open this repo in VS Code.
2. Run the Copilot prompt [`extract-rule`](.github/prompts/extract-rule.prompt.md) and paste the comment + link.
3. Apply the proposed diff to the relevant file under [`/standards`](standards/).
4. If it's a non-negotiable, also update the quick-reference list in [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
5. Commit with the standard format (short subject, blank line, bullets) and open a PR.

## Layout

```
standards/                  # the rules — edited by humans + the extract-rule prompt
.github/
  copilot-instructions.md   # entry point Copilot reads in consumer repos
  prompts/
    extract-rule.prompt.md  # turn a PR comment into a rule
  workflows/
    ai-review.yml           # reusable AI PR-review workflow
examples/
  consumer-ai-review.yml    # drop-in workflow for consumer repos
install.sh                  # submodule + symlink installer
```

## Notes

- Replace `CHANGE-ME` in [`install.sh`](install.sh) and [`examples/consumer-ai-review.yml`](examples/consumer-ai-review.yml) with your GitHub org/user once this repo is published.
- The reusable workflow needs `models: read` permission, which is available on GitHub Models–enabled accounts. Swap the `actions/ai-inference` step for a different LLM provider if you prefer.
