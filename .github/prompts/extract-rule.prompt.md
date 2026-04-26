# Extract Rule from PR Comment

You are helping me convert a code-review comment into a permanent rule in `ai-coding-standards`.

## Inputs I will provide

- The PR comment text.
- **Strongly preferred:** the diff the comment was left on (before/after, or just the original snippet plus the eventual fix). Resolved comments with a visible fix are the best source.
- A link to the comment (may be a private repo — that's fine, it's just provenance).
- Optionally, the project/language context (e.g. "Node service", "Terraform", "Python CLI").

## Your task

1. Identify the **single underlying lesson**. If the comment contains multiple lessons, produce multiple rules.
2. **Generalize aggressively.** The rule must apply across projects, not just the one the comment came from.
   - Strip project-specific names (`WorkivaService`, `getRecordsByType`, `customer_id`, internal repo paths, team-specific tooling).
   - Replace concrete examples with the underlying pattern (e.g. *"Don't hardcode `api.workiva.com`"* → *"Don't hardcode third-party API hostnames"*).
   - If you cannot generalize without losing meaning, the lesson is probably project-specific and does **not** belong in `ai-coding-standards` — say so and stop.
3. Decide the correct topic file under [`/standards`](../../standards/):
   - `general.md`, `git.md`, `typescript.md`, `python.md`, `security.md`, `infra.md`
   - Propose a new file only if no existing topic fits.
4. Draft the rule using exactly this template:

   ```markdown
   ## Rule: <short imperative title>

   **Do:** <what to do>
   **Don't:** <what not to do>
   **Why:** <reasoning, citing the comment>
   **Source:** <link>
   **Detection:** <regex / AST hint / reviewer cue — use the before/after diff to make this concrete>
   ```

5. Check for duplicates or near-duplicates already in the target file. If one exists, propose an **edit** (tighten wording, add a detection hint, broaden scope) instead of a new rule.
6. Output:
   - The target file path.
   - The diff to apply (new rule appended, or existing rule edited).
   - If a non-negotiable is implied, also propose updating the quick-reference list in [`/.github/copilot-instructions.md`](../copilot-instructions.md).

## Style

- Keep rules atomic, imperative, and short.
- Detection must be something a grep, linter, or reviewer can actually use. The before/after diff usually makes this easy — show the literal pattern that would have caught the original mistake.
- Never invent a source link. If I didn't give one, leave `**Source:**` blank.
- Resolved comments are valid input. The lesson doesn't expire just because the code was fixed.
