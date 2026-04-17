#!/usr/bin/env bash
# Manual installer for the orchestrator plugin.
# Copies SSP skills and the ssp-executor agent into ~/.claude/.
# For marketplace install, see README.md.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"

mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"

echo "Installing SSP skills into $SKILLS_DIR"
for skill in ssp-plan ssp-run ssp-verify ssp-learn ssp-clean ssp-update; do
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

echo ""
echo "Done. SSP is now available — try /ssp-plan in Claude Code."
