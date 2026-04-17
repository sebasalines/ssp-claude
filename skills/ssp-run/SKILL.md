---
name: ssp-run
description: Wave-based parallel execution. Spawns ssp-executor subagents, handles retries, commits, verifies, rebases onto local staging branch, kicks off code review. Use after /ssp-plan.
---

# SSP Run

> 🚀 **ssp-run** — executing plan.

Print that line before doing anything else.

## Non-negotiable rules

1. **Executors share this worktree.** No `isolation: "worktree"` on Agent calls. All subagents work here.
2. **You own git.** Executors never run git commands. You commit after collecting results.
3. **Never delete the plan folder.** Not after execution, not after merge, not ever. `/ssp-clean` is the user's call.
4. **File disjointness is the only parallel safety net.** Before spawning a wave, verify the file map — if two parallel tasks claim the same file, stop and tell the user.
5. **Local staging branch comes from memory.** Check memory for "SSP local staging branch" to find the user's configured branch name. If not found, ask the user to name their local staging branch, then save it to memory (type: `user`, description: "SSP local staging branch for merging completed plans"). Every developer has their own — never assume `main` or any default.

## Prerequisites

Load the task tracking tools before starting:

```
ToolSearch query: "select:TaskCreate,TaskUpdate,TaskGet"
```

## Workflow

### Step 0: Load Plan

Pick up the plan from conversation context. Read `PLAN.md` and all task specs from `tasks/`.

If the plan folder doesn't exist in this worktree (gitignored — normal for `claude --worktree`), ask the user for the path or have them copy it over.

### Step 1: Git Setup

**Check if this is a sub-plan** — look for `parent_branch` in PLAN.md or check if the current branch is already ahead of main:

```bash
git log main..HEAD --oneline | head -3
```

**If sub-plan (current branch has existing work):**
- **In-place mode** (default for ≤3 tasks): stay on the current branch, commit directly. No new branch.
- **Child branch mode** (for >3 tasks or when PLAN.md specifies): create a child branch FROM the current branch (not from main), execute there, then merge back into the parent:
  ```bash
  git checkout -b <type>/<slug-without-date>
  # ... execute ...
  # After completion, merge back:
  git checkout <parent-branch>
  git merge --no-ff <type>/<slug-without-date> -m "merge: <plan title>"
  git push
  ```

**If fresh plan (on main or no commits ahead):**
Create the integration branch from current HEAD:

```bash
git checkout -b <type>/<slug-without-date>
```

Type comes from PLAN.md (feat/fix/refactor/chore). Drop the date from the branch name — `feat/design-page-layout`, not `feat/2026-04-15-design-page-layout`.

Check CLAUDE.md for any project-specific branch naming rules.

### Step 2: Progress Tracking

Create tasks for the progress display — wave-level granularity:

```
☐ Wave 1: create layout, sidebar shell, chat panel (3 tasks)
☐ Wave 2: wire sidebar (1 task)
☐ Verification
☐ Merge to <staging-branch>
☐ Code review
```

One TaskCreate per line. Update with TaskUpdate as each completes.

### Step 3: Execute Waves

For each wave, in order:

#### 3a. Pre-wave checks

- Any permanently failed tasks blocking this wave? If yes, skip blocked tasks.
- Re-read task specs at execution time (user may have hand-edited between waves).
- Verify file disjointness for parallel tasks in this wave.
- **Wave promotion check (DEFAULT: ON).** Before spawning, look at the next wave's tasks. For each, check whether its file map is disjoint from *every* task in the current wave AND from every task in other intermediate waves it would pass through. If yes, *promote* it into this wave. Repeat until no more promotions are possible. This recovers from over-cautious `blocked_by` values set during planning (contract coupling that isn't actually a file-read dependency). Announce promotions to the user before spawning:
  ```
  Wave 1 was [T01]. Promoting T04 (src/App.scss — disjoint from T01's src/assets/*).
  Spawning wave 1: [T01, T04].
  ```
  Only skip promotion if a downstream task's spec depends on *reading* a file an earlier-wave task writes (not just referring to the contract).

#### 3b. Spawn executors (background, non-blocking)

**Default: spawn with `run_in_background: true`.** Foreground Agent calls block the orchestrator from responding to the user until the subagent returns — for a 90-second executor task, the user can't interject, redirect, or abort. Background Agent calls return immediately, and the orchestrator is notified automatically when each agent completes. The user stays interactive throughout.

For each task in the wave, spawn an Agent:

