---
name: ssp-local-sync
description: Sync the local staging branch (e.g. seba-local) — fetch origin/main, fast-forward or auto-reset+remerge if diverged, merge the current worktree branch in, run post-merge hooks (npm install, prisma generate/migrate, tmux dev pane restart). Run after /ssp-run pushes an integration branch, or any time you want to refresh staging with new feature work.
---

# SSP Local Sync

> 🔄 **ssp-local-sync** — syncing staging branch.

Print that line before doing anything else.

## When to use

- Right after `/ssp-run` pushes an integration branch and you want to test the combined state locally
- Any time `seba-local` falls behind `origin/main` and you want to refresh it
- Standalone: switch to a feature branch, run this skill, it merges that branch into staging

## Non-negotiable rules

1. **NEVER push the local staging branch.** It is local-only by definition. `git push` is forbidden while on staging. This skill never pushes anything.
2. **Refuse if current branch IS the staging branch.** That would mean merging staging into itself. Tell the user to checkout the integration branch first.
3. **Capture reflog before any reset.** If auto-reset is needed, write `git reflog "<staging>" | head -20` to `~/.claude/ssp-staging-reset-log.md` (append, mode 600) so destructive operations are recoverable for ~24h. `<staging>` is the user's configured branch name.
4. **Never reset without explicit user confirmation.** The auto-reset path uses `AskUserQuestion` — destructive operations always require an interactive opt-in.
5. **Detect tmux config opt-in via `.claude/local-sync.json`.** No tmux session is restarted unless the project has this file declaring `tmux_session` and panes. All values from the config file are validated against strict format regexes before use, and `restart_cmd` is allowlisted.

## Prerequisites

Load tools at the start:

```
ToolSearch query: "select:AskUserQuestion,TaskCreate,TaskUpdate"
```

## Workflow

### Step 1: Detect Branches & Capture Baseline

```bash
current=$(git rev-parse --abbrev-ref HEAD)
# Read staging from user memory (description matches "SSP local staging branch").
# ASSUMPTION: staging branch name is ASCII-only (no @, {, spaces, or shell metacharacters).
# Branch names with non-ASCII chars are not supported.
staging="<staging-branch-from-memory>"

echo "current=$current staging=$staging"

if [ "$current" = "$staging" ]; then
  echo "ERROR: already on staging branch. Checkout the integration branch first."
  exit 1
fi

# Capture pre-sync HEAD of staging — used as diff baseline in Step 5.
# Must run BEFORE any checkout/reset/merge in Steps 3 and 4.
# If staging doesn't exist locally yet, this is empty; Step 5 will use origin/main as fallback.
if git rev-parse --verify "$staging" >/dev/null 2>&1; then
  pre_sync_staging_head=$(git rev-parse "$staging")
else
  pre_sync_staging_head=""
fi
echo "pre_sync_staging_head=$pre_sync_staging_head"
```

If staging is unset in memory: prompt the user to name it via AskUserQuestion, then save it (memory type `user`, description "SSP local staging branch for merging completed plans").

### Step 2: Progress Tracking

Create progress tasks:

```
☐ Fetch origin/main
☐ Sync staging branch
☐ Merge <integration-branch> into <staging>
☐ Run post-merge hooks
☐ Return to integration branch
```

### Step 3: Fetch & Sync Staging

```bash
git fetch origin main

# Try fast-forward staging from origin/main (no checkout needed)
git fetch origin main:"$staging" 2>&1 | tee /tmp/ssp-staging-ff.log
```

**If fast-forward succeeded** → staging now matches `origin/main` plus whatever was already on staging that's still ancestor. Continue to Step 4.

**If fast-forward failed** (output contains `! [rejected]` or `non-fast-forward`) → staging has diverged. The skill must NOT auto-reset without explicit user confirmation.

#### 3a. Compute the replay set

