# Agent Orchestration

## SSP Orchestration (primary workflow)

For non-trivial work, use the SSP skills:

| Skill | When |
|-------|------|
| `/ssp-plan` | Starting any multi-file feature, refactor, fix, or chore |
| `/ssp-run` | After plan is reviewed — executes waves, verifies, merges to staging branch |
| `/ssp-verify` | Standalone verification (typecheck, tests, build, lint) |
| `/ssp-clean` | Archive a completed plan (manual only) |

SSP spawns `ssp-executor` subagents for parallel task execution. Executors share the orchestrator's worktree, write code only (no git), and report results.

For trivial single-file changes, skip SSP and just do the work directly.

## ECC Agents (used by SSP and standalone)

These agents are available via ECC and are called by `/ssp-run` automatically during the review step:

| Agent | Purpose | How SSP uses it |
|-------|---------|-----------------|
| code-reviewer | Code quality, patterns | Auto-spawned after execution |
| security-reviewer | Security analysis | Auto-spawned after execution |

These can also be used standalone when you're not in an SSP flow — just spawn them directly.

## Parallel Execution

When spawning multiple independent agents, ALWAYS send them in a single message:

```
# GOOD: parallel
Agent 1: task A
Agent 2: task B
Agent 3: task C
(all in one message)

# BAD: sequential when they don't depend on each other
Agent 1 → wait → Agent 2 → wait → Agent 3
```

This applies to SSP wave execution (parallel tasks in a wave) and to any standalone agent work.
