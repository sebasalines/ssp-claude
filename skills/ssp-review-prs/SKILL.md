---
name: ssp-review-prs
description: Check for PRs assigned or review-requested, spawn background code reviews via claude -p in worktrees. Max 2 concurrent. Run with /loop for continuous monitoring.
---

# SSP Review PRs

> 👀 **ssp-review-prs** — checking for PRs to review.

Print that line before doing anything else.

## How to use

**Dedicated review session** — open a separate terminal, start `claude`, run:

```
/loop /ssp-review-prs
```

Walk away. It self-paces: checks every ~5 min when idle, ~2 min when reviews are active. Check back later to see results in each repo's `.claude/code-reviews/`.

Can also run one-shot: `/ssp-review-prs` for a single check cycle.

## Config

`~/.claude/review-repos.json` — maps GitHub repos to local paths:

```json
{
  "bevy/spiralpegasus": "/Users/ssp/projects/spiralpegasus",
  "bevy/bevy": "/Users/ssp/projects/bevy-3"
}
```

Add repos as needed. The key is `owner/repo` (for `gh` commands), the value is the local clone path.

## State

`~/.claude/review-state.json` — tracks what's been reviewed. Created automatically on first run. Format:

```json
{
  "bevy/spiralpegasus#465": {
    "sha": "be9bac3b",
    "status": "done",
    "reviewFile": "/Users/ssp/projects/spiralpegasus/.claude/code-reviews/pr-465-2026-04-17.md",
    "startedAt": "2026-04-17T14:30"
  }
}
```

Statuses: `queued`, `reviewing`, `done`, `failed`.

## Workflow (one cycle)

### Step 1: Load config + state

```bash
cat ~/.claude/review-repos.json
cat ~/.claude/review-state.json 2>/dev/null || echo '{}'
```

### Step 2: Check for PRs

For each configured repo:

```bash
gh pr list -R <owner/repo> --search "review-requested:@me" --json number,title,headRefName,headRefOid,baseRefName,url
gh pr list -R <owner/repo> --search "assignee:@me" --json number,title,headRefName,headRefOid,baseRefName,url
```

Merge results, dedup by PR number.

**Skip PRs where:**
- State shows `done` and `sha` matches current `headRefOid` (already reviewed this version)
- State shows `reviewing` (in progress)
- The PR author is you (`--author=@me`) — don't review your own PRs

### Step 3: Check active reviews

Count entries with `status: "reviewing"` in state. Check if their background `claude -p` processes have finished.

The background agent writes the review to `/tmp/ssp-review-pr-<number>-<date>.md` (not directly to the repo — `.claude/` is a permission-gated path even under `bypassPermissions`). When the background task exits, the orchestrator moves the file into the repo.

A review can end three ways:

```bash
# If the /tmp file exists and is non-empty → done
# If the /tmp file is missing/empty AND the background task has completed → failed
# Otherwise → still running
[ -s "/tmp/ssp-review-pr-<number>-<date>.md" ] && echo "done"
```

For **done**:
- Move the review into the repo:
  `mv /tmp/ssp-review-pr-<number>-<date>.md <repo-path>/.claude/code-reviews/pr-<number>-<date>.md`
- Update state to `done` and set `reviewFile` to the final path in the repo
- Clean up the worktree: `git -C <repo-path> worktree remove .claude/worktrees/pr-<number> --force`
- Report: "Review complete: PR #<number> — <title>"

For **failed**:
- Update state to `failed` with the log path (see Step 4)
- Leave the worktree in place so the next cycle can retry or the user can inspect
- Report: "Review failed: PR #<number> — see `/tmp/ssp-review-pr-<number>.log`"

### Step 4: Spawn new reviews

If active count < 2 and there are unreviewed PRs:

For each PR to review (fill up to 2 slots):

1. Make sure `.claude/code-reviews/` exists **before** spawning:
   ```bash
   mkdir -p <repo-path>/.claude/code-reviews
   ```

2. Fetch and create worktree:
   ```bash
   git -C <repo-path> fetch origin <headRefName>
   git -C <repo-path> worktree add .claude/worktrees/pr-<number> origin/<headRefName>
   ```

3. Update state to `reviewing`.