```bash
prev_base=$(git merge-base "$staging" origin/main)

# Strict regex: full 40-char SHAs only. Excludes octopus merges (3+ parents) by requiring
# exactly two SHAs followed by a space before the subject.
captured_tips=$(git log --merges "$prev_base..$staging" --pretty=format:"%P %s" \
  | grep "^[a-f0-9]\{40\} [a-f0-9]\{40\} " \
  | awk '{print $2}')

# Octopus-merge sanity: warn if any merge commits had >2 parents (silently dropped above).
octopus_count=$(git log --merges --min-parents=3 "$prev_base..$staging" --oneline | wc -l | tr -d ' ')
if [ "$octopus_count" -gt 0 ]; then
  echo "WARNING: $octopus_count octopus merge(s) detected on staging — these will not be replayed."
fi

# Resolve each captured SHA to its current remote branch tip (HIGH-1 fix).
# If a remote branch still contains the captured SHA, use the remote tip — that's
# the up-to-date version of the merged-in work. Otherwise, fall back to the captured
# SHA (still works as a content-addressed merge target, just may be stale).
resolved_tips=""
# Use while-read (consistent with M-01/M-02) — captured_tips is well-formed hex
# SHAs by construction, but unquoted for-loop expansion is the wrong pattern.
while IFS= read -r sha; do
  [ -z "$sha" ] && continue
  # Find the most recent remote branch tip that contains this SHA.
  remote_branch=$(git branch -r --contains "$sha" 2>/dev/null \
    | grep -v 'HEAD' \
    | head -1 \
    | tr -d ' \n\r')
  if [ -n "$remote_branch" ]; then
    remote_tip=$(git rev-parse "$remote_branch")
    resolved_tips="$resolved_tips $remote_tip"
    echo "  $sha -> $remote_branch ($remote_tip)"
  else
    resolved_tips="$resolved_tips $sha"
    echo "  $sha -> (no remote branch contains; using captured SHA)"
  fi
done < <(printf '%s\n' "$captured_tips")
```

#### 3b. Confirm with user (H-02 fix)

Show the user the divergence summary and ask before any destructive action:

```
ahead_of_main=$(git rev-list --count origin/main.."$staging")
behind_main=$(git rev-list --count "$staging"..origin/main)
replay_count=$(printf '%s\n' $resolved_tips | grep -c .)

# Use AskUserQuestion (loaded in prerequisites):
#   question: "Staging has diverged from origin/main (ahead $ahead_of_main, behind $behind_main).
#              Reset $staging to origin/main and replay $replay_count merge(s)?"
#   options:
#     - label: "Auto-reset and replay (Recommended)"
#       description: "Reset $staging to origin/main, then replay $replay_count remerge(s).
#                     Reflog backed up to ~/.claude/ssp-staging-reset-log.md."
#     - label: "Abort and resolve manually"
#       description: "Stop here. Staging is left as-is. Resolve manually with git rebase or merge."
```

If the user picks "Abort": stop the skill cleanly, do NOT proceed to Step 4.

If the user picks "Auto-reset and replay": continue to 3c.

#### 3c. Capture reflog and reset (only after confirmation)

```bash
# 1. Capture reflog for recovery — write with mode 600 (no world-read on shared machines)
mkdir -p ~/.claude
(
  umask 077
  {
    echo ""
    echo "## $(date -Iseconds) — auto-reset of $staging during /ssp-local-sync"
    echo "  ahead-of-main: $ahead_of_main, behind-main: $behind_main"
    echo "  replay-tips: $resolved_tips"
    git reflog "$staging" | head -20
  } >> ~/.claude/ssp-staging-reset-log.md
)
chmod 600 ~/.claude/ssp-staging-reset-log.md 2>/dev/null || true

# 2. Reset staging to origin/main
git checkout "$staging"
git reset --hard origin/main

# 3. Replay each resolved tip — use while-read to avoid unquoted expansion.
while IFS= read -r tip; do
  [ -z "$tip" ] && continue
  git merge --no-ff "$tip" -m "merge: replay $(git rev-parse --short "$tip") (auto-resync)" || {
    echo "Conflict during replay of $tip. Aborting auto-recover; staging is at origin/main + partial replay."
    echo "Manual recovery: see ~/.claude/ssp-staging-reset-log.md"
    exit 1
  }
done < <(printf '%s\n' $resolved_tips)

# Back to the integration branch (we'll merge it next in Step 4)
git checkout "$current"
```

