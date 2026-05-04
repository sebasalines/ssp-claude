---
name: ssp-plan
description: Discovery → discussion → planning. Explores the codebase, surfaces gray areas for user input, creates atomic tasks with wave-based parallelism. Use when starting any non-trivial implementation.
---

# SSP Plan

> ⚡ **ssp-plan** — starting discovery and planning.

Print that line before doing anything else.

## When to use

- Starting a feature, refactor, fix, or chore that touches multiple files
- Work that benefits from breaking into parallel tasks
- Anything where "just start coding" would mean backtracking

Don't use for single-file changes or trivial fixes — just do those directly.

## Non-negotiable rules

1. **Stay on whatever non-main branch the user put you on.** If the current branch is not `main`, the default is `branch_mode: in-place` — regardless of ahead count. A non-main branch with 0 commits ahead almost always means the user just created it to host this plan (e.g. `chore/design-tweaks` entered via `EnterWorktree`); creating another branch on top is never what they wanted. A non-main branch with 1+ commits is a sub-plan; same default. Only use `child-branch` if the user literally says "make a separate branch for this" or passes `--child-branch`.
2. **Record the branch mode in PLAN.md frontmatter.** Every PLAN.md has a `branch_mode` field. `/ssp-run` reads it verbatim — it does not re-detect, it does not second-guess. If `branch_mode: in-place`, `/ssp-run` will NOT run `git checkout -b` under any circumstance.
3. **Never push the local staging branch.** See the global rule in `~/.claude/rules/common/development-workflow.md`. The staging branch is local-only.

## Flags

- `--yolo` — skip discussion entirely. Planner makes all calls, no questions asked.
- `--child-branch` — explicit opt-in for a sub-plan to get its own child branch. Without this flag (and without the user saying "make a separate branch for this" in prose), sub-plans are always in-place.

## Workflow

### Step 0: Initialize

0. **Freshness check (mandatory first step).** See "Staying Fresh with Remote Main" in `~/.claude/rules/common/development-workflow.md`. Before anything else, run:

   ```bash
   git fetch origin main
   behind=$(git rev-list --count HEAD..origin/main)
   ahead=$(git rev-list --count origin/main..HEAD)
   staging="<staging-branch-from-memory>"
   # Fast-forward staging without checkout; tolerate failure (divergence).
   git fetch origin main:"$staging" 2>&1 | tee /tmp/ssp-staging-fetch.log
   ```

   If the worktree's branch is **behind origin/main** (`$behind > 0`), STOP. Report the drift to the user and offer to rebase the worktree onto `origin/main` before starting the plan. Do NOT proceed with discovery on a stale base — it bakes drift into every task spec.

   If the staging-branch fast-forward failed (staging has diverged from main), surface that to the user too, but don't block the plan — the staging branch is their concern, not this plan's.

   Only advance to step 1 when the worktree is even-or-ahead of `origin/main`.

0b. **Worktree symlink check.** If running inside a secondary worktree (i.e. `git rev-parse --show-toplevel` ≠ the main working tree from `git worktree list | head -1`), ensure shared state is symlinked. The cheap heuristic: `node_modules` and `__ssp__/plans` should be symlinks pointing at the main tree. If either is missing or is a real directory, run:

   ```bash
   bash ~/.claude/skills/ssp-setup-worktree/setup.sh
   ```

   This is idempotent — safe to run even when already set up. If the script reports the main tree is missing `node_modules`, stop and tell the user to `npm install` in the main tree, then re-run. Skip this step entirely when operating in the main working tree.

