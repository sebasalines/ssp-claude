# ssp-claude

A personal [Claude Code](https://claude.com/claude-code) plugin -- the **SSP** orchestration layer: discovery-driven planning, wave-based parallel execution, verification, and continuous learning.

## What's in the box

### Skills (7)

| Skill | Purpose |
|-------|---------|
| `ssp-plan` | Discovery → discussion → atomic tasks with wave-based parallelism. Use when starting any non-trivial implementation. |
| `ssp-run` | Wave-based parallel execution. Spawns `ssp-executor` subagents, handles retries, commits, verifies, rebases, and kicks off code review. |
| `ssp-verify` | Typecheck, tests, build, lint. Writes `VERIFICATION.md` to the plan folder. |
| `ssp-learn` | Extracts reusable patterns from a completed plan — code and process. |
| `ssp-clean` | Compresses a finished plan folder into a single audit-trail markdown. Manual only. |
| `ssp-update` | Snapshots all SSP skills + agent to a private GitHub gist backup. |
| `ssp-review-prs` | Scans for PRs assigned or review-requested and spawns background code reviews via `claude -p` in worktrees. |

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

Copies skills to `~/.claude/skills/` and the agent to `~/.claude/agents/`.

## How SSP Works

```
/ssp-plan      →  Discovery → discussion → atomic task specs with wave graph
    ↓
/ssp-run       →  Parallel wave execution (ssp-executor subagents)
                  → auto-commits, rebases onto staging branch
                  → auto-spawns code-reviewer + security-reviewer
    ↓
/ssp-verify    →  Typecheck, tests, build, lint
    ↓
/ssp-learn     →  Extract reusable patterns → skills/
    ↓
/ssp-clean     →  Archive plan folder to single audit markdown
```

## Philosophy

SSP is a *living* system. When a skill fails to match actual workflow, update the skill in the same session. Skills should get better every time they're used.

## License

MIT
