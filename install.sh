#!/usr/bin/env bash
# Manual installer for the orchestrator plugin.
# Copies SSP skills, the ssp-executor agent, and global rules into ~/.claude/.
# For marketplace install, see README.md.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
RULES_DIR="$CLAUDE_DIR/rules"

mkdir -p "$SKILLS_DIR" "$AGENTS_DIR" "$RULES_DIR/common" "$RULES_DIR/typescript"

echo "Installing SSP skills into $SKILLS_DIR"
for skill in ssp-plan ssp-run ssp-verify ssp-learn ssp-clean ssp-update ssp-review-prs ssp-setup-worktree; do
  src="$SCRIPT_DIR/skills/$skill"
  dest="$SKILLS_DIR/$skill"
  if [[ -d "$dest" ]]; then
    echo "  ~ overwriting $skill"
    rm -rf "$dest"
  else
    echo "  + installing $skill"
  fi
  cp -r "$src" "$dest"
done

echo "Installing ssp-executor agent into $AGENTS_DIR"
cp "$SCRIPT_DIR/agents/ssp-executor.md" "$AGENTS_DIR/ssp-executor.md"

echo "Installing global rules into $RULES_DIR"
for group in common typescript; do
  src_dir="$SCRIPT_DIR/rules/$group"
  dest_dir="$RULES_DIR/$group"
  [[ -d "$src_dir" ]] || continue
  mkdir -p "$dest_dir"
  for f in "$src_dir"/*.md; do
    [[ -e "$f" ]] || continue
    name=$(basename "$f")
    if [[ -e "$dest_dir/$name" ]]; then
      echo "  ~ overwriting $group/$name"
    else
      echo "  + installing $group/$name"
    fi
    cp "$f" "$dest_dir/$name"
  done
done

echo ""
echo "Done. SSP is now available — try /ssp-plan in Claude Code."