1. Understand what the user wants. If the request is vague, ask — don't guess intent.
2. Determine plan type: `feat` | `fix` | `refactor` | `chore`
3. Propose a name and slug: `YYYY-MM-DD-<kebab-description>`. User can rename.
4. **Resolve `branch_mode`** — this is a deterministic decision you make once and record in PLAN.md. `/ssp-run` will obey whatever you write.

   ```bash
   current=$(git rev-parse --abbrev-ref HEAD)
   ahead=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
   # Read the configured staging branch from user memory.
   # Look for a memory entry with description matching "SSP local staging branch"
   # (typically `seba-local`). If unset, prompt the user to name it and save it.
   staging="<staging-branch-from-memory>"
   echo "branch=$current ahead=$ahead staging=$staging"
   ```

   Then apply this table:

   | Current branch | Ahead of main? | User said "separate branch"? | `branch_mode` | Parent branch |
   |----------------|----------------|------------------------------|---------------|---------------|
   | `main` | — | — | `new-branch` | — |
   | `<staging>` (matches memory value) | — | — | **`new-branch` off `origin/main`** | — |
   | any other branch | any (0 or 1+) | no | **`in-place`** | current branch |
   | any other branch | any | yes (or `--child-branch` flag) | `child-branch` | current branch |

   **Defaults are load-bearing — do not ask the user "in-place vs child branch?".** The table above IS the answer. The only time the user gets a say is when they spontaneously tell you "make a separate branch for this" (or pass `--child-branch`). Otherwise, honor the table silently.

   > The previous version of this table treated "non-main, 0 commits ahead" as `new-branch`, which misfires when the user creates a topic branch (e.g. via `EnterWorktree`) specifically to host the plan. If you're on a non-main branch, the user's act of putting you there IS the opt-in to that branch — honor it.

   > **Why staging gets special-cased:** The local staging branch accumulates merged feature work for testing and is not meant to host new commits. If a user starts `/ssp-plan` while sitting on staging, treating that as `in-place` would commit feature work directly to the integration sandbox, polluting it with un-merged changes that confuse future merges. Forcing `new-branch` off `origin/main` keeps the contract: features always base off `origin/main`, never staging. See `~/.claude/rules/common/development-workflow.md` "The Local Staging Branch" for the full contract.

   Write the resolved mode + parent into PLAN.md frontmatter (see Step 3 template).
5. Create the plan folder:

```bash
mkdir -p __ssp__/plans/<slug>/tasks __ssp__/plans/<slug>/results
```

### Step 1: Discovery

Explore the codebase to map what exists and what needs to change.

