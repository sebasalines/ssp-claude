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
3. **Capture reflog before any reset.** If auto-reset is needed, write `git reflog seba-local | head -20` to `~/.claude/ssp-staging-reset-log.md` (append) so destructive operations are recoverable for ~24h.
4. **Detect tmux config opt-in via `.claude/local-sync.json`.** No tmux session is restarted unless the project has this file declaring `tmux_session` and panes.

## Prerequisites

Load tools at the start:

```
ToolSearch query: "select:AskUserQuestion,TaskCreate,TaskUpdate"
```

## Workflow

### Step 1: Detect Branches

```bash
current=$(git rev-parse --abbrev-ref HEAD)
# Read staging from user memory (description matches "SSP local staging branch")
staging="<staging-branch-from-memory>"

echo "current=$current staging=$staging"

if [ "$current" = "$staging" ]; then
  echo "ERROR: already on staging branch. Checkout the integration branch first."
  exit 1
fi
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

**If fast-forward failed** (output contains `! [rejected]` or `non-fast-forward`) → staging has diverged. Auto-recover:

```bash
# 1. Capture reflog for recovery (D-02 safeguard)
mkdir -p ~/.claude
{
  echo ""
  echo "## $(date -Iseconds) — auto-reset of $staging during /ssp-local-sync"
  git reflog "$staging" | head -20
} >> ~/.claude/ssp-staging-reset-log.md

# 2. Find the merge commits on staging since the last shared ancestor with origin/main
prev_base=$(git merge-base "$staging" origin/main)
merged_branches=$(git log --merges "$prev_base..$staging" --pretty=format:"%P %s" \
  | grep "^[a-f0-9]* [a-f0-9]* " \
  | awk '{print $2}')
# (Each merge commit's second parent is the merged-in branch tip.)

# 3. Reset staging to origin/main (destructive — reflog is the safety net)
git checkout "$staging"
git reset --hard origin/main

# 4. Replay each merged-in branch tip
for tip in $merged_branches; do
  git merge --no-ff "$tip" -m "merge: replay $(git rev-parse --short $tip) (auto-resync)" || {
    echo "Conflict during replay of $tip. Aborting auto-recover, leaving staging at origin/main + partial replay."
    echo "Manual recovery: see ~/.claude/ssp-staging-reset-log.md"
    exit 1
  }
done

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

Detect what changed between the pre-merge HEAD of staging and the new HEAD:

```bash
prev_head=$(git rev-parse "$staging@{1}")  # before the merge
changed_files=$(git diff --name-only "$prev_head" "$staging")

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

# New migration folders detected: a new file under prisma/migrations/
if echo "$changed_files" | grep -q 'prisma/migrations/.*'; then
  # Check if any of them are NEW (didn't exist in $prev_head)
  for f in $(echo "$changed_files" | grep 'prisma/migrations/'); do
    if ! git cat-file -e "$prev_head:$f" 2>/dev/null; then
      run_prisma_migrate=true
      break
    fi
  done
fi

if [ -f .claude/local-sync.json ]; then
  tmux_session=$(jq -r '.tmux_session // empty' .claude/local-sync.json)
  if [ -n "$tmux_session" ] && tmux has-session -t "$tmux_session" 2>/dev/null; then
    run_tmux_restart=true
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
  # Find each workspace with a schema and run there
  for schema in $(git diff --name-only "$prev_head" "$staging" | grep 'prisma/schema.prisma$'); do
    workspace=$(dirname "$(dirname "$schema")")
    (cd "$workspace" && npx prisma generate)
  done
fi

if $run_prisma_migrate; then
  echo "→ prisma migrate dev (new migrations detected)"
  for schema in $(find . -path ./node_modules -prune -o -name 'schema.prisma' -print 2>/dev/null); do
    workspace=$(dirname "$(dirname "$schema")")
    (cd "$workspace" && npx prisma migrate dev) || echo "migrate failed in $workspace — investigate"
  done
fi

if $run_tmux_restart; then
  echo "→ restarting tmux dev panes (session=$tmux_session)"
  # Read pane definitions and send restart keys per declared pane
  jq -c '.panes[]?' .claude/local-sync.json | while read -r pane; do
    target=$(echo "$pane" | jq -r '.target')   # e.g. "spiralpegasus:0.1"
    cmd=$(echo "$pane" | jq -r '.restart_cmd') # e.g. "C-c" then the command
    tmux send-keys -t "$target" C-c
    sleep 0.5
    tmux send-keys -t "$target" "$cmd" Enter
  done
fi
```

If any hook fails: surface the error, but don't undo the merge. The merge is committed; hook recovery is the user's call.

### Step 6: Return to Integration Branch

```bash
git checkout "$current"
```

### Step 7: Summary

Print:

```
Plan: <integration-branch>
Staging: <staging>
  - Diverged: yes/no
  - Auto-reset: yes/no
  - Branches replayed: N
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

If the file is absent, tmux restart is skipped silently. The other three hooks (npm install, prisma generate, prisma migrate) run unconditionally based on file-change detection.

## Cross-references

- **Branch contract:** `~/.claude/rules/common/development-workflow.md` "The Local Staging Branch"
- **Stalled hook recovery:** `~/.claude/rules/common/escalation.md`
