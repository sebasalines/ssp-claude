# Development Workflow

> Extends [git-workflow.md](./git-workflow.md) with the full development process.

## Typical Session Flow

1. Open `claude --worktree` (isolated from your local staging branch)
2. `/ssp-plan` — discovery, discussion, atomic task planning
3. Review plan, tweak task specs if needed
4. `/ssp-run` — parallel execution, verification, code review, push integration branch
5. `/ssp-local-sync` — sync `seba-local` from `origin/main`, merge integration branch in, run post-merge hooks (deps, migrations, dev-server restart)
6. Test locally on your staging branch
7. Create PR (target `main`)
8. `/ssp-clean` when done

For trivial changes (single file, obvious fix), skip SSP and work directly.

## Research & Reuse (mandatory before new implementation)

Before writing anything new — whether inside SSP discovery or standalone:

1. **GitHub code search first:** `gh search repos` and `gh search code` for existing implementations
2. **Library docs second:** Context7 or primary vendor docs to confirm API behavior
3. **Exa only when the first two are insufficient:** broader web research
4. **Check package registries:** npm, PyPI, crates.io before writing utility code
5. **Search for adaptable implementations:** open-source that solves 80%+ of the problem

Prefer adopting a proven approach over writing net-new code.

## The Local Staging Branch

Every developer maintains a personal staging branch (e.g., `seba-local`) that serves as a local-only integration sandbox for testing combined feature work before any of it ships. This is configured per-user in Claude Code memory — check memory for "SSP local staging branch."

```
main (shared, what ships)
  └── seba-local (personal, local testing — NEVER pushed)
        ├── feat/design-chat-sidebar (merged after verification)
        ├── fix/auth-redirect (merged after verification)
        └── ... (test the combined result locally)
```

**The contract** — these rules are non-negotiable:

1. **Every feature/fix branch bases off `origin/main`.** Never base a feature branch off `seba-local`. If you're sitting on `seba-local` when you start a new branch, `git fetch origin main && git checkout -b feat/foo origin/main` — never `git checkout -b feat/foo` (which would inherit staging's accumulated state).
2. **Merges are one-way: features → `seba-local`.** `seba-local` never merges back into `main` and never merges back into a feature branch. The staging branch exists only to combine in-flight work for local testing.
3. **PRs always target `main`, never `seba-local`.** `seba-local` has no remote counterpart and no PR can target it.
4. **Before any merge into `seba-local`: fast-forward from `origin/main` first.** If staging cannot fast-forward (it has diverged), reset to `origin/main` and re-merge the accumulated feature branches. `/ssp-local-sync` does this automatically.
5. **NEVER push the local staging branch to remote.** Hard rule everywhere — SSP, standalone work, manual git commands. The staging branch is local-only by definition. `git push` only ever touches integration branches (`feat/...`, `fix/...`) or `main`. Before any `git push`, verify the current branch is not the configured staging branch. If the user asks to push it, stop and confirm — they almost certainly meant the integration branch.

**Workflow**: use `/ssp-local-sync` to merge a feature branch into `seba-local`. It fetches `origin/main`, syncs staging (auto-resets if diverged), merges the current worktree branch in, and runs post-merge hooks (`npm install`, `prisma generate`, `prisma migrate dev`, tmux pane restart).

## Staying Fresh with Remote Main

Both the local staging branch AND any worktree you're about to plan in must be up-to-date with `origin/main` before a new SSP plan starts. Stale starting points cause merge hell at the end — cheap to fix at plan time, expensive to fix during Step 6.

**`/ssp-plan` runs this freshness check automatically at the start of Step 0.** Other SSP skills (`/ssp-run`, `/ssp-verify`) trust that `/ssp-plan` already did it and don't re-check.

