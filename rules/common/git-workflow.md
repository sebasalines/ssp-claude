# Git Workflow

## Commit Message Format
```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Commit Early — Hooks Can Revert

Commit work-in-progress frequently. Don't accumulate many uncommitted edits across multiple files.

**Why:** Pre-commit hooks, file watchers, formatters, and linter auto-fixes can silently revert modified files back to their git state mid-session. This has happened repeatedly during multi-file edit sessions — multiple rounds of edits lost, recoverable only from `git stash` if you remember to stash first.

**How to apply:** After each logical change (a styling pass, a route restructure, a config update), commit immediately even if it's WIP. Don't wait for "all related changes" to be done. Messy commit history is trivially fixable; lost edits are not.

<!-- Origin: feedback_commit_early_hooks_revert.md (project memory promotion) -->

## Never Push Planning Files

Never push planning artifacts to the remote repository. This includes:
- `.planning/` (GSD)
- `.__ssp__/` (SSP)
- `docs/plans/`
- Ad-hoc scratch docs like `setup-project-rules.md`, `notes-to-self.md`, etc.

**Why:** These are local-only workspace artifacts, not part of the codebase. Pushing them clutters PRs with files reviewers can't act on and leaks in-progress thinking.

**How to apply:** Before any `git push` or `gh pr create`, run `git diff <base>...HEAD --name-only | grep -E '(\.planning|.__ssp__|docs/plans)'`. If anything matches, either unstage those files or rebase them out before pushing.

<!-- Origin: feedback_no_push_planning.md (project memory promotion) -->

## Resolve Merge Conflicts Pragmatically

When merging surfaces conflicts that include modify/delete pairs or architectural-level changes (routes moved, files renamed, wrappers reshaped), **resolve them directly instead of proposing abort.** The default mental model is that routes moving between paths or files being renamed is a mechanical transform, not a "dedicated session" problem.

**Why:** Catastrophizing — labeling a normal route-rename merge as an "architectural integration session" and offering three options leaning toward abort — wastes time. Most modify/delete conflicts are file moves, where the deletion has a corresponding new path elsewhere on `main`.

**How to apply:**

1. When a merge surfaces modify/delete, **investigate whether the deletion has a replacement.** `git log origin/main -- <deleted-path>` usually shows the move commit; `git ls-tree -r origin/main --name-only | grep <keyword>` finds the new location.
2. If it's a move/rename, port the local modifications forward to the new path. `git rm` the deleted file, edit main's new file with the local changes.
3. If it's a legitimate removal (feature deleted, not moved), check whether the local branch still depends on it. Only THEN escalate to the user — when resolution requires product judgment.
4. Default tone: "I see N conflicts, here's the resolution plan, executing." Not "this is architecturally deep, let me ask."
5. Offering abort is appropriate only when resolution requires user judgment on product behavior — not for mechanical name/path changes.
6. Use `git show origin/main:<path>` to fetch the authoritative version of a renamed file when the conflict markers don't show enough context.

<!-- Origin: feedback_resolve_dont_catastrophize.md (project memory promotion) -->

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch
6. **PRs always target `main`.** Never target the local staging branch (`seba-local`) — see `development-workflow.md` for the staging branch contract.

> For the full development process (planning, TDD, code review) before git operations,
> see [development-workflow.md](./development-workflow.md).
