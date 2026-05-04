# ssp-claude

A personal [Claude Code](https://claude.com/claude-code) plugin -- the **SSP** orchestration layer: discovery-driven planning, wave-based parallel execution, verification, and continuous learning.

## What's in the box

### Skills (8)

| Skill | Purpose |
|-------|---------|
| `ssp-plan` | Discovery → discussion → atomic tasks with wave-based parallelism. Use when starting any non-trivial implementation. |
| `ssp-run` | Wave-based parallel execution. Spawns `ssp-executor` subagents, handles retries, commits, verifies, rebases, and kicks off code review. |
| `ssp-verify` | Typecheck, tests, build, lint. Writes `VERIFICATION.md` to the plan folder. |
| `ssp-learn` | Extracts reusable patterns from a completed plan — code and process. |
| `ssp-clean` | Compresses a finished plan folder into a single audit-trail markdown. Manual only. |
| `ssp-local-sync` | Syncs the local staging branch — fetches origin/main, fast-forwards or auto-resets+remerges if diverged, merges the current branch in, runs post-merge hooks (npm install, prisma, tmux pane restart). |
| `ssp-review-prs` | Scans for PRs assigned or review-requested and spawns background code reviews via `claude -p` in worktrees. |
| `ssp-setup-worktree` | Symlinks shared project state (node_modules, generated code, `.claude/ssp-plans`) from a fresh worktree to the main working tree. Auto-invoked by `/ssp-plan` when needed. |

### Agents (1)

| Agent | Role |
|-------|------|
| `ssp-executor` | Executes a single atomic task from an SSP plan. Code-only, no git. Spawned by `/ssp-run`. |

### Global rules

| Group | Files |
|-------|-------|
| `common/` | `agents`, `code-display`, `coding-style`, `comments`, `development-workflow`, `git-workflow`, `hooks`, `orchestration-layer`, `patterns`, `performance`, `security`, `testing` |
| `typescript/` | `coding-style`, `patterns`, `security`, `testing` |

Installed into `~/.claude/rules/` — personal engineering conventions that SSP and other skills read during planning, review, and execution. Project-specific rules (e.g. `rules/projects/...`) are deliberately not included; those stay on each machine.

## Install

### Via Claude Code marketplace

```bash
# Add this repo as a marketplace
/plugin marketplace add sebasalines/ssp-claude

# Install the plugin
/plugin install ssp-claude@ssp-claude
```

### Manual (local dev)

```bash
./install.sh
```

Copies skills to `~/.claude/skills/`, the agent to `~/.claude/agents/`, and rules to `~/.claude/rules/`.

## How SSP Works

```
claude --worktree            ← fresh worktree
    ↓
/ssp-setup-worktree          (auto-invoked by /ssp-plan, or run standalone)
    → symlinks node_modules, generated code, .claude/ssp-plans to the main tree
    ↓
/ssp-plan                    → Discovery → discussion → atomic task specs with wave graph
    ↓                         Plans live under .claude/ssp-plans/<slug>/
/ssp-run                     → Parallel wave execution (ssp-executor subagents)
                               → auto-commits per task, rebases onto staging branch
                               → auto-spawns code-reviewer + security-reviewer
    ↓
/ssp-verify                  → Typecheck, tests, build, lint → VERIFICATION.md
    ↓
/ssp-learn                   → Extract reusable patterns → skills/learned/
    ↓
/ssp-clean                   → Archive plan folder to single audit markdown
```

Parallel utilities:
- `/ssp-local-sync` — sync your local staging branch with the latest integration branch (post-`/ssp-run`)
- `/ssp-review-prs` — run periodically (e.g. with `/loop`) to review incoming PRs in the background

## Plan artifacts

Plans write to `.claude/ssp-plans/<slug>/` in the project root. Add that path to your project's `.gitignore`. Inside a worktree, `ssp-setup-worktree` symlinks it to the main working tree so plans survive worktree cleanup and are visible from the main tree without copy-back.

Previous versions of SSP used `.planning/<slug>/`. The path was renamed to live under `.claude/` so a single gitignore line covers all local tooling output.

## Philosophy

SSP is a *living* system. When a skill fails to match actual workflow, update the skill in the same session. Skills should get better every time they're used.

See [CHANGELOG.md](./CHANGELOG.md) for release history.

## License

MIT
