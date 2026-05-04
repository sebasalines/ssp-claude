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
for skill in ssp-plan ssp-run ssp-verify ssp-learn ssp-clean ssp-review-prs ssp-setup-worktree ssp-local-sync ssp-setup-project; do
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

echo "Installing hooks into $CLAUDE_DIR/hooks"
HOOKS_DIR="$CLAUDE_DIR/hooks"
for hook_pkg in ssp-claude; do
  src_dir="$SCRIPT_DIR/hooks/$hook_pkg"
  [[ -d "$src_dir" ]] || continue
  dest_dir="$HOOKS_DIR/$hook_pkg"
  mkdir -p "$dest_dir"
  for f in "$src_dir"/*.sh; do
    [[ -e "$f" ]] || continue
    name=$(basename "$f")
    if [[ -e "$dest_dir/$name" ]]; then
      echo "  ~ overwriting $hook_pkg/$name"
    else
      echo "  + installing $hook_pkg/$name"
    fi
    cp "$f" "$dest_dir/$name"
    chmod +x "$dest_dir/$name"
  done
done

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

# Register the SessionStart hook in ~/.claude/settings.json (prompt-gated).
register_session_start_hook() {
  local settings="$CLAUDE_DIR/settings.json"
  local hook_command="bash $HOOKS_DIR/ssp-claude/session-start-worktree-detect.sh"

  if ! command -v jq >/dev/null 2>&1; then
    echo ""
    echo "⚠ jq not found — skipping hook registration."
    echo "  Manually add to $settings under .hooks.SessionStart:"
    echo "    {\"matcher\": \"\", \"hooks\": [{\"type\": \"command\", \"command\": \"$hook_command\"}]}"
    return 0
  fi

  # Check if already registered (matches by command substring).
  if [ -f "$settings" ] && jq -e --arg cmd "$hook_command" \
      '.hooks.SessionStart // [] | any(.hooks[]?.command == $cmd)' \
      "$settings" >/dev/null 2>&1; then
    echo "  ✓ SessionStart hook already registered in $settings"
    return 0
  fi

  # Skip prompt in non-interactive mode.
  if [ "${SSP_SKIP_HOOK_REGISTER:-}" = "1" ]; then
    echo ""
    echo "⚠ SSP_SKIP_HOOK_REGISTER=1 set — skipping hook registration."
    echo "  Manually add to $settings under .hooks.SessionStart:"
    echo "    {\"matcher\": \"\", \"hooks\": [{\"type\": \"command\", \"command\": \"$hook_command\"}]}"
    return 0
  fi

  echo ""
  echo "─────────────────────────────────────────────────────────────────"
  echo "Register the SSP worktree-detect SessionStart hook globally?"
  echo ""
  echo "  Target file: $settings"
  echo "  Hook fires once per session in fresh worktrees missing __ssp__/"
  echo "  symlinks. Injects context offering rename + setup. Skip path is"
  echo "  first-class (worktree-level skip marker)."
  echo ""
  echo "  Set SSP_SKIP_HOOK_REGISTER=1 to skip this prompt in future runs."
  echo "─────────────────────────────────────────────────────────────────"
  read -p "Add hook? [y/N] " -r reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "  Skipped. Add manually later if you change your mind."
    return 0
  fi

  # Initialize settings.json if missing.
  if [ ! -f "$settings" ]; then
    echo "{}" > "$settings"
  fi

  # Atomic merge — mktemp in same dir as target so mv is rename-atomic.
  local tmp
  tmp=$(mktemp -p "$(dirname "$settings")")
  jq --arg cmd "$hook_command" \
    '.hooks = (.hooks // {})
     | .hooks.SessionStart = (.hooks.SessionStart // [])
     | .hooks.SessionStart += [{
         "matcher": "",
         "hooks": [{ "type": "command", "command": $cmd }]
       }]' "$settings" > "$tmp" \
    && mv "$tmp" "$settings" \
    && echo "  ✓ Hook registered in $settings" \
    || { echo "  ✗ Hook registration failed; $settings unchanged"; rm -f "$tmp"; }
}

register_session_start_hook

echo ""
echo "Done. SSP is now available — try /ssp-plan in Claude Code."
