# Development Workflow

> Extends [git-workflow.md](./git-workflow.md) with the full development process.

## Typical Session Flow

1. Open `claude --worktree` (isolated from your local staging branch)
2. `/ssp-plan` — discovery, discussion, atomic task planning
3. Review plan, tweak task specs if needed
4. `/ssp-run` — parallel execution, verification, merge to staging branch, code review
5. Test locally on your staging branch
6. Rebase integration branch onto `main`, push, create PR
7. `/ssp-clean` when done

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

Every developer maintains a personal staging branch (e.g., `seba-local`) that stays up-to-date with `main`. All completed work merges here first for local testing before any PR gets created. This is configured per-user in Claude Code memory — check memory for "SSP local staging branch."

```
main (shared, what ships)
  └── seba-local (personal, local testing)
        ├── feat/design-chat-sidebar (merged after verification)
        ├── fix/auth-redirect (merged after verification)
        └── ... (test the combined result locally)
```

**NEVER push the local staging branch to remote.** This is a hard rule that applies everywhere — SSP, standalone work, manual git commands, any context. The staging branch is a local-only accumulation of integration branches for testing; it has no remote counterpart and must not get one. `git push` only touches integration branches (`feat/...`, `fix/...`) and `main`. Before any `git push`, verify the current branch is not the configured staging branch. If the user asks to push it, stop and confirm — they almost certainly meant to push the integration branch or create a PR instead.

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
