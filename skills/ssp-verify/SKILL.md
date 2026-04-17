---
name: ssp-verify
description: Typecheck, tests, build, and lint. Writes VERIFICATION.md to the plan folder. Run standalone or called by /ssp-run.
---

# SSP Verify

> ✅ **ssp-verify** — running verification.

Print that line before doing anything else.

## Checks

Run in order. If one fails, still run the rest — report everything at once.

### 1. Typecheck
```bash
npm run typecheck --workspaces --if-present
```

### 2. Tests
```bash
npm test --workspaces --if-present
```

### 3. Build
Build only the workspaces whose files changed (check the plan's file map):
```bash
npm run build -w apps/ui        # if UI files changed
npm run build -w apps/mastra    # if Mastra files changed
```

### 4. Lint
```bash
npm run lint --workspaces --if-present
```

## Output

Write `VERIFICATION.md` to the plan folder:

```markdown
# Verification

**Plan:** <slug>
**Branch:** <current branch>
**Date:** YYYY-MM-DD

| Check | Status | Details |
|-------|--------|---------|
| Typecheck | PASS/FAIL | <error summary if failed> |
| Tests | PASS/FAIL | <X passed, Y failed> |
| Build | PASS/FAIL | <which workspaces, errors if any> |
| Lint | PASS/FAIL | <error count> |

## Overall: PASS / FAIL
```

Report the full table to the user. If anything failed, show the relevant error output — don't just say "failed."