```bash
# 1. Fetch remote main (works from any branch/worktree).
git fetch origin main

# 2. Is the current worktree's branch ahead, behind, or diverged from origin/main?
behind=$(git rev-list --count HEAD..origin/main)
ahead=$(git rev-list --count origin/main..HEAD)
echo "worktree branch: ahead=$ahead behind=$behind"

# 3. Fetch-and-fast-forward the local staging branch without switching to it.
git fetch origin main:<staging-branch> 2>/dev/null || true
# If that fails (staging-branch has diverged from main), surface it — don't force-update.
```

**Decision table:**

| Worktree vs `origin/main` | Action |
|---------------------------|--------|
| `ahead=0 behind=0` — up to date | Proceed. |
| `ahead>0 behind=0` — clean feature branch, no drift | Proceed. |
| `behind>0` (any ahead value) | **Stop.** Rebase the worktree onto `origin/main` (or ask the user) before starting the plan. Running `/ssp-plan` on a stale branch bakes drift into every task spec. |

For the local staging branch: `git fetch origin main:<staging-branch>` fast-forwards it without checkout. If the fetch fails (staging has diverged), report it to the user — do NOT force-update. Let them choose to rebase, merge, or reset.

**When to skip:** explicit user instruction ("don't touch remote", offline work, airplane mode). Default to fresh — the fetch costs seconds; the alternative is midnight merge conflicts.

## Code Review

`/ssp-run` auto-spawns ECC code-reviewer + security-reviewer after execution completes. Critical/high issues block the PR — fix them before pushing. Medium/low are advisory.

Outside of SSP, spawn the reviewers directly after writing code:
- `everything-claude-code:code-reviewer` for quality, patterns, correctness
- `everything-claude-code:security-reviewer` for security analysis

## TDD

When the work involves testable logic, use ECC's `/everything-claude-code:tdd` skill:
1. Write test first (RED)
2. Implement to pass (GREEN)
3. Refactor (IMPROVE)
4. Verify 80%+ coverage

## Worktree Location Standard

Place all git worktrees at `~/worktrees/<repo>/<branch-name>`. Never create them inside `~/projects/` (clutters the projects directory) or inside `.claude/worktrees/` (reserved for agent-managed internal use).

```bash
mkdir -p ~/worktrees/<repo>
git worktree add ~/worktrees/<repo>/feat/my-feature -b feat/my-feature origin/main
```

**Why:** Ad-hoc worktrees in `~/projects/` mix human and agent working trees. `~/worktrees/<repo>/` is the established convention.

**Don't trust `isolation: worktree` alone.** The Agent tool's `isolation: "worktree"` parameter creates a temporary worktree but does NOT guarantee a separate branch — agents can still commit to the user's working branch by default. Always create the feature branch explicitly before launching an implementation agent. Confirm the worktree exists on the right branch before instructing the agent to start.

<!-- Origin: feedback_worktree_discipline.md (project memory promotion) -->

## Fix Problems Directly

When you discover a fixable problem (server down, missing dependency, broken config, stale cache), **fix it yourself immediately**. Do not output instructions telling the user to run a command — you have access to the same shell they do.

**Why:** Diagnosing a problem and then handing the fix back wastes the user's time and breaks flow.

**How to apply:** After diagnosing any issue — dead dev server, missing file, wrong config, failed build — take the corrective action in the same response. Only ask the user when the fix requires credentials, destructive action, or a decision between multiple valid options.

<!-- Origin: feedback_fix_dont_instruct.md (project memory promotion) -->

## Explain Before Implementing

When investigating a bug or feature with the user, don't jump from diagnosis straight to commit + PR. If the user says "let's work on it" or "let's fix it," that means **collaborate** — present the proposed approach with the specific code changes and get explicit confirmation before editing files.

**Why:** Users want to understand and steer the fix, not just receive a finished PR. The walkthrough is the value, especially for non-trivial changes.

**How to apply:** After diagnosing a bug, walk through the fix approach: which files, what changes, why this approach over alternatives. Wait for the user's nod before touching code. Especially when the user explicitly asks to be "in the loop."

<!-- Origin: feedback_explain_before_implementing.md (project memory promotion) -->
