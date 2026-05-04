---
name: ssp-setup-project
description: Bootstrap SSP in this project. Adds `__ssp__/` to .gitignore, creates project-level permission allow-rules in .claude/settings.local.json (and optionally globally), and migrates any legacy .claude/ssp-plans/ content to __ssp__/plans/. Run once per project — idempotent on re-run.
---

# SSP Setup Project

> 🛠 **ssp-setup-project** — bootstrapping SSP in this project.

Print that line before doing anything else.

## When to use

- First time using SSP in a new project: get the `__ssp__/` path gitignored, get permissions set, no manual config
- After upgrading from a pre-Bundle-C SSP install: migrate existing `.claude/ssp-plans/` content
- Any time you suspect drift in `.gitignore` or `.claude/settings.local.json` allow-rules — the skill is idempotent

## Non-negotiable rules

1. **Never silently overwrite existing settings.** When updating `.claude/settings.local.json` or `~/.claude/settings.json`, merge with existing keys rather than replacing.
2. **Never run `git add` or `git commit`.** This skill mutates files; the user reviews and stages changes themselves.
3. **AskUserQuestion before any global settings.json write.** Project-level changes are low-risk; global changes affect every Claude Code session and need explicit consent.
4. **Migration is opt-in.** If the user has existing `.claude/ssp-plans/` content, ask before moving it.

## Prerequisites

Load the question tool at the start:

```
ToolSearch query: "select:AskUserQuestion"
```

## Workflow

### Step 1: Detect Current State

```bash
# Check what's already there.
has_new_path=$([ -d __ssp__ ] && echo yes || echo no)
has_legacy_path=$([ -d .claude/ssp-plans ] && echo yes || echo no)
legacy_count=0
if [ "$has_legacy_path" = "yes" ]; then
  legacy_count=$(find .claude/ssp-plans -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

has_gitignore=$([ -f .gitignore ] && echo yes || echo no)
gitignore_has_ssp="no"
if [ "$has_gitignore" = "yes" ] && grep -qE '^__ssp__/?$' .gitignore; then
  gitignore_has_ssp="yes"
fi

has_local_settings=$([ -f .claude/settings.local.json ] && echo yes || echo no)
has_global_settings=$([ -f "$HOME/.claude/settings.json" ] && echo yes || echo no)

echo "Detected state:"
echo "  __ssp__/ exists: $has_new_path"
echo "  .claude/ssp-plans/ exists: $has_legacy_path ($legacy_count plan(s))"
echo "  .gitignore exists: $has_gitignore (has __ssp__/: $gitignore_has_ssp)"
echo "  .claude/settings.local.json exists: $has_local_settings"
echo "  ~/.claude/settings.json exists: $has_global_settings"
```

### Step 2: Ask the User What to Do

Use `AskUserQuestion` to confirm which actions to take. Build the question dynamically based on detected state — only offer actions that are applicable.

```
Use AskUserQuestion (loaded in prerequisites):
  question 1: "What setup actions should I take?"
  multiSelect: true
  options:
    - label: "Add __ssp__/ to .gitignore"
      description: "(skipped if already present)"
    - label: "Migrate .claude/ssp-plans/* → __ssp__/plans/*"
      description: "Only offered if legacy_count > 0. Uses git mv if path is tracked, plain mv otherwise."
    - label: "Write project-level allow-rules to .claude/settings.local.json"
      description: "Adds Read/Write/Edit on __ssp__/** and Bash(mkdir/ls/cat:*) for the path."
    - label: "Skip everything (just report state)"
      description: "Does nothing. Useful to confirm what's missing without changing anything."
```

If "Skip everything" is selected, jump to Step 7 and print the summary without acting.

### Step 3: Update Project .gitignore

Only if the user opted in AND `gitignore_has_ssp = no`.

```bash
# Create .gitignore if missing
if [ ! -f .gitignore ]; then
  cat > .gitignore <<EOF
# SSP plan artifacts — local-only, never pushed
__ssp__/

# OS / editor noise
.DS_Store
EOF
  echo "Created .gitignore with __ssp__/ entry"
else
  # Append __ssp__/ if missing
  if ! grep -qE '^__ssp__/?$' .gitignore; then
    {
      echo ""
      echo "# SSP plan artifacts — local-only, never pushed"
      echo "__ssp__/"
    } >> .gitignore
    echo "Added __ssp__/ to existing .gitignore"
  else
    echo ".gitignore already has __ssp__/ — skipped"
  fi
fi
```

### Step 4: Migrate Legacy Plans

Only if `legacy_count > 0` AND user opted in.

