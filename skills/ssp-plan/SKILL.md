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

## Flags

- `--yolo` — skip discussion entirely. Planner makes all calls, no questions asked.

## Workflow

### Step 0: Initialize

1. Understand what the user wants. If the request is vague, ask — don't guess intent.
2. Determine plan type: `feat` | `fix` | `refactor` | `chore`
3. Propose a name and slug: `YYYY-MM-DD-<kebab-description>`. User can rename.
4. **Detect branch context** — check if the current branch is already ahead of main:
   ```bash
   git log main..HEAD --oneline | head -5
   ```
   - **If on main (or no commits ahead):** this is a fresh plan. `/ssp-run` will create a new branch.
   - **If on a feature branch with existing commits:** this is a **sub-plan** — focused work within an existing branch's scope. Note the parent branch in PLAN.md. `/ssp-run` should either:
     - **Work in-place** on the current branch (default for small sub-plans)
     - **Create a child branch** and merge back (for larger sub-plans that need isolation)
   - Ask the user which approach they prefer, or infer from plan size (≤3 tasks → in-place, >3 tasks → child branch).
5. Create the plan folder:

```bash
mkdir -p .planning/<slug>/tasks .planning/<slug>/results
```

### Step 1: Discovery

Explore the codebase to map what exists and what needs to change.

**Always:**
- Read files in the affected areas (layouts, components, routes, whatever's relevant)
- Map files to create, modify, or delete
- Identify patterns to follow — naming, imports, component structure, state management
- Note risks: shared state, breaking changes, migration needs, missing tests

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

**Task design rules:**
- Tasks touching different files → `parallel: true`
- Tasks touching the same files → sequential via `blocked_by`
- **File disjointness is load-bearing.** Parallel tasks in the same wave MUST NOT touch the same file. They run simultaneously in the same worktree — conflicts will corrupt output.
- **`blocked_by` is for file-read dependencies, not contract coupling.** Only set `blocked_by: [X]` when task Y *reads* a file that task X *writes*. If Y only needs to know X's output contract (a renamed export, a new class name, a chosen ID), that contract lives in both task specs — Y and X are still file-disjoint and belong in the same wave. The executor reads the task spec, not the sibling's result file.
  - ✅ Task 2 *imports from* `src/feature/NewComponent.tsx` that task 1 creates → `blocked_by: [1]`
  - ❌ Task 2 *renders* `<NewComponent />` (name specified in both specs) without importing a file task 1 touches → no `blocked_by`
- Every task needs a concrete **Approach** section — specific enough for a subagent to execute cold with zero conversation context. Include file paths, function names, code patterns.

**Wave computation:**
- Wave 1: tasks with empty `blocked_by`
- Wave 2: tasks blocked only by wave 1
- Wave N: tasks blocked only by wave N-1

Write `PLAN.md`:

```markdown
# <Title>

**Type:** feat | fix | refactor | chore
**Slug:** <slug>
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
<actual code snippets from discovery, relevant decisions from discussion — not "see DISCOVERY.md">

## Acceptance Criteria
- [ ] <observable outcome>
- [ ] <observable outcome>

## Approach
<step-by-step: file paths, function signatures, which patterns to follow, what to import>
```

### Step 4: Present

Show the user:
1. Task table
2. Wave breakdown
3. File impact summary

Then: **"Run `/ssp-run` when ready."**

Do NOT start execution. Planning and execution are separate.
