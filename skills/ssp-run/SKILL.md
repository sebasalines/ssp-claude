---
name: ssp-run
description: Wave-based parallel execution. Spawns ssp-executor subagents, handles retries, commits, verifies, pushes integration branch, kicks off code review. Use after /ssp-plan. Staging-branch operations live in /ssp-local-sync.
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
6. **NEVER push the local staging branch to remote.** The staging branch lives only on the user's machine. It is an accumulation of unmerged integration branches for local testing, not a shareable reference. `git push` only ever touches integration branches (`feat/...`, `fix/...`) or `main`. If the current branch equals the staging branch, do NOT run `git push`, `git push -u`, or `git push origin <staging>` under any circumstance — even if the user seems to ask for it, stop and confirm first. This applies everywhere in this skill: sub-plan parent merges, Step 5, Step 6, and any conflict-resolution branch you create from the staging branch.

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

**Read `branch_mode` from PLAN.md frontmatter.** This is authoritative — do NOT re-detect, do NOT second-guess, do NOT ask the user to confirm. The planner already made this call.

```bash
# Read branch_mode and parent_branch verbatim from PLAN.md frontmatter.
# Do not infer from `git log main..HEAD` — trust the file.
```

Branch into exactly one of three paths based on `branch_mode`:

**`branch_mode: in-place`** — stay on the current branch. **Do NOT run `git checkout -b`. Do NOT create any new branch.** Verify the current branch matches `parent_branch` from PLAN.md; if not, something is wrong — stop and tell the user. Otherwise, commit directly to the current branch for every task. This is the default for sub-plans and applies regardless of task count.

**`branch_mode: new-branch`** — fresh plan from main (or an empty branch). Create the integration branch from current HEAD:

```bash
git checkout -b <type>/<slug-without-date>
```

Type comes from PLAN.md (feat/fix/refactor/chore). Drop the date from the branch name — `feat/design-page-layout`, not `feat/2026-04-15-design-page-layout`. Check CLAUDE.md for any project-specific branch naming rules.

**`branch_mode: child-branch`** — rare, opt-in only (user said "make a separate branch for this" or passed `--child-branch` to `/ssp-plan`). Create a child branch FROM the current branch (not from main), execute there, then merge back into the parent:

```bash
git checkout -b <type>/<slug-without-date>
# ... execute ...
# After completion, merge back:
git checkout <parent-branch>
git merge --no-ff <type>/<slug-without-date> -m "merge: <plan title>"
# Only push if <parent-branch> is NOT the local staging branch.
# Staging branch is local-only — see non-negotiable rule #6.
if [ "<parent-branch>" != "<staging-branch>" ]; then git push; fi
```

**If PLAN.md has no `branch_mode` field** (legacy plan written before this contract existed): default to `in-place` if the current branch is ahead of main, `new-branch` otherwise. Ask the user to confirm before proceeding so legacy plans don't silently branch unexpectedly.

### Step 2: Progress Tracking

Create tasks for the progress display — wave-level granularity:

```
☐ Wave 1: create layout, sidebar shell, chat panel (3 tasks)
☐ Wave 2: wire sidebar (1 task)
☐ Verification
☐ Push integration branch
☐ Code review
```

One TaskCreate per line. Update with TaskUpdate as each completes.

### Step 3: Execute Waves

For each wave, in order:

#### 3a. Pre-wave checks

- Any permanently failed tasks blocking this wave? If yes, skip blocked tasks.
- Re-read task specs at execution time (user may have hand-edited between waves).
- Verify file disjointness for parallel tasks in this wave.

#### 3b. Spawn executors

For each task in the wave, read the task spec's `model:` frontmatter field and pass it to the Agent call. Defaults if missing: `sonnet`. Valid values: `sonnet`, `opus`, `haiku`.

The planner (Opus) chose each task's model during `/ssp-plan` using the per-task decision guide — **trust the file**. Do not override. If you think a task's model choice is wrong, that's feedback for `/ssp-learn`, not a reason to bump it up at run time.