If conflicts surface during replay: stop, print the recovery file path, and ask the user via AskUserQuestion whether to abort, skip the conflicting branch, or resolve manually.

### Step 4: Merge Integration Branch into Staging

```bash
git checkout "$staging"
git merge --no-ff "$current" -m "merge: $current"
```

If merge conflicts: surface them. Don't force-resolve. Tell the user the staging branch is in a half-merged state and offer options: resolve manually, abort (`git merge --abort`), or skip this merge.

**Hard guard against push:**

```bash
# This skill never pushes. If anything in the user's session tries to,
# the rule from non-negotiable #1 stops it.
git config --local --unset-all branch."$staging".remote 2>/dev/null || true
git config --local --unset-all branch."$staging".merge 2>/dev/null || true
```

### Step 5: Post-Merge Hooks

Detect what changed between the pre-sync HEAD of staging and the new HEAD. Use `pre_sync_staging_head` from Step 1 — `@{1}` reflog syntax is unreliable here because Step 3 may have rewritten the reflog.

```bash
# Diff baseline: pre-sync HEAD captured in Step 1.
# If staging didn't exist before this run, fall back to origin/main.
if [ -n "$pre_sync_staging_head" ]; then
  diff_base="$pre_sync_staging_head"
else
  diff_base=$(git rev-parse origin/main)
fi
changed_files=$(git diff --name-only "$diff_base" "$staging")

run_npm_install=false
run_prisma_generate=false
run_prisma_migrate=false
run_tmux_restart=false

if echo "$changed_files" | grep -q '^package-lock.json$\|/package-lock.json$'; then
  run_npm_install=true
fi

if echo "$changed_files" | grep -q 'prisma/schema.prisma$'; then
  run_prisma_generate=true
fi

# New migration folders detected: a new file under prisma/migrations/.
# Use `while IFS= read -r` to handle filenames with spaces (M-01 sec fix).
if echo "$changed_files" | grep -q 'prisma/migrations/.*'; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! git cat-file -e "$diff_base:$f" 2>/dev/null; then
      run_prisma_migrate=true
      break
    fi
  done < <(echo "$changed_files" | grep 'prisma/migrations/')
fi

if [ -f .claude/local-sync.json ]; then
  tmux_session=$(jq -r '.tmux_session // empty' .claude/local-sync.json)
  # M-03 sec: validate tmux_session format before any tmux command.
  if [ -n "$tmux_session" ] && echo "$tmux_session" | grep -Eq '^[a-zA-Z0-9_-]+(:[0-9]+(\.[0-9]+)?)?$'; then
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
      run_tmux_restart=true
    fi
  elif [ -n "$tmux_session" ]; then
    echo "WARNING: invalid tmux_session value in .claude/local-sync.json — skipping tmux restart"
  fi
fi
```

Run the hooks that fired:

