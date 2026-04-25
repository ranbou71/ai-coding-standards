#!/usr/bin/env bash
# Install ai-coding-standards into the current repo as a git submodule and
# symlink its rules into the consumer repo's .github/ so Copilot picks them up.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/ai-coding-standards/main/install.sh | bash
#   # or, from a clone:
#   ./install.sh [--path .ai-standards] [--remote git@github.com:<you>/ai-coding-standards.git]

set -euo pipefail

SUBMODULE_PATH=".ai-standards"
REMOTE="${AI_STANDARDS_REMOTE:-git@github.com:CHANGE-ME/ai-coding-standards.git}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) SUBMODULE_PATH="$2"; shift 2 ;;
    --remote) REMOTE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d .git ]]; then
  echo "Run this from the root of a git repo." >&2
  exit 1
fi

# 1. Add (or update) the submodule.
if [[ -d "$SUBMODULE_PATH" ]]; then
  echo "Submodule already present at $SUBMODULE_PATH; updating."
  git submodule update --init --remote -- "$SUBMODULE_PATH"
else
  git submodule add "$REMOTE" "$SUBMODULE_PATH"
  git submodule update --init --recursive
fi

mkdir -p .github

# 2. Symlink the Copilot instructions.
INSTR_LINK=".github/copilot-instructions.md"
INSTR_TARGET="../$SUBMODULE_PATH/.github/copilot-instructions.md"
if [[ -e "$INSTR_LINK" && ! -L "$INSTR_LINK" ]]; then
  echo "Refusing to overwrite existing non-symlink: $INSTR_LINK" >&2
  echo "Move it aside and re-run." >&2
  exit 1
fi
ln -sfn "$INSTR_TARGET" "$INSTR_LINK"

# 3. Symlink the prompts directory.
PROMPTS_LINK=".github/prompts"
PROMPTS_TARGET="../$SUBMODULE_PATH/.github/prompts"
if [[ -e "$PROMPTS_LINK" && ! -L "$PROMPTS_LINK" ]]; then
  echo "Note: $PROMPTS_LINK already exists and is not a symlink. Leaving it alone."
else
  ln -sfn "$PROMPTS_TARGET" "$PROMPTS_LINK"
fi

# 4. Symlink standards/ at repo root for easy reading.
STD_LINK="standards"
STD_TARGET="$SUBMODULE_PATH/standards"
if [[ -e "$STD_LINK" && ! -L "$STD_LINK" ]]; then
  echo "Note: $STD_LINK already exists and is not a symlink. Skipping."
else
  ln -sfn "$STD_TARGET" "$STD_LINK"
fi

cat <<EOF

ai-coding-standards installed.

  submodule:        $SUBMODULE_PATH
  copilot rules:    $INSTR_LINK -> $INSTR_TARGET
  prompts:          $PROMPTS_LINK -> $PROMPTS_TARGET
  standards (root): $STD_LINK -> $STD_TARGET

To pull the latest rules later:
  git submodule update --remote $SUBMODULE_PATH

Commit the new submodule and symlinks to lock the version.
EOF
