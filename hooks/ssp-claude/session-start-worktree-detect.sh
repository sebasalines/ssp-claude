#!/usr/bin/env bash
# SSP SessionStart hook — detects fresh worktrees missing setup, injects
# onboarding context for Claude's first response.
#
# Behavior:
#   - Runs only on session "startup" (not resume/clear/compact).
#   - No-op outside git worktrees, in the main checkout, or when setup is done.
#   - Outputs a JSON envelope on stdout that Claude Code injects as session
#     context. Claude sees the directive and AskUserQuestions on the user's
#     first message.
#   - Honors a per-worktree "skip" marker so the user can dismiss permanently.

set +e  # Do NOT use set -e — hook must never crash the session.

# 1. Read stdin JSON. Tolerate jq missing (degrade silently) — don't block session.
input=""
if command -v jq >/dev/null 2>&1; then
  input=$(cat 2>/dev/null)
  source_kind=$(echo "$input" | jq -r '.source // "unknown"' 2>/dev/null)
else
  # No jq — read stdin to drain the pipe but skip parsing.
  cat >/dev/null 2>&1
  source_kind="unknown"
fi

# Only run on fresh sessions. Resume/clear/compact = no-op.
[ "$source_kind" != "startup" ] && exit 0

# 2. Are we in a git repo?
git_top=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$git_top" ] && exit 0

# 3. Are we in a worktree (not the main checkout)?
# git worktree list outputs the main checkout first; compare paths.
main_top=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
[ -z "$main_top" ] && exit 0
[ "$git_top" = "$main_top" ] && exit 0

# 4. Skip marker — if the user previously dismissed setup for this worktree,
#    don't re-prompt every session.
skip_marker="$git_top/.claude/.ssp-worktree-skip"
[ -f "$skip_marker" ] && exit 0

# 5. Detect what's missing.
needs_worktree_setup="no"
needs_project_setup="no"

# Worktree symlink check.
if [ ! -L "$git_top/__ssp__/plans" ] && [ ! -L "$git_top/__ssp__" ]; then
  needs_worktree_setup="yes"
fi

# Project setup check (only meaningful if we're in a fresh worktree — but the
# project-level state is inherited from main, so check the main checkout).
gitignore="$main_top/.gitignore"
if [ -f "$gitignore" ]; then
  if ! grep -qE '^__ssp__/?$' "$gitignore"; then
    needs_project_setup="yes"
  fi
else
  needs_project_setup="yes"
fi

# If nothing's missing, nothing to do.
[ "$needs_worktree_setup" = "no" ] && [ "$needs_project_setup" = "no" ] && exit 0

# 6. Gather context for the directive.
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
worktree_dir=$(basename "$git_top")

# 7. Build the directive. Use a heredoc so the prose is readable in source.
#    The directive is injected verbatim into Claude's context.
directive=$(cat <<EOF
# Fresh worktree detected — onboarding offer

You're starting in a git worktree at \`$git_top\` on branch \`$current_branch\`.
Setup is incomplete:

EOF
)

if [ "$needs_worktree_setup" = "yes" ]; then
  directive+=$'\n'"- **Worktree symlinks missing:** \`__ssp__/plans\` is not symlinked to the main checkout. Plan artifacts written here will not survive worktree cleanup."
fi

if [ "$needs_project_setup" = "yes" ]; then
  directive+=$'\n'"- **Project not bootstrapped:** \`__ssp__/\` is not in the project's \`.gitignore\` and \`.claude/settings.local.json\` likely lacks SSP allow-rules."
fi

directive+=$'\n\n'"## Required first action

Before responding to the user's actual request, use \`AskUserQuestion\` (load it via ToolSearch first) to ask:

> Setup options for this worktree?

With these three options:

1. **Setup worktree only** — rename branch from \`$current_branch\` to a meaningful name (ask the user for a slug like \`feat/foo\` or \`chore/bar\` based on what they say they're working on), run \`/ssp-setup-worktree\`, print a one-line \`mv\` command for the user to rename the directory \`$worktree_dir\` after the session ends.
2. **Setup worktree + run /ssp-setup-project** — same as #1, plus run \`/ssp-setup-project\` first to bootstrap \`__ssp__/\` in the project gitignore + settings allow-rules. Recommended if this is the first SSP-using session in this project."

if [ "$needs_project_setup" = "no" ]; then
  # Project is already set up; option 2 is irrelevant.
  directive=${directive//"2. **Setup worktree + run \/ssp-setup-project**"*"in this project."*/}
fi

directive+=$'\n'"3. **Skip — proceed with my actual request as-is.** No rename, no setup. The user can run \`/ssp-setup-worktree\` manually later if they change their mind. **If the user picks this, immediately write \`$skip_marker\` (touch it) so this prompt does not fire on future sessions in this worktree.**

After they choose, proceed accordingly. If they pick option 1 or 2, do the rename + setup BEFORE addressing whatever they originally typed. Carry their original message forward — don't drop it.
"

# 8. Emit JSON envelope. hookSpecificOutput.additionalContext is the structured
#    way to inject context per Claude Code's hook contract. Use jq to escape
#    the directive properly.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$directive" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  # Fallback: emit plain text. The existing project-rules-loader hook in the
  # user's ~/.claude/settings.json uses this pattern and it works.
  echo "$directive"
fi

exit 0
