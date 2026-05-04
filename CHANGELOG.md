# Changelog

All notable changes to the ssp-claude plugin are recorded here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project is personal and unversioned — entries are grouped by date.

## 2026-05-04

### Added
- **`session-start-worktree-detect` hook (Bundle B).** New `SessionStart` hook at `hooks/ssp-claude/session-start-worktree-detect.sh`. Detects fresh worktrees missing `.__ssp__/plans` symlink and/or projects missing `.__ssp__/` in `.gitignore`, then injects onboarding context that prompts Claude to AskUserQuestion before responding to the user's first message. Three-option flow: (a) setup worktree only, (b) setup worktree + run `/ssp-setup-project`, (c) skip. Skip is first-class via `.claude/.ssp-worktree-skip` marker file. `install.sh` registers the hook in `~/.claude/settings.json` behind a confirmation prompt (overridable via `SSP_SKIP_HOOK_REGISTER=1`).
- **`ssp-setup-project` skill.** Bootstraps SSP in any consuming project: adds `.__ssp__/` to project `.gitignore`, creates/merges allow-rules in `.claude/settings.local.json` (and optionally `~/.claude/settings.json` behind a separate AskUserQuestion gate), and migrates any legacy `.claude/ssp-plans/*` content via `git mv` (or plain `mv` when the path is gitignored). Idempotent on re-run.

### Changed
- **Plan artifact path renamed** from `.claude/ssp-plans/<slug>/` to `.__ssp__/plans/<slug>/`. The new path sorts to the top of filesystem views (no clutter under `.claude/`) and signals "tooling output, not source" via the underscore-bracketed name. Updated across `ssp-plan`, `ssp-run`, `ssp-clean`, `ssp-setup-worktree`, `rules/common/git-workflow.md`, and `README.md`. Run `/ssp-setup-project` per consuming project to migrate any existing plans.
- **`.gitignore`** keeps `.claude/ssp-plans/` for back-compat with existing plans on `main` while adding `.__ssp__/` as the new canonical entry.

## 2026-05-01

### Added
- **`ssp-local-sync` skill.** Owns all local staging branch operations: fetches `origin/main`, fast-forwards `seba-local`, auto-resets+remerges if diverged (with reflog backup at `~/.claude/ssp-staging-reset-log.md`), merges the current worktree branch in, runs post-merge hooks (`npm install`, `prisma generate`, `prisma migrate dev`, optional tmux pane restart via `.claude/local-sync.json`). Allowlists `restart_cmd` against a strict regex; format-validates `tmux_session` and `target` before any tmux call; gates the destructive reset behind an explicit `AskUserQuestion`.
- **`rules/common/escalation.md`.** New global rule codifying the "two-failure pivot" pattern with concrete signals (202 polling, identical empty results, parallel-worker same-mode failures).
- **`ssp-verify` Step 5: branch-base sanity check.** Hard-fails if file count vs `origin/main` exceeds 100 OR if the branch is rooted off the staging branch instead of `origin/main`. Opt-out via `SSP_VERIFY_SKIP_DIFFSTAT=1`.
- **`/ssp-plan` decision-table row** for staging branch — when current branch matches the configured staging branch, force `branch_mode: new-branch` off `origin/main` to prevent accidental commits to the integration sandbox.
- **Global rules ported from project memory** into `rules/common/`: worktree location standard, fix-don't-instruct, explain-before-implementing (in `development-workflow.md`); commit-early-hooks-revert, never-push-planning-files, resolve-merge-conflicts-pragmatically (in `git-workflow.md`). Each section carries an `<!-- Origin: ... -->` attribution comment.
- **`.gitignore`** for ssp-claude itself — never-push-planning rule now applies to the SSP source repo too.

### Changed
- **`/ssp-run` Step 6 (Merge to staging) removed.** Staging operations are now exclusively `/ssp-local-sync`'s responsibility. Step 5 AskUserQuestion offers "Run /ssp-local-sync" instead of "Merge to staging" with explicit deferral note for code review and learnings.
- **The Local Staging Branch contract** in `rules/common/development-workflow.md` rewritten as five non-negotiable rules: features base off `origin/main`, one-way merges into staging, PRs always target `main`, fast-forward-or-reset before merging, never push staging.

### Removed
- **`ssp-update` skill.** Gist-snapshot backup retired now that `~/projects/ssp-claude` is the canonical source of truth versioned via PRs.

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
