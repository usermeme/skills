#!/bin/bash
set -e

# Converts a standard git repository into the bare worktree layout:
#   <repo>/.git (bare) + <repo>/<branch>/ primary worktree + wt-add.sh + .scripts/
#
# The whole working tree is MOVED into the primary worktree, so every untracked
# file (env files, local configs, node_modules, ...) survives the conversion.
#
# Usage: convert-repo-to-worktree.sh [repo-path]

SKILL_SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository (no .git directory found in $REPO_DIR)."
    exit 1
fi

if [ "$(git config --bool core.bare 2>/dev/null)" = "true" ]; then
    echo "ℹ️ This repository is already configured with bare worktrees."
    exit 0
fi

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️ You have uncommitted changes to tracked files. Commit or stash them first."
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main"
fi
CURRENT_DIR="${CURRENT_BRANCH//\//-}"

echo "🔄 Converting to bare worktree layout on branch '$CURRENT_BRANCH' (folder './$CURRENT_DIR')..."

git config --bool core.bare true
if git remote get-url origin >/dev/null 2>&1; then
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
fi

# Move the entire working tree aside (rename on the same volume — instant),
# register the primary worktree without checkout, then move the tree back in.
# Nothing is deleted, so all untracked files are preserved as-is.
TMP_TREE=".wt-convert-$$"
mkdir "$TMP_TREE"
find . -mindepth 1 -maxdepth 1 ! -name ".git" ! -name "$TMP_TREE" -exec mv {} "$TMP_TREE/" \;

git worktree add --no-checkout "$CURRENT_DIR" "$CURRENT_BRANCH"
find "$TMP_TREE" -mindepth 1 -maxdepth 1 -exec mv {} "$CURRENT_DIR/" \;
rmdir "$TMP_TREE"

# Relative worktree pointers keep the layout portable across host and containers
echo "gitdir: ../.git/worktrees/$CURRENT_DIR" > "$CURRENT_DIR/.git"
echo "../../../$CURRENT_DIR/.git" > ".git/worktrees/$CURRENT_DIR/gitdir"

# Rebuild the worktree index; tracked files already match HEAD (clean tree checked above)
git -C "$CURRENT_DIR" reset --hard --quiet

"$SKILL_SCRIPTS_DIR/install-wt-scripts.sh" .

if command -v python3 >/dev/null 2>&1; then
    python3 ".scripts/devcontainer-override.py" "$CURRENT_DIR"
elif [ -d "$CURRENT_DIR/.devcontainer" ] || [ -f "$CURRENT_DIR/.devcontainer.json" ]; then
    echo "⚠️ Skipped devcontainer.override.json (python3 not found)."
fi

echo "✨ Successfully converted to bare worktree layout!"
echo "📁 Layout:"
echo "   ├── .git/"
echo "   ├── .scripts/"
echo "   ├── wt-add.sh"
echo "   └── $CURRENT_DIR/"
echo ""
echo "👉 Add a worktree:          ./wt-add.sh <branch-name>"
echo "👉 Configure copied files:  edit .scripts/copy-list"