```bash
if $run_npm_install; then
  echo "→ npm install (package-lock.json changed)"
  npm install
fi

if $run_prisma_generate; then
  echo "→ prisma generate (schema.prisma changed)"
  # M-02 sec: while-read to handle paths with spaces.
  while IFS= read -r schema; do
    [ -z "$schema" ] && continue
    workspace=$(dirname "$(dirname "$schema")")
    (cd "$workspace" && npx prisma generate)
  done < <(git diff --name-only "$diff_base" "$staging" | grep 'prisma/schema.prisma$')
fi

if $run_prisma_migrate; then
  echo "→ prisma migrate dev (new migrations detected)"
  # M-02 sec: while-read for find output.
  while IFS= read -r schema; do
    [ -z "$schema" ] && continue
    workspace=$(dirname "$(dirname "$schema")")
    (cd "$workspace" && npx prisma migrate dev) || echo "migrate failed in $workspace — investigate"
  done < <(find . -path ./node_modules -prune -o -name 'schema.prisma' -print 2>/dev/null)
fi

if $run_tmux_restart; then
  echo "→ restarting tmux dev panes (session=$tmux_session)"
  # H-01 sec: allowlist restart_cmd before sending to tmux.
  # M-03 sec: validate target format too.
  cmd_allowlist='^npm (run|test) [a-zA-Z0-9 _:.@/-]+$|^npx [a-zA-Z0-9 _:.@/-]+$'
  target_regex='^[a-zA-Z0-9_-]+(:[0-9]+(\.[0-9]+)?)?$'

  jq -c '.panes[]?' .claude/local-sync.json | while read -r pane; do
    target=$(echo "$pane" | jq -r '.target')
    cmd=$(echo "$pane" | jq -r '.restart_cmd')

    if ! echo "$target" | grep -Eq "$target_regex"; then
      echo "  ⚠ skipping pane: invalid target '$target' (must match $target_regex)"
      continue
    fi
    if ! echo "$cmd" | grep -Eq "$cmd_allowlist"; then
      echo "  ⚠ skipping pane $target: restart_cmd '$cmd' not in allowlist"
      echo "    allowed: 'npm run <args>' | 'npm test <args>' | 'npx <args>' (alphanumerics, space, _:.@/-)"
      continue
    fi

    tmux send-keys -t "$target" C-c
    sleep 0.5
    tmux send-keys -t "$target" "$cmd" Enter
  done
fi
```

If any hook fails: surface the error, but don't undo the merge. The merge is committed; hook recovery is the user's call.

### Step 6: Return to Integration Branch and Summarize

```bash
git checkout "$current"
```

Print:

```
Plan: <integration-branch>
Staging: <staging>
  - Diverged: yes/no
  - Auto-reset: yes/no (user-confirmed)
  - Branches replayed: N (M octopus merges skipped)
Merged: <integration-branch> → <staging>
Hooks fired:
  - npm install: yes/no
  - prisma generate: yes/no
  - prisma migrate dev: yes/no
  - tmux restart: yes/no (session=<session>)
Now on: <integration-branch>
```

## Optional: `.claude/local-sync.json` schema

Projects opt into tmux pane restart by creating this file:

```json
{
  "tmux_session": "spiralpegasus",
  "panes": [
    { "target": "spiralpegasus:0.0", "restart_cmd": "npm run dev -w apps/mastra" },
    { "target": "spiralpegasus:0.1", "restart_cmd": "npm run dev:inngest -w apps/mastra" },
    { "target": "spiralpegasus:0.2", "restart_cmd": "npm run dev -w apps/ui" }
  ]
}
```

**Validation enforced by the skill:**

- `tmux_session` must match `^[a-zA-Z0-9_-]+(:[0-9]+(\.[0-9]+)?)?$`. Invalid values disable tmux restart.
- Each pane's `target` must match the same regex. Invalid panes are skipped with a warning.
- Each pane's `restart_cmd` must match `^npm (run|test) [a-zA-Z0-9 _:.@/-]+$|^npx [a-zA-Z0-9 _:.@/-]+$`. Commands outside the allowlist are skipped with a warning.

If the file is absent, tmux restart is skipped silently. The other three hooks (npm install, prisma generate, prisma migrate) run unconditionally based on file-change detection.

**Recommended:** add `.claude/local-sync.json` to your project's `.gitignore` if the file contains environment-specific pane targets you don't want in version control.

## Cross-references

- **Branch contract:** `~/.claude/rules/common/development-workflow.md` "The Local Staging Branch"
- **Two-failure pivot rule (when a stalled approach should be reconsidered):** `~/.claude/rules/common/escalation.md`