**Always:**
- Read files in the affected areas (layouts, components, routes, whatever's relevant)
- Map files to create, modify, or delete
- Identify patterns to follow — naming, imports, component structure, state management
- Note risks: shared state, breaking changes, migration needs, missing tests
- **If this is a sub-plan (fixing something on an existing branch):** check if recent commits on this branch introduced the problem. Run `git log --oneline -10` and scan for commits that touch the affected files. If the bug was introduced by work on this same branch, note it in DISCOVERY.md — the fix might be a targeted revert or amendment rather than a full plan

**If needed (use judgment — don't research things you already know):**
- Context7 (`mcp__context7__resolve-library-id` → `mcp__context7__query-docs`) for unfamiliar library APIs
- Web search for docs you can't find locally
- `gh search code` for prior art

Write `DISCOVERY.md`:

```markdown
# Discovery

## Affected Area
<what part of the codebase this plan touches>

## Existing Patterns
<how similar things are done today — show code snippets with file paths, not descriptions>

## Files to Change
| Action | Path | Why |
|--------|------|-----|
| create | ... | ... |
| modify | ... | ... |

## Risks
<what could go wrong, shared state concerns, breaking change potential>
```

### Step 2: Discussion (conditional)

**Skip if:**
- The request is unambiguous and discovery gave you everything you need
- `--yolo` was passed

**Run if:**
- There are decisions that depend on what the user *wants* — UX choices, scope boundaries, trade-offs
- You're about to make an architectural call the user might disagree with

Don't stop to ask about things you can figure out from the code. Only stop for user intent.

**Use AskUserQuestion** — not a wall of text. The user wants an interactive back-and-forth, not a numbered list of 8 questions they have to address all at once. Load the tool first:

```
ToolSearch query: "select:AskUserQuestion"
```

Batch up to 4 gray areas into a single AskUserQuestion call. Each gray area becomes one question with 2-4 options. Put your recommended option first with "(Recommended)" in the label. Use the `preview` field for options that benefit from showing code snippets or layout mockups.

If there are more than 4 gray areas, batch them into multiple AskUserQuestion calls. But honestly, if you have more than 4-5 decisions, you're probably over-thinking it — make some calls yourself and only surface the ones that truly depend on user intent.

After the user responds, write `DISCUSSION.md`:

```markdown
# Discussion

## Decisions

### D-01: <name>
**Decision:** <what was chosen>
**Why:** <rationale>

### D-02: ...

## Assumptions
<things not discussed but assumed>

## Out of Scope
<explicitly deferred>
```

If discussion was skipped, still write `DISCUSSION.md` noting it was skipped and listing any assumptions.

### Step 3: Planning

Create atomic tasks. Each one either fully succeeds or fully fails, and the codebase compiles after it's done.

#### Solve, don't describe (core doctrine)

You are Opus. Executors will be Sonnet. **Do the thinking here, once, in the plan — don't punt design to execution.**

A task spec is not a to-do note. It is a pre-solved problem. The `## Implementation` block should contain the actual code (or code tight enough that a Sonnet model translates it mechanically into the listed files). The executor's job is transcription — reading your spec and writing what you already decided into the tree.

**Self-check before writing each task:** Can a Sonnet model with no broader context produce correct code from this spec alone? If you catch yourself writing "figure out how X works" or "use an appropriate pattern," stop. Go read the code, make the call, and put the answer in the spec. If the call requires user input, it belongs in Discussion, not in the task spec.

**What "solved" looks like per task:**
- Exact file paths, exact function/component signatures with types
- The actual code body (not pseudocode) wherever the logic is non-trivial
- Exact import statements, including type-only imports
- Named existing patterns to mirror, with the source file path + line reference
- All edge cases enumerated — error paths, null checks, empty states — with the handling decided
- Every decision from DISCUSSION.md that applies, quoted inline so the executor doesn't need to cross-reference

**When a task genuinely can't be fully solved at plan time** (e.g. "match the visual weight of sibling cards"): say so explicitly in the task spec. Pre-identify the exact files the executor must read, list the specific questions they must answer, and bound the scope of their judgment. Don't leave it implicit.

#### Per-task model selection

Every task spec has a `model:` field in frontmatter. You (Opus) pick it based on what the executor actually has to do. `/ssp-run` reads this field and spawns the matching model. **Default is `sonnet`** (Sonnet 4.6) — the "solve in planning" doctrine means most tasks should land here.

| Pick `sonnet` (default) when | Pick `opus` when | Pick `haiku` when |
|-------------------------------|------------------|-------------------|
| Implementation block has real code or a clearly-scoped diff | Implementation admits an unresolved design choice the executor must make ("if X, use A, otherwise use B — investigate which applies") | Pure mechanical: rename, add import, apply a fully-specified text diff, boilerplate from an explicit template |
| Task pattern-matches existing code you cited by file path | Task involves performance, concurrency, security, or algorithm decisions you couldn't finish during planning | Low blast radius — if it comes out wrong, it's trivially visible and trivially fixable |
| Edge cases are enumerated and decided | Task is a bug fix where the root cause isn't certain and the executor must diagnose | Spec is ≤ ~50 lines and the change is ≤ ~20 lines of code |
| Refactor where target pattern is named | Cross-file reasoning the planner didn't fully map (e.g. "rewire everything that imports from X") | You'd be embarrassed to spend Opus tokens on it |

**Guidance:**
- Don't pick `opus` by default — if you catch yourself wanting Opus for most tasks, it means the plan is under-specified and you should go back and finish the design instead of pushing it onto execution.
- Don't pick `haiku` unless the task is genuinely boilerplate — the retry cost of a wrong Haiku output usually exceeds the Sonnet savings.
- When in doubt, `sonnet`.
- If a task is `opus`, add a **one-line rationale** in the task spec's `## Executor Notes` section so future reviewers understand why. If a task is `haiku`, note that too.

**Task design rules:**
- Tasks touching different files → `parallel: true`
- Tasks touching the same files → sequential via `blocked_by`
- **File disjointness is load-bearing.** Parallel tasks in the same wave MUST NOT touch the same file. They run simultaneously in the same worktree — conflicts will corrupt output.
- Each task spec must include an `## Implementation` block with actual code (or the equivalent — e.g. a migration, a config diff, a schema). If you are writing prose in this section, you are not done planning.

**Wave computation:**
- Wave 1: tasks with empty `blocked_by`
- Wave 2: tasks blocked only by wave 1
- Wave N: tasks blocked only by wave N-1

Write `PLAN.md`:

```markdown
# <Title>

**Type:** feat | fix | refactor | chore
**Slug:** <slug>
**branch_mode:** in-place | new-branch | child-branch
**parent_branch:** <current branch name, or "main" for new-branch>
**createdAt:** YYYY-MM-DDTHH:MM
**updatedAt:** YYYY-MM-DDTHH:MM

## Summary
<what and why — 1-3 sentences>

## Tasks

| # | Task | Parallel | Blocked By | Status |
|---|------|----------|------------|--------|
| 1 | ... | yes | — | pending |
| 2 | ... | yes | — | pending |
| 3 | ... | no | 1, 2 | pending |

## Waves
- **Wave 1:** [1, 2] — parallel
- **Wave 2:** [3] — depends on wave 1

## File Map
| File | Tasks | Action |
|------|-------|--------|
| src/app/(design)/layout.tsx | 1 | create |
| src/components/Sidebar.tsx | 2, 3 | create, modify |
```

Write each task as `tasks/<id>-<name>.md` (zero-padded: `01`, `02`, ...):

```markdown
---
id: <number>
name: <kebab-name>
model: sonnet  # sonnet (default) | opus (unresolved design / hard reasoning) | haiku (pure mechanical)
parallel: true | false
blocked_by: []
files:
  create: []
  modify: []
  delete: []
---

## Objective
<what this delivers — 1-2 sentences>

## Context
<actual code snippets from discovery, relevant decisions from discussion — not "see DISCOVERY.md". Quote the decisions that apply to this task inline so the executor doesn't cross-reference.>

## Acceptance Criteria
- [ ] <observable outcome>
- [ ] <observable outcome>

## Implementation

<The actual solution. A Sonnet executor should be able to translate this into working code mechanically. Include:>

- **Code blocks for each file** — real code, not pseudocode, in the target language. Fences labeled with the file path:

  ```tsx
  // apps/ui/src/features/foo/Bar.tsx
  import { baz } from "@/lib/baz";
  export function Bar({ id }: { id: string }) {
    return <div>{baz(id)}</div>;
  }
  ```

- **Patch-style diffs for modifications** — show the exact lines to change, with ~3 lines of surrounding context:

  ```diff
  // apps/ui/src/features/foo/Bar.tsx
  - export function Bar({ id }: { id: string }) {
  + export function Bar({ id, variant }: { id: string; variant: "a" | "b" }) {
  ```

- **Migrations, config, schema** — full text. No "add a column for X" — write the SQL.
- **Imports** — exact module specifiers, including type-only.
- **Edge cases** — list them with the handling decided (null, empty, error, loading, auth).
- **Open questions for the executor** — only if genuinely unresolvable at plan time. Pre-identify which files they must read and what bounded judgment they need to make.

## Executor Notes
<Optional. Anything Sonnet might get wrong without a nudge: "don't add tests — they come in task 07", "this file has a .tsx twin — update both", etc.>
```

**Sanity pass before writing the plan:** re-read each task. If the Implementation section is mostly prose, go back and write the code. If you're unsure about any line, resolve it now — don't let it bleed into execution.

### Step 4: Present

Show the user:
1. Task table
2. Wave breakdown
3. File impact summary

Then: **"Run `/ssp-run` when ready."**

Do NOT start execution. Planning and execution are separate.

## Cross-references

- **Branch contract:** `~/.claude/rules/common/development-workflow.md` "The Local Staging Branch"
- **Stalled approaches during research/discovery:** `~/.claude/rules/common/escalation.md` (two-failure pivot rule)
- **Showing options to the user:** always via `AskUserQuestion`, never as plain-text numbered lists. See the Discussion section above.
