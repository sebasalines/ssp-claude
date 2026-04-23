# Performance Optimization

## Model Selection

**Haiku 4.5** — lightweight, frequent invocation, worker agents:
- SSP executor subagents (when task is straightforward)
- Quick lookups, simple edits

**Sonnet 4.6** — best coding model:
- Main development work
- SSP executor subagents (default for most tasks)
- Orchestrating multi-agent workflows

**Opus 4.6** — deepest reasoning:
- Complex architectural decisions
- SSP planning (discovery + discussion + task design)
- Research and analysis

## Context Window Management

Avoid last 20% of context for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

SSP helps here — `/ssp-plan` and `/ssp-run` keep the orchestrator lean while subagents handle the heavy context load per-task.

## Extended Thinking

Enabled by default (up to 31,999 tokens reserved for reasoning).

- **Toggle**: Option+T (macOS) / Alt+T (Windows/Linux)
- **Budget cap**: `export MAX_THINKING_TOKENS=10000`
- **Verbose mode**: Ctrl+O to see thinking output

## Build Failures

If build fails:
1. Read the error — don't guess
2. Fix incrementally
3. Verify after each fix
4. If stuck, run `/ssp-verify` to get the full picture (typecheck + tests + build + lint)
