---
name: ssp-setup-worktree
description: Symlink shared project state (dependencies, generated code, plan artifacts) from the current git worktree to the main working tree. Run after creating a new worktree so tooling can reuse installed deps and plan output writes through to the main tree. Skips cleanly if already set up. Do NOT run `npm install` here — only install in the main working tree, and only when a dep error appears or package.json/lockfile changes.
---

# SSP Setup Worktree

> 🔗 **ssp-setup-worktree** — linking shared state to the main tree.

Print that line before doing anything else.

## What it does

Creates idempotent symlinks from the current worktree → the main working tree for:

**Dependencies and generated code** (expensive to rebuild per worktree):
- `node_modules/`
- `apps/ui/node_modules/`, `apps/mastra/node_modules/`, `packages/workflow-types/node_modules/`
- `apps/ui/src/generated/prisma/`
- `packages/workflow-types/dist/`
- `apps/ui/.env.local` (required for `next build`; typecheck/tests stub Prisma)

**Plan artifacts** (write-through so plans survive worktree cleanup):
- `__ssp__/plans/`

The list is spiralpegasus-specific for now. Edit `setup.sh` to adjust.

## Preconditions

- Must be invoked from inside a git worktree under `.claude/worktrees/<slug>/`.
- Refuses to run in the main working tree — nothing to link to.
- Refuses if the target path inside the worktree exists AS A REAL FILE/DIR (not a symlink). The script reports what it skipped; the user decides whether to move or delete.

## Behavior

Idempotent rules, per target path:

| Current state in worktree | Action |
|---------------------------|--------|
| symlink → correct target | skip (already linked) |
| symlink → wrong target | replace |
| broken symlink | replace |
| real file/dir, non-empty | **skip with warning** — do not clobber |
| real file/dir, empty | remove and link |
| missing | create link |

If a required target is missing in the main tree (e.g. `node_modules` not yet installed), the script warns and skips that entry — the user runs `npm install` in the main tree, then re-runs this skill.

## When to use

- After creating a new worktree via `claude --worktree`
- Auto-invoked by `/ssp-plan` Step 0 if it detects a worktree without the expected symlinks
- Any time a worktree feels "stale" — re-running is safe

## Do NOT

- **Do not run `npm install` from inside this skill.** The main working tree owns dependency state. If a dep error appears or `package.json`/`package-lock.json` changed, install in the main tree only, then re-run this skill to refresh.
- **Do not symlink git-tracked directories** (e.g. `patches/`, `apps/ui/src/`). Those diverge per branch and must live in each worktree independently.

## How to invoke

Run the script:

```bash
bash ${SSP_SETUP_WORKTREE_DIR:-~/.claude/skills/ssp-setup-worktree}/setup.sh
```

The script prints one line per target: `linked`, `already-linked`, `replaced`, `skipped (reason)`. Exit code is 0 unless the precondition check fails (e.g. running in main working tree).
