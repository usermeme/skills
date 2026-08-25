#!/bin/bash
set -e

# Creates a sibling worktree in a bare-worktree wrapper:
#   1. checks out an existing local/remote branch, or creates one off the base
#   2. sets relative gitdir pointers for host/container portability
#   3. copies the files listed in .scripts/copy-list from the base worktree
#   4. generates .devcontainer/devcontainer.override.json when a devcontainer exists
#
# Usage: ./wt-add.sh <branch-name> [base-branch]

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
SCRIPTS_DIR="$ROOT_DIR/.scripts"

BRANCH_NAME=$1
BASE_BRANCH=${2:-}

if [ -z "$BRANCH_NAME" ]; then
    echo "❌ Error: Please provide a branch name."
    echo "Usage: ./wt-add.sh <branch-name> [base-branch]"
    exit 1
fi

if ! git check-ref-format --branch "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "❌ Error: '$BRANCH_NAME' is not a valid branch name."
    exit 1
fi

# Folder name: slashes become hyphens (feat/login -> ./feat-login), branch name is preserved
DIR_NAME="${BRANCH_NAME//\//-}"

if [ -e "$DIR_NAME" ]; then
    echo "❌ Error: './$DIR_NAME' already exists."
    exit 1
fi

# Refresh remote refs so remote-only branches are found (offline-safe)
git fetch origin --prune >/dev/null 2>&1 || true

# Detect base branch (main or master) if not explicitly passed
if [ -z "$BASE_BRANCH" ]; then
    if [ -d "main" ]; then
        BASE_BRANCH="main"
    elif [ -d "master" ]; then
        BASE_BRANCH="master"
    elif git show-ref --verify --quiet refs/heads/master; then
        BASE_BRANCH="master"
    else
        BASE_BRANCH="main"
    fi
fi

if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
    echo "❌ Error: '$BASE_BRANCH' is not a valid base branch name."
    exit 1
fi

BASE_DIR_NAME="$BASE_BRANCH"
if [ ! -d "$BASE_DIR_NAME" ] && [ -d "${BASE_BRANCH//\//-}" ]; then
    BASE_DIR_NAME="${BASE_BRANCH//\//-}"
fi

echo "🌿 Creating worktree for branch '$BRANCH_NAME' in './$DIR_NAME' (based on '$BASE_BRANCH')..."

# Existing local/remote branch is checked out directly; otherwise a new branch is created off the base
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    git worktree add "$DIR_NAME" "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$DIR_NAME" "$BASE_BRANCH"
fi

# Relative worktree pointers keep the layout portable across host and containers
echo "gitdir: ../.git/worktrees/$DIR_NAME" > "$DIR_NAME/.git"
echo "../../../$DIR_NAME/.git" > ".git/worktrees/$DIR_NAME/gitdir"

if [ -x "$SCRIPTS_DIR/copy-worktree-files.sh" ]; then
    "$SCRIPTS_DIR/copy-worktree-files.sh" "$BASE_DIR_NAME" "$DIR_NAME"
else
    echo "⚠️ Missing $SCRIPTS_DIR/copy-worktree-files.sh — skipped copying config files."
    echo "   Re-run install-wt-scripts.sh from the worktree skill to restore .scripts/."
fi

if [ -f "$SCRIPTS_DIR/devcontainer-override.py" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPTS_DIR/devcontainer-override.py" "$DIR_NAME" "$BASE_DIR_NAME"
elif [ -d "$DIR_NAME/.devcontainer" ] || [ -f "$DIR_NAME/.devcontainer.json" ]; then
    echo "⚠️ Skipped devcontainer.override.json ($SCRIPTS_DIR/devcontainer-override.py or python3 missing)."
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"
