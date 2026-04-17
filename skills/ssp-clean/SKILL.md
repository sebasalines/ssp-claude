---
name: ssp-clean
description: Summarize and archive a completed plan. Compresses the full plan folder into a single audit-trail markdown. Manual-only — never runs automatically.
---

# SSP Clean

> 🧹 **ssp-clean** — archiving plan.

Print that line before doing anything else.

## When to use

When you're done with a plan and want to free up the folder while keeping an audit trail. **Always manual** — never auto-triggered by other skills.

## Usage

- `/ssp-clean` — list plans, pick which to archive
- `/ssp-clean <slug>` — archive a specific plan

## Workflow

### Step 1: Read the plan

Read everything in the plan folder:
- `PLAN.md` — tasks, waves, final status
- `DISCOVERY.md` — what was explored
- `DISCUSSION.md` — decisions made
- `results/*.md` — what happened per task
- `VERIFICATION.md` — pass/fail
- `LEARNINGS.md` — patterns extracted

### Step 2: Summarize

Create a single markdown that captures the full picture:

```markdown
# <Plan Title>

**Slug:** <slug>
**Type:** feat | fix | refactor | chore
**Branch:** <integration branch name>
**Created:** YYYY-MM-DD
**Completed:** YYYY-MM-DD

## Summary
<what was built — from PLAN.md summary>

## Tasks
| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | ... | completed | — |
| 2 | ... | completed | — |
| 3 | ... | failed | <brief reason> |

## Decisions
<key choices from DISCUSSION.md — D-01, D-02, etc.>

## Verification
<pass/fail summary from VERIFICATION.md>

## Commits
<list from result files>

## Learnings
<aggregated from LEARNINGS.md>
```

### Step 3: Archive

```bash
mkdir -p .planning/__archived__
```

Write the summary to `.planning/__archived__/<slug>.md`.

### Step 4: Delete the plan folder

```bash
rm -rf .planning/<slug>/
```

**Only after confirming the archive file was written.** Tell the user:

"Archived to `.planning/__archived__/<slug>.md` — full plan folder removed."