4. Spawn background review. **Flags matter** — without them the agent silently bails:
   - `--permission-mode=bypassPermissions` → lets the agent write the review file at its absolute path without prompting (background process has no one to approve it, so a prompt = silent exit)
   - `< /dev/null` → closes stdin so claude doesn't print a "no stdin data received" warning and/or hang
   - `> /tmp/ssp-review-pr-<number>.log 2>&1` → capture stdout + stderr to a log file instead of discarding, so failures are debuggable

   The spawned `claude -p` should NOT review the diff inline — it should delegate to the ECC review agents for consistent, thorough coverage matching what `/ssp-run` produces. Invoke both `everything-claude-code:code-reviewer` AND `everything-claude-code:security-reviewer` in parallel, then synthesize their findings into the review file.

   **Write target must be `/tmp/ssp-review-pr-<number>-<date>.md`**, NOT the repo path. `bypassPermissions` does not override the hard block on writing to `.claude/` directories — the agent would produce output but fail silently. The orchestrator moves the file into the repo after the background task completes (see Step 3).

   ```bash
   cd <repo-path>/.claude/worktrees/pr-<number> && \
   claude -p --permission-mode=bypassPermissions "You are coordinating a code review of PR #<number>: <title>.
   Branch: <headRefName> → <baseRefName>
   Repo: <owner/repo>
   Head SHA: <sha>

   Do NOT review the diff yourself. Instead:

   1. Read CLAUDE.md if it exists (project conventions may affect how the reviewers score findings — pass any critical conventions through in the agent prompts).
   2. Compute the diff: \`git diff origin/<baseRefName>...HEAD\` — note which files and languages are touched.
   3. In a SINGLE message, spawn BOTH agents in parallel via the Agent tool:
      - \`everything-claude-code:code-reviewer\` — review \\\`git diff origin/<baseRefName>...HEAD\\\` for quality, correctness, patterns, performance. Flag critical/high/medium/low issues with file:line references. Skip pure style nitpicks.
      - \`everything-claude-code:security-reviewer\` — review the same diff for security issues (injection, authz, secrets, unsafe deserialization, XSS, SSRF, etc.). Flag CRITICAL/HIGH/MEDIUM/LOW.
   4. Synthesize both agent reports into a single review file at: \`/tmp/ssp-review-pr-<number>-<date>.md\` (the orchestrator moves this file into the repo after your task completes — do NOT write into \`.claude/\` directly; that path is permission-gated and the write will be silently blocked).

   Review file format:

   # PR #<number>: <title>
   **Repo:** <owner/repo>
   **Branch:** <headRefName>
   **Reviewed at:** <sha>
   **Date:** <date>
   **Reviewers:** code-reviewer + security-reviewer

   ## Verdict: APPROVE / REQUEST_CHANGES / COMMENT
   (REQUEST_CHANGES if either agent flagged critical or high severity; otherwise APPROVE unless your judgement disagrees.)

   ## Summary
   (2-3 sentences — what the PR does and the overall read.)

   ## Code review findings
   | Severity | File:Line | Finding |
   |----------|-----------|---------|
   | ... | ... | ... |

   ## Security findings
   | Severity | File:Line | Finding |
   |----------|-----------|---------|
   | ... | ... | ... |

   (Write \"None.\" if either table is empty — don't omit the section.)

   ## Recommendation
   (Action items in priority order.)" < /dev/null > /tmp/ssp-review-pr-<number>.log 2>&1
   ```

   Run with `Bash` `run_in_background: true`.

### Step 5: Save state

Write updated `~/.claude/review-state.json`.

### Step 6: Report

```
PRs: N pending, M reviewing, K completed this session
[if completed:] Reviews ready:
  - bevy/spiralpegasus#465 → .claude/code-reviews/pr-465-2026-04-17.md
[if new reviews spawned:] Started reviewing:
  - bevy/spiralpegasus#470: "feat: user profiles"
[if nothing new:] No new PRs to review.
```

### Step 7: Loop timing

If running via `/loop`:
- **Reviews active:** wake up in ~120s to check if they finished
- **Nothing happening:** wake up in ~300s to poll for new PRs
- **Just completed reviews:** wake up in ~60s in case there are queued PRs to start

## Gitignore

Each repo needs `.claude/code-reviews/` gitignored. Add it if it's not there:

```bash
grep -q 'code-reviews' <repo-path>/.gitignore 2>/dev/null || echo '.claude/code-reviews/' >> <repo-path>/.gitignore
```

## Re-reviews

When a PR gets new commits (HEAD SHA changes from what's in state), the state entry resets to unreviewed. Next cycle picks it up and creates a new dated review file. Old review files stay — you can diff them to see what changed.

## Manual posting

Reviews are local-only by default. To post one to GitHub:

```bash
gh pr review <number> -R <owner/repo> --comment --body-file <review-file>
```

This is deliberate — you read the review first, decide if you agree, then post.

## Troubleshooting

**`.claude/` is a permission-gated path.** `claude -p --permission-mode=bypassPermissions` does NOT override the hard block on writing inside `.claude/` directories. This is why the skill has the background agent write to `/tmp/ssp-review-pr-<number>-<date>.md` and the orchestrator moves the file into the repo's `.claude/code-reviews/` in Step 3. If you modify the skill to write directly to `.claude/`, the Write tool will prompt for approval, no one will answer in background mode, and the agent will silently emit the review to stdout (captured in `/tmp/ssp-review-pr-<number>.log`) without saving a file.

**Background task exited 0 but the review file is missing or empty.** Likely causes in order of likelihood:
1. The agent wrote to `.claude/` instead of `/tmp/` (see above) — check `/tmp/ssp-review-pr-<number>.log`; the review body is usually in there.
2. `claude -p` was spawned without `--permission-mode=bypassPermissions` — the Write tool prompted, got no response, agent gave up.
3. The ECC review agents weren't available in the spawned process — unusual, but possible if they're project-scoped rather than user-global.

**How to recover a failed review:** read `/tmp/ssp-review-pr-<number>.log` — if the agent produced the review in stdout but couldn't write the file, you can hand-extract it and save to `.claude/code-reviews/pr-<number>-<date>.md` from the orchestrator session (which has write access).

**Retry path:** the worktree stays in place for `failed` entries. Next loop cycle, delete the `failed` state entry (or change it to unreviewed) and the skill will respawn a fresh review.
