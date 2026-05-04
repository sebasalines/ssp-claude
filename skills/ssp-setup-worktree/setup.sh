#!/usr/bin/env bash
# Symlink shared project state from the current git worktree to the main working tree.
# Idempotent. Safe to re-run.

set -euo pipefail

# Resolve the current worktree and the main working tree.
CURRENT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$CURRENT" ]]; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

MAIN=$(git worktree list | head -1 | awk '{print $1}')
if [[ -z "$MAIN" || ! -d "$MAIN" ]]; then
  echo "error: could not resolve main working tree from 'git worktree list'" >&2
  exit 1
fi

if [[ "$CURRENT" == "$MAIN" ]]; then
  echo "error: running inside the main working tree ($MAIN) — nothing to link to" >&2
  echo "this skill is meant to be run from a secondary worktree (e.g. .claude/worktrees/<slug>/)" >&2
  exit 1
fi

echo "main: $MAIN"
echo "worktree: $CURRENT"
echo

# Paths to link, relative to the worktree root.
TARGETS=(
  "node_modules"
  "apps/ui/node_modules"
  "apps/mastra/node_modules"
  "packages/workflow-types/node_modules"
  "apps/ui/src/generated/prisma"
  "packages/workflow-types/dist"
  "apps/ui/.env.local"
  "__ssp__/plans"
)

link_one() {
  local rel="$1"
  local src="$MAIN/$rel"
  local dest="$CURRENT/$rel"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    printf "  skipped %-48s (main has no %s — install deps or create it first)\n" "$rel" "$rel"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local resolved
    resolved=$(readlink "$dest")
    if [[ "$resolved" == "$src" ]]; then
      printf "  already-linked %-41s\n" "$rel"
      return
    fi
    rm "$dest"
    ln -s "$src" "$dest"
    printf "  replaced %-47s (was → %s)\n" "$rel" "$resolved"
    return
  fi

  if [[ -e "$dest" ]]; then
    # Real file or directory. Don't clobber unless empty.
    if [[ -d "$dest" && -z "$(ls -A "$dest" 2>/dev/null)" ]]; then
      rmdir "$dest"
      ln -s "$src" "$dest"
      printf "  linked %-49s (empty dir removed)\n" "$rel"
      return
    fi
    printf "  skipped %-48s (exists as real file/dir — move or delete to link)\n" "$rel"
    return
  fi

  ln -s "$src" "$dest"
  printf "  linked %-49s\n" "$rel"
}

for rel in "${TARGETS[@]}"; do
  link_one "$rel"
done

echo
echo "done. do NOT run npm install in this worktree — install in $MAIN only, then re-run this skill."
