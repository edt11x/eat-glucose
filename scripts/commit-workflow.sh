#!/bin/bash
# commit-workflow.sh — Automated commit workflow for edt-glucose
#
# Usage: ./scripts/commit-workflow.sh ["commit message"]
#
# This script automates the mechanical parts of the commit workflow.
# For the full workflow (including README/CLAUDE.md/MEMORY updates),
# tell Claude Code: "Run the Commit Workflow" and it will follow
# the procedure documented in COMMIT_WORKFLOW.md.
#
# Steps performed:
#   1. Show current status and diff summary
#   2. Check for untracked files that should be staged
#   3. Stage all modified and new source files
#   4. Commit with the provided message (or prompt for one)
#   5. Push to the current remote tracking branch

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== Git Status ==="
git status --short

echo ""
echo "=== Diff Summary ==="
git diff --stat
git diff --cached --stat 2>/dev/null

echo ""
echo "=== Recent Commits ==="
git log --oneline -5

echo ""

# Check for untracked files (excluding .gitignore patterns)
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "=== Untracked Files ==="
    echo "$UNTRACKED"
    echo ""
    read -p "Stage all untracked files? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$UNTRACKED" | xargs git add
        echo "Staged untracked files."
    fi
fi

# Stage all modified tracked files
MODIFIED=$(git diff --name-only)
if [ -n "$MODIFIED" ]; then
    echo "$MODIFIED" | xargs git add
    echo "Staged modified files."
fi

# Commit
if [ -n "${1:-}" ]; then
    COMMIT_MSG="$1

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
else
    echo ""
    read -p "Enter commit message: " COMMIT_MSG
    COMMIT_MSG="$COMMIT_MSG

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
fi

git commit -m "$COMMIT_MSG"

# Push
BRANCH=$(git branch --show-current)
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")

if [ -z "$UPSTREAM" ]; then
    echo "No upstream set. Pushing with --set-upstream..."
    git push --set-upstream origin "$BRANCH"
else
    git push
fi

echo ""
echo "=== Done ==="
git log --oneline -1
