---
name: ssp-verify
description: Typecheck, tests, build, lint, and branch-base sanity. Writes VERIFICATION.md to the plan folder. Run standalone or called by /ssp-run.
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

### 5. Branch-base Sanity

Validates that the current branch was based off `origin/main`, not `seba-local` or another staging branch. Catches the most common branch-base mistake — a feature branch silently inflated with hundreds of unrelated files because it was started from staging.

```bash
# Skip mechanism for legitimate giant refactors
if [ "$SSP_VERIFY_SKIP_DIFFSTAT" = "1" ]; then
  echo "Branch-base check skipped (SSP_VERIFY_SKIP_DIFFSTAT=1)"
else
  git fetch origin main 2>/dev/null

  current=$(git rev-parse --abbrev-ref HEAD)

  if [ "$current" = "main" ]; then
    echo "On main — branch-base check N/A"
  else
    file_count=$(git diff origin/main...HEAD --name-only | wc -l | tr -d ' ')
    base=$(git merge-base HEAD origin/main)
    base_short=$(git rev-parse --short "$base")

    echo "Branch-base check:"
    echo "  merge-base(HEAD, origin/main) = $base_short"
    echo "  files changed vs origin/main: $file_count"

    if [ "$file_count" -gt 100 ]; then
      echo "  ❌ FAIL: file count exceeds 100 (likely branched off staging instead of origin/main)"
      exit 1
    fi

    # Verify branch is rooted off origin/main, not off the staging branch.
    # If merge-base(HEAD, staging) is descendant of merge-base(HEAD, origin/main),
    # HEAD shares more history with staging than with main — meaning HEAD was branched
    # off staging. The first check (--is-ancestor "$base" origin/main) was tautological:
    # merge-base HEAD origin/main is by definition on origin/main's history.
    staging="<staging-branch-from-memory>"
    if [ -n "$staging" ] && git rev-parse --verify "$staging" >/dev/null 2>&1; then
      staging_base=$(git merge-base HEAD "$staging")
      main_base="$base"  # already computed above
      if [ "$staging_base" != "$main_base" ] \
         && git merge-base --is-ancestor "$main_base" "$staging_base"; then
        echo "  ❌ FAIL: branch appears to be based off $staging, not origin/main"
        echo "     main-base:    $(git rev-parse --short "$main_base")"
        echo "     staging-base: $(git rev-parse --short "$staging_base")"
        exit 1
      fi
    fi

    echo "  ✓ PASS"
  fi
fi
```

**Hard fail when:**
- `file_count > 100` — typical staging-based branches pull in 200+ files
- branch appears rooted off the staging branch (`merge-base(HEAD, staging)` is descendant of `merge-base(HEAD, origin/main)`)

**Opt-out:** set `SSP_VERIFY_SKIP_DIFFSTAT=1` in the shell before running. Use for legitimate large refactors that intentionally touch >100 files.

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
| Branch base | PASS/FAIL/SKIP | <file count, merge-base, or skip reason> |

## Overall: PASS / FAIL
```

Report the full table to the user. If anything failed, show the relevant error output — don't just say "failed."
