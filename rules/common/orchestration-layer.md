# Orchestration Layer (SSP)

The SSP skills (`/ssp-plan`, `/ssp-run`, `/ssp-verify`, `/ssp-learn`, `/ssp-clean`) are a personal orchestration layer that mirrors how the user (Seba) naturally works — deep planning, parallel execution, verification, learning. They are NOT static tools. They are a living system.

## Core principle

When the orchestration layer fails to match the user's actual workflow, **update the skill in the same session**. Don't just note it — fix it. The skills should get better every time they're used.

## What SSP models

| Human workflow step | SSP skill | What it does |
|---------------------|-----------|--------------|
| Think about what to build | `/ssp-plan` | Discovery → discussion → atomic tasks |
| Do the work in parallel | `/ssp-run` | Spawn executor subagents per wave |
| Check it compiles and passes | `/ssp-verify` | Typecheck, tests, build, lint |
| Remember what worked | `/ssp-learn` | Extract patterns → skill files |
| Archive when done | `/ssp-clean` | Compress plan folder to audit trail |

## Sub-plans

A plan can run inside the scope of an existing branch. When `/ssp-plan` is invoked on a branch that already has work (not `main`), it should:

1. **Detect the parent branch** — check if HEAD is ahead of main
2. **Ask the user**: run in-place on this branch, or create a child branch?
3. **If child branch**: base it off the current branch (not main), and after execution, merge back into the parent branch before continuing
4. **If in-place**: skip branch creation entirely, commit directly to the current branch

This prevents the "orphan branch" problem where sub-plan work ends up on a disconnected branch that has to be manually merged back.

## Keeping skills up to date

After any session where an SSP skill behaved unexpectedly:
- `/ssp-learn` should evaluate not just code patterns but also **process patterns** — did the plan skill do the right thing? Did the run skill handle the branch correctly?
- If a skill gap is identified, update the skill file (in `~/.claude/skills/`) in the same session
- Use `/ssp-update` to snapshot all skills to the backup gist after significant changes