```bash
mkdir -p __ssp__/plans

# Detect whether legacy path is git-tracked. If yes, use git mv to preserve history.
# If no (typical case — most projects gitignore .claude/ssp-plans/), plain mv.
is_tracked=$(git ls-files .claude/ssp-plans 2>/dev/null | head -1)

if [ -n "$is_tracked" ]; then
  echo "Migrating .claude/ssp-plans/* → __ssp__/plans/* (git mv)"
  for plan in .claude/ssp-plans/*; do
    [ -d "$plan" ] || continue
    name=$(basename "$plan")
    git mv "$plan" "__ssp__/plans/$name"
  done
else
  echo "Migrating .claude/ssp-plans/* → __ssp__/plans/* (plain mv — path is gitignored)"
  for plan in .claude/ssp-plans/*; do
    [ -d "$plan" ] || continue
    name=$(basename "$plan")
    mv "$plan" "__ssp__/plans/$name"
  done
fi

# Remove the now-empty legacy directory
rmdir .claude/ssp-plans 2>/dev/null && echo "Removed empty .claude/ssp-plans/"
```

### Step 5: Write Project Allow-Rules

Only if user opted in. Merge with existing settings rather than overwriting.

```bash
mkdir -p .claude
settings_file=.claude/settings.local.json

# Permissions to add — keep minimal, only what SSP needs without prompts.
# This list matches what /ssp-plan, /ssp-run, /ssp-verify, /ssp-clean, /ssp-learn use.
new_perms=(
  "Read(__ssp__/**)"
  "Write(__ssp__/**)"
  "Edit(__ssp__/**)"
  "Bash(mkdir:__ssp__/*)"
  "Bash(ls:__ssp__/*)"
  "Bash(cat:__ssp__/*)"
  "Bash(rm:__ssp__/*)"
)

if [ ! -f "$settings_file" ]; then
  # Create fresh
  cat > "$settings_file" <<EOF
{
  "permissions": {
    "allow": [
$(printf '      "%s",\n' "${new_perms[@]}" | sed '$ s/,$//')
    ]
  }
}
EOF
  echo "Created $settings_file with __ssp__/ allow-rules"
else
  # Merge with existing — use jq to add missing entries to permissions.allow without dups.
  for perm in "${new_perms[@]}"; do
    # Add only if not already present.
    if ! jq -e --arg p "$perm" '.permissions.allow // [] | index($p)' "$settings_file" >/dev/null 2>&1; then
      tmp=$(mktemp)
      jq --arg p "$perm" '.permissions = (.permissions // {}) | .permissions.allow = ((.permissions.allow // []) + [$p])' "$settings_file" > "$tmp"
      mv "$tmp" "$settings_file"
    fi
  done
  echo "Merged __ssp__/ allow-rules into $settings_file (existing rules preserved)"
fi
```

### Step 6: Optional — Update Global `~/.claude/settings.json`

This is invasive — it affects every Claude Code session. Always ask first.

```
Use AskUserQuestion separately (do NOT batch with Step 2):
  question: "Also add __ssp__/ allow-rules to your global ~/.claude/settings.json? This affects every project on your machine."
  options:
    - label: "Yes, add globally (Recommended for personal machines)"
      description: "Future projects with __ssp__/ won't prompt for permissions. Trades isolation for convenience."
    - label: "No, project-level only"
      description: "Each project still needs its own .claude/settings.local.json. More explicit, less convenient."
```

If yes, apply the same merge logic as Step 5 but against `$HOME/.claude/settings.json`.

```bash
global_settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [ ! -f "$global_settings" ]; then
  cat > "$global_settings" <<EOF
{
  "permissions": {
    "allow": [
$(printf '      "%s",\n' "${new_perms[@]}" | sed '$ s/,$//')
    ]
  }
}
EOF
  echo "Created $global_settings with __ssp__/ allow-rules"
else
  for perm in "${new_perms[@]}"; do
    if ! jq -e --arg p "$perm" '.permissions.allow // [] | index($p)' "$global_settings" >/dev/null 2>&1; then
      tmp=$(mktemp)
      jq --arg p "$perm" '.permissions = (.permissions // {}) | .permissions.allow = ((.permissions.allow // []) + [$p])' "$global_settings" > "$tmp"
      mv "$tmp" "$global_settings"
    fi
  done
  echo "Merged __ssp__/ allow-rules into $global_settings"
fi
```

### Step 7: Summary

Print a recap of every action taken — and every skipped action — so the user has a complete record:

```
SSP setup complete.

Actions taken:
  ✓ .gitignore: <added __ssp__/  |  already present  |  not modified per user choice>
  ✓ Plans migrated: <N moved from .claude/ssp-plans/ to __ssp__/plans/  |  none to migrate>
  ✓ .claude/settings.local.json: <created  |  merged N new rules  |  not modified per user choice>
  ✓ ~/.claude/settings.json: <merged N new rules  |  not modified per user choice>

Next steps:
  1. Review the changes — run `git status` and `git diff`.
  2. Stage and commit when ready.
  3. Run `/ssp-plan` to create your first plan in this project.
```

## Cross-references

- **Branch contract:** `~/.claude/rules/common/development-workflow.md` "The Local Staging Branch"
- **Why __ssp__/ over .claude/ssp-plans/:** see `README.md` "Plan artifacts" section
- **Two-failure pivot rule (when a stalled approach should be reconsidered):** `~/.claude/rules/common/escalation.md`
