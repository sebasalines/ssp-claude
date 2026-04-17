---
name: ssp-learn
description: Extract reusable patterns from an SSP plan execution. Reads plan artifacts (results, learnings, discussion, discovery), evaluates quality, and saves to the right location. Called by /ssp-run or run standalone on any plan folder.
---

# SSP Learn

> 🧠 **ssp-learn** — extracting patterns from plan execution.

Print that line before doing anything else.

## When to use

- Called automatically by `/ssp-run` after execution completes (step 7)
- Run standalone on any plan folder: `/ssp-learn <slug>`
- Run without a plan folder to fall back to session-only extraction (same as ECC learn-eval)

## Inputs

### From the plan folder (primary source)

Read these in order — they're the richest source of patterns:

1. **`results/*.md`** — per-task `## Learnings` sections. These are first-hand observations from executors who did the actual work.
2. **`LEARNINGS.md`** — aggregated learnings (if `/ssp-run` already collected them)
3. **`DISCUSSION.md`** — decisions made during planning. A decision like "chose Sheet over Dialog because X" is worth persisting if the reasoning would help future plans.
4. **`DISCOVERY.md`** — codebase patterns found during exploration. Only extract if something was genuinely surprising or non-obvious.
5. **`PLAN.md`** — check for failed/skipped tasks. A task that failed 3 times often reveals a pattern worth capturing.

### From the session (secondary source)

Scan the conversation for:
- Patterns not captured in plan artifacts (e.g., a debugging detour that wasn't part of any task)
- User corrections during execution ("no, do it this way instead")
- Anything the executor learnings missed

### SSP meta-patterns (look for these specifically)

- **Planning granularity**: "These 3 tasks should have been 1" or "This task was too big, should have been split"
- **File disjointness failures**: parallel tasks that needed the same file despite the plan saying otherwise
- **Discovery gaps**: files or patterns the discovery phase missed that executors had to figure out on their own
- **Discussion decisions that proved right/wrong**: "D-01 said use X, and it turned out to be the right call because..."

## Process

### Step 1: Gather candidates

Read all plan artifacts and the session. Build a list of candidate patterns — anything that might be worth saving.

### Step 2: Pick the most valuable

Identify the 1-3 most reusable patterns. Prioritize:
- Patterns that would save real time in future sessions
- Patterns specific enough to be actionable (not "write good code")
- Patterns that aren't already captured in existing skills or memory

### Step 3: Determine save location

For each pattern, ask: "Would this be useful in a different project?"

- **Yes → Global** (`~/.claude/skills/learned/`)
- **No → Project** (`.claude/skills/learned/` in the current project)

### Step 4: Quality gate

For each candidate:

```
### Checklist
- [ ] Grep ~/.claude/skills/learned/ for content overlap
- [ ] Grep .claude/skills/learned/ (project) for content overlap
- [ ] Check MEMORY.md (project + global) for overlap
- [ ] Could append to existing skill instead of creating new file?
- [ ] Is this reusable, not a one-off fix?

### Verdict: Save / Improve then Save / Absorb into [X] / Drop

**Rationale:** (1-2 sentences)
```

**Verdict rules:**
- **Save** — unique, specific, well-scoped. Write it.
- **Improve then Save** — valuable but needs refinement. Fix it, then write.
- **Absorb into [X]** — should be appended to an existing skill. Show the target and additions.
- **Drop** — trivial, redundant, or too abstract. Explain why and move on.

### Step 5: Write

For each pattern that passes the gate, write a skill file:

```markdown
---
name: <pattern-name>
description: "<under 130 chars>"
user-invocable: false
origin: ssp-learn
---

# <Descriptive Pattern Name>

**Extracted:** <date>
**Plan:** <slug>
**Context:** <when this applies>

## Problem
<what problem this solves — be specific>

## Solution
<the pattern/technique/workaround — with code examples if applicable>

## When to Use
<trigger conditions for future sessions>
```

### Step 6: Report

Tell the user what was extracted:

```
Patterns extracted: N
- <pattern-name> → ~/.claude/skills/learned/ (global)
- <pattern-name> → .claude/skills/learned/ (project)
Dropped: M (reasons)
```

## What NOT to extract

- Trivial fixes (typos, simple syntax errors)
- One-time issues (specific API outages, transient failures)
- Things already documented in CLAUDE.md or project conventions
- Things already in memory or existing learned skills
- The plan itself (that's what `/ssp-clean` archives are for)
