---
name: ssp-update
description: Snapshot all SSP skills, agent, and global rules to a private GitHub gist. Recreates the gist fresh each time with a README, install script, and all files. Use after modifying any SSP component.
---

# SSP Update

> 📦 **ssp-update** — snapshotting SSP to gist.

Print that line before doing anything else.

## What it does

Deletes the previous SSP gist (if one exists in memory) and creates a fresh one with the current versions of all SSP files — README, curl-based install script, skills, agent, and rewritten global rules.

## Workflow

### Step 1: Check memory for existing gist

Look in memory for "SSP gist URL". If found, delete it:

```bash
gh gist delete <gist-id> --yes
```

If not found, skip deletion.

### Step 2: Clean /tmp

```bash
rm -f /tmp/gist-*.md /tmp/gist-*.sh
```

### Step 3: Copy files with unique names

Gists can't have duplicate filenames. Copy everything to `/tmp/` with prefixed names:

```bash
# SSP skills + agent
cp ~/.claude/skills/ssp-plan/SKILL.md    /tmp/gist-01-ssp-plan.md
cp ~/.claude/skills/ssp-run/SKILL.md     /tmp/gist-02-ssp-run.md
cp ~/.claude/skills/ssp-verify/SKILL.md  /tmp/gist-03-ssp-verify.md
cp ~/.claude/skills/ssp-clean/SKILL.md   /tmp/gist-04-ssp-clean.md
cp ~/.claude/skills/ssp-learn/SKILL.md   /tmp/gist-05-ssp-learn.md
cp ~/.claude/skills/ssp-update/SKILL.md  /tmp/gist-06-ssp-update.md
cp ~/.claude/agents/ssp-executor.md      /tmp/gist-07-ssp-executor.md

# Global rules (only the ones SSP rewrote)
cp ~/.claude/rules/common/agents.md                /tmp/gist-08-rules-common-agents.md
cp ~/.claude/rules/common/hooks.md                 /tmp/gist-09-rules-common-hooks.md
cp ~/.claude/rules/common/development-workflow.md   /tmp/gist-10-rules-common-development-workflow.md
cp ~/.claude/rules/common/testing.md               /tmp/gist-11-rules-common-testing.md
cp ~/.claude/rules/common/performance.md           /tmp/gist-12-rules-common-performance.md
cp ~/.claude/rules/common/patterns.md              /tmp/gist-13-rules-common-patterns.md
cp ~/.claude/rules/typescript/testing.md           /tmp/gist-14-rules-typescript-testing.md
```

If any new SSP skills or rules have been added since this skill was written, include them too — scan `~/.claude/skills/ssp-*/SKILL.md` and `~/.claude/agents/ssp-*.md` to catch additions.

### Step 4: Build the README

Write `/tmp/gist-00-README.md`. Read the current skill files to make sure the README reflects what actually exists. Include:

- Overview of SSP
- **Install instructions using `curl`** (see install script format below)
- Component table (skills + agent + rules, with install paths)
- The local staging branch concept
- Full workflow example (worktree → plan → run → test on staging branch → PR → clean)
- Multiple parallel plans across worktrees
- Design decisions
- Plan folder structure

**Important:** Leave the gist ID as a placeholder (`GIST_ID`) in the README — you'll replace it after creation in Step 6.

### Step 5: Build the install script

Write `/tmp/gist-00-install.sh`. The script takes a gist raw base URL as its first argument and uses `curl` to download each file. No git clone, no auth needed.

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?Usage: install.sh <gist-raw-base-url>}"
CLAUDE_DIR="${HOME}/.claude"

echo "Installing SSP Orchestration System to ${CLAUDE_DIR}/"

# File map: gist filename → install path
declare -A FILES=(
  ["gist-01-ssp-plan.md"]="skills/ssp-plan/SKILL.md"
  ["gist-02-ssp-run.md"]="skills/ssp-run/SKILL.md"
  ["gist-03-ssp-verify.md"]="skills/ssp-verify/SKILL.md"
  ["gist-04-ssp-clean.md"]="skills/ssp-clean/SKILL.md"
  ["gist-05-ssp-learn.md"]="skills/ssp-learn/SKILL.md"
  ["gist-06-ssp-update.md"]="skills/ssp-update/SKILL.md"
  ["gist-07-ssp-executor.md"]="agents/ssp-executor.md"
  ["gist-08-rules-common-agents.md"]="rules/common/agents.md"
  ["gist-09-rules-common-hooks.md"]="rules/common/hooks.md"
  ["gist-10-rules-common-development-workflow.md"]="rules/common/development-workflow.md"
  ["gist-11-rules-common-testing.md"]="rules/common/testing.md"
  ["gist-12-rules-common-performance.md"]="rules/common/performance.md"
  ["gist-13-rules-common-patterns.md"]="rules/common/patterns.md"
  ["gist-14-rules-typescript-testing.md"]="rules/typescript/testing.md"
)

for src in "${!FILES[@]}"; do
  dest="${CLAUDE_DIR}/${FILES[$src]}"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL "${BASE_URL}/${src}" -o "$dest"
  echo "  ${FILES[$src]}"
done

echo ""
echo "Done. Installed to ${CLAUDE_DIR}/"
echo ""
echo "Next steps:"
echo "  1. Add '.planning/' to your project's .gitignore"
echo "  2. Create your local staging branch:"
echo "     git checkout main && git pull"
echo "     git checkout -b yourname-local"
echo "  3. Start: claude --worktree"
echo "  4. Plan:  /ssp-plan"
```

**The README install instructions should show:**

```bash
curl -fsSL https://gist.githubusercontent.com/USER/GIST_ID/raw/gist-00-install.sh \
  | bash -s -- https://gist.githubusercontent.com/USER/GIST_ID/raw
```

### Step 6: Create the gist and patch the README

Create the gist:

```bash
gh gist create \
  -d "SSP Orchestration System — skills, agent, and global rules" \
  /tmp/gist-00-README.md \
  /tmp/gist-00-install.sh \
  /tmp/gist-01-ssp-plan.md \
  ... (all files)
```

Extract the gist ID from the returned URL. Then patch the README to replace `GIST_ID` with the actual ID:

```bash
# Extract gist ID from URL
GIST_ID=$(echo "$URL" | grep -o '[^/]*$')

# Replace placeholder in README
sed -i '' "s/GIST_ID/${GIST_ID}/g" /tmp/gist-00-README.md

# Update the gist's README with the patched version
gh gist edit "$GIST_ID" -f gist-00-README.md /tmp/gist-00-README.md
```

### Step 7: Save gist URL to memory

Save the new gist URL to memory so the next `/ssp-update` can delete and recreate it:

```markdown
---
name: SSP gist URL
description: Current GitHub gist URL for SSP orchestration system snapshot
type: reference
---

Gist: <url>
Updated: <date>
```

### Step 8: Report

```
SSP snapshot updated: <url>
Files: N (M skills + 1 agent + K rules + README + install.sh)

Install command:
curl -fsSL https://gist.githubusercontent.com/USER/GIST_ID/raw/gist-00-install.sh \
  | bash -s -- https://gist.githubusercontent.com/USER/GIST_ID/raw
```