```
Agent(
  subagent_type: "ssp-executor",
  run_in_background: true,
  prompt: "Execute task <id> from plan <slug>.

    Plan folder: <absolute path to .planning/<slug>/>
    Task spec: <absolute path>/tasks/<id>-<name>.md

    Read before starting:
    1. CLAUDE.md (project root)
    2. <plan-folder>/DISCOVERY.md
    3. <plan-folder>/DISCUSSION.md
    4. <plan-folder>/PLAN.md
    5. Your task: <plan-folder>/tasks/<id>-<name>.md
    [if blocked_by non-empty:]
    6. Dependencies: <plan-folder>/results/<dep-id>-<dep-name>.md

    Write result to: <plan-folder>/results/<id>-<name>.md

    You share this worktree with other agents. Do NOT run any git commands."
)
```

**If the wave has multiple tasks, spawn ALL agents in a single message** — this is still how parallel execution works. With background spawning, all calls return immediately and the orchestrator can respond to the user.

After spawning, announce to the user:
```
Wave <N> spawned: [T01, T04] (background). I'm still here — ask anything. I'll commit each task as its agent reports back.
```

**Do not sleep, poll, or proactively check agent progress.** Wait for completion notifications — they arrive automatically. Between notifications, respond to user messages normally.

#### 3c. Collect results (notification-driven)

Background agent completions arrive as notifications in arrival order (not task order). Handle each as it lands:

1. Read that agent's `results/<id>-<name>.md`
2. **completed:** stage and commit that task's files immediately:
   ```bash
   git add <files from task spec>
   git commit -m "<type>: <description>"
   ```
   Per-task commits (not per-wave) keep blast radius small and let the user see incremental progress. This works because file disjointness is already enforced — parallel agents never write to the same files.
3. **failed (attempt < 3):** retry — spawn the executor again, also with `run_in_background: true`. It reads its own previous result and sees the attempt number.
4. **failed (attempt = 3):** permanently failed. Log it, keep running everything that doesn't depend on it.
5. **blocked:** treat as permanently failed.

Do not advance to the next wave until all agents in the current wave have reported. Between notifications, respond to the user — they may be asking questions, correcting direction, or wanting to abort.

#### 3d. Advance

Update the wave's progress task. Move to the next wave.

If a task is permanently failed, skip all downstream tasks that list it in `blocked_by`. Continue with everything else.

After all waves complete (or all runnable tasks are done), report status:

```
Wave results:
- Wave 1: 3/3 completed
- Wave 2: 0/1 completed (task 4 failed after 3 attempts)
- Skipped: task 5 (blocked by task 4)
```

If any tasks failed, ask the user how to proceed before continuing to verification.

### Step 4: Verify

Invoke `/ssp-verify` (use the Skill tool).

If verification fails, show the errors and offer to fix inline.

Update progress task.

### Step 5: Merge to <staging-branch>

Merge the integration branch into `<staging-branch>`:

```bash
# If <staging-branch> has diverged, rebase first
git rebase --onto <staging-branch> <merge-base> <type>/<slug>

# Merge
git checkout <staging-branch>
git merge --no-ff <type>/<slug> -m "merge: <plan title>"

# Back to integration branch (it survives for PR)
git checkout <type>/<slug>
```

*If merge conflicts:* show them to the user. Don't force-resolve.

*If rebase needed and verification already passed:* re-run verification after rebase — the rebase may have introduced issues.

Update progress task.

### Step 6: Code Review

Spawn ECC reviewers in parallel on the integration branch changes:

```
Agent(subagent_type="everything-claude-code:code-reviewer",
  prompt="Review all changes on branch <type>/<slug> vs its merge base. Focus on code quality, patterns, and correctness.")

Agent(subagent_type="everything-claude-code:security-reviewer",
  prompt="Security review all changes on branch <type>/<slug> vs its merge base.")
```

**Both in a single message** (parallel).

- **Critical/high issues → block.** Tell the user what needs fixing before PR.
- **Medium/low → advisory.** Note them, don't block.

Update progress task.

### Step 7: Learnings

Run `/ssp-learn` (Skill tool). It reads the plan artifacts + session, evaluates quality, and saves reusable patterns to the right location (global vs project `skills/learned/`).

### Step 8: Copy plan to main working tree

If running in a worktree (not the main working tree), copy the plan folder:

```bash
MAIN_TREE=$(git worktree list | head -1 | awk '{print $1}')
mkdir -p "$MAIN_TREE/.planning/"
cp -r .planning/<slug> "$MAIN_TREE/.planning/<slug>"
```

### Step 9: Summary

```
Plan: <slug>
Branch: <type>/<slug>
Tasks: X/Y completed, Z failed, W skipped
Verification: PASS / FAIL
Merged to: <staging-branch>
Review: clean / N critical, M high, P medium issues
Learnings: N patterns → LEARNINGS.md
```

Update PLAN.md:
- Set each task's Status column to `completed`, `failed`, or `skipped`
- Update the `**updatedAt:**` field to the current timestamp (`YYYY-MM-DDTHH:MM`)

**Always update `updatedAt` whenever you modify PLAN.md** — after each wave, after verification, after merge. This tracks how long a plan has been actively worked on (analytics).
