# Extract Rule from PR Comment

You are helping me convert a code-review comment into a permanent rule in `ai-coding-standards`.

## Inputs I will provide

- The PR comment text (and optionally the diff/context it was on).
- A link to the comment.

## Your task

1. Identify the **single underlying lesson**. If the comment contains multiple lessons, produce multiple rules.
2. Decide the correct topic file under [`/standards`](../../standards/):
   - `general.md`, `git.md`, `typescript.md`, `python.md`, `security.md`, `infra.md`
   - Propose a new file only if no existing topic fits.
3. Draft the rule using exactly this template:

   ```markdown
   ## Rule: <short imperative title>

   **Do:** <what to do>
   **Don't:** <what not to do>
   **Why:** <reasoning, citing the comment>
   **Source:** <link>
   **Detection:** <regex / AST hint / reviewer cue>
   ```

4. Check for duplicates or near-duplicates already in the target file. If one exists, propose an **edit** instead of a new rule.
5. Output:
   - The target file path.
   - The diff to apply (new rule appended, or existing rule edited).
   - If a non-negotiable is implied, also propose updating the quick-reference list in [`/.github/copilot-instructions.md`](../copilot-instructions.md).

## Style

- Keep rules atomic, imperative, and short.
- Detection must be something a grep, linter, or reviewer can actually use.
- Never invent a source link. If I didn't give one, leave `**Source:**` blank.