```
Agent(
  subagent_type: "ssp-executor",
  model: "<task.model from frontmatter — default sonnet>",
  prompt: "Execute task <id> from plan <slug>.

    Plan folder: <absolute path to .claude/ssp-plans/<slug>/>
    Task spec: <absolute path>/tasks/<id>-<name>.md

    Your job is to TRANSLATE the task spec's ## Implementation block into code
    in the files listed under `files:` in the frontmatter. The spec was
    written by an Opus planner — the design is already done. Do not
    redesign, do not substitute alternate approaches, do not skip edge
    cases the spec enumerates.

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

**If the wave has multiple tasks, spawn ALL agents in a single message** — this is how parallel execution works. One task per wave = one Agent call.

**If an executor fails twice with a message like "spec contradicts the code" or "approach doesn't apply":** the plan is stale or wrong. Don't retry a third time. Stop the wave, re-read the relevant file, and either patch the task spec yourself (orchestrator is Opus — fix the design here) or tell the user the plan needs revision.

#### 3c. Collect results

After agents return:

1. Read each `results/<id>-<name>.md`
2. **completed:** stage and commit that task's files:
   ```bash
   git add <files from task spec>
   git commit -m "<type>: <description>"
   ```
3. **failed (attempt < 3):** retry — spawn the executor again. It reads its own previous result and sees the attempt number.
4. **failed (attempt = 3):** permanently failed. Log it, keep running everything that doesn't depend on it.
5. **blocked:** treat as permanently failed.

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

### Step 5: Push & Pause

Push the **integration branch** to the remote. Confirm first that the current branch is NOT the local staging branch — pushing the staging branch is forbidden (see rule #6):

```bash
# Sanity check — abort if somehow on staging
current=$(git rev-parse --abbrev-ref HEAD)
if [ "$current" = "<staging-branch>" ]; then
  echo "refusing to push staging branch"; exit 1
fi
git push -u origin <branch>
```

**Re-read git state before asking the user.** The push commit log + reflog is your last cached snapshot. Run `git log --oneline -3 && git reflog HEAD | head -5` so the next decision is grounded in current state.

Then ask the user what to do next using `AskUserQuestion`:

```
question: "Branch pushed. What next?"
options:
  - label: "Run /ssp-local-sync"
    description: "Sync seba-local from origin/main, merge this branch in, run post-merge hooks (npm install, prisma, dev server restart)"
  - label: "Create PR"
    description: "Create a GitHub PR targeting main and run code review on the PR branch"
  - label: "Stop here"
    description: "I'll test manually first — skip merge and review for now"
```

- **Run /ssp-local-sync** → invoke `Skill(skill="ssp-local-sync")` and exit `/ssp-run` (the sync skill owns the rest)

  > **Note:** picking this option **defers** Step 6 (Code Review) and Step 7 (Learnings) — they are not silently skipped, just postponed until you run "Create PR" later or invoke the reviewers manually. If you want code review feedback before merging into staging, pick "Create PR" first.

- **Create PR** → continue to Step 6 (code review), then create PR with `gh pr create --base main`
- **Stop here** → mark remaining tasks as deferred, print summary, done

**Important: re-read git state again after the user answers.** Long pauses for user input can change branch state externally — another worktree, another claude session, a manual reset, a scheduled hook. Before any branch-touching action that follows the AskUserQuestion, run `git -C <path> log --oneline -3 && git -C <path> reflog <branch> | head -5` to confirm. If a `reset: moving to ...` entry appeared between your prior interaction and now, re-derive the situation from current state — don't paste in the previously-drafted plan.

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

### Step 8: Summary

```
Plan: <slug>
Branch: <type>/<slug>
Tasks: X/Y completed, Z failed, W skipped
Verification: PASS / FAIL
Review: clean / N critical, M high, P medium issues
Learnings: N patterns → LEARNINGS.md
```

Update PLAN.md:
- Set each task's Status column to `completed`, `failed`, or `skipped`
- Update the `**updatedAt:**` field to the current timestamp (`YYYY-MM-DDTHH:MM`)

**Always update `updatedAt` whenever you modify PLAN.md** — after each wave, after verification, after merge. This tracks how long a plan has been actively worked on (analytics).
