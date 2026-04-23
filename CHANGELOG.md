# Changelog

All notable changes to the ssp-claude plugin are recorded here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project is personal and unversioned — entries are grouped by date.

## 2026-04-23

### Added
- **`ssp-setup-worktree` skill.** Symlinks shared project state — `node_modules`, generated code (`apps/ui/src/generated/prisma`, `packages/workflow-types/dist`), `apps/ui/.env.local`, and `.claude/ssp-plans` — from a secondary worktree to the main working tree. Idempotent, safe to re-run. Deliberately does not run `npm install`; dependency installs happen in the main tree only.
- **`ssp-plan` Step 0b.** Auto-detects when running inside a secondary worktree and invokes `ssp-setup-worktree` if the expected symlinks are missing.
- **`ssp-review-prs` skill.** Scans for PRs assigned or with review requested and spawns background reviews via `claude -p` (max 2 concurrent). Designed to be paired with `/loop` for continuous monitoring.
- **Global rules** shipped with the plugin: `rules/common/` (12 files) and `rules/typescript/` (4 files). Installed into `~/.claude/rules/`. Project-specific rules are deliberately not shipped — those stay local per machine.
- **`CHANGELOG.md`**.

### Changed
- **Plan artifact directory renamed** from `.planning/<slug>/` to `.claude/ssp-plans/<slug>/` across `ssp-plan`, `ssp-run`, `ssp-clean`, `ssp-update`. The old path collided with other tooling and wasn't namespaced to SSP. Consumers should add `.claude/ssp-plans/` to their project `.gitignore`.
- **`ssp-run`:**
  - Removed Step 8 (copy-plan-to-main-tree). The new worktree symlink makes the copy-back redundant — the worktree's `.claude/ssp-plans` *is* the main tree's.
  - Reads `branch_mode` from PLAN.md frontmatter verbatim instead of re-detecting; planner (Opus) is authoritative.
  - Three-mode branching: `in-place` (default for sub-plans), `new-branch` (fresh from main), `child-branch` (explicit opt-in).
  - Per-task `model:` frontmatter is passed to the executor spawn.
  - Hard prohibition on pushing the local staging branch.
  - Executors spawn synchronously (reverted from background spawn after usability issues with wave sequencing).
- **`ssp-plan`:**
  - New "Non-negotiable rules" section at the top.
  - `--child-branch` flag for explicit opt-in to a child branch on sub-plans.
  - Mandatory Step 0 freshness check against `origin/main` — stop and report if the worktree is behind.
  - `branch_mode` decision table replaces the previous ask-the-user dialog.
  - "Solve, don't describe" doctrine block — tasks must be pre-solved at plan time, not punted to execution.
- **`install.sh`:** new rules-install loop; skill list updated (now 8 skills).
- **README:** adds rules section, `ssp-setup-worktree` and `ssp-review-prs` rows, `.claude/ssp-plans/` path note.

## 2026-04-15 (initial)

### Added
- Initial plugin with 6 skills (`ssp-plan`, `ssp-run`, `ssp-verify`, `ssp-learn`, `ssp-clean`, `ssp-update`) and the `ssp-executor` agent.
- `install.sh` for manual install into `~/.claude/`.
- Marketplace manifest (`.claude-plugin/{plugin,marketplace}.json`).
- README, MIT license.

### Renamed
- Plugin name: `ssp` → `ssp-claude` (match repo name).
