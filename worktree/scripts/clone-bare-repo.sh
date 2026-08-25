#!/bin/bash
set -e

# Clones a repository straight into the bare worktree layout:
#   <target>/.git (bare) + <target>/<default-branch>/ + wt-add.sh + .scripts/
#
# Usage: clone-bare-repo.sh <repo-url> [target-directory]

SKILL_SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_URL=$1
TARGET_DIR=${2:-}

if [ -z "$REPO_URL" ]; then
    echo "❌ Error: Please provide a repository URL."
    echo "Usage: clone-bare-repo.sh <repo-url> [target-directory]"
    exit 1
fi

if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(basename "$REPO_URL" .git)
fi

echo "🚀 Cloning '$REPO_URL' into bare worktree layout at './$TARGET_DIR'..."

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

git clone --bare "$REPO_URL" .git
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin

# Bare clones set HEAD to the remote's default branch
DEFAULT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ -z "$DEFAULT_BRANCH" ]; then
    if git show-ref --verify --quiet refs/heads/main; then
        DEFAULT_BRANCH="main"
    elif git show-ref --verify --quiet refs/heads/master; then
        DEFAULT_BRANCH="master"
    else
        DEFAULT_BRANCH="main"
    fi
fi
DEFAULT_DIR="${DEFAULT_BRANCH//\//-}"

git worktree add "$DEFAULT_DIR" "$DEFAULT_BRANCH"

# Relative worktree pointers keep the layout portable across host and containers
echo "gitdir: ../.git/worktrees/$DEFAULT_DIR" > "$DEFAULT_DIR/.git"
echo "../../../$DEFAULT_DIR/.git" > ".git/worktrees/$DEFAULT_DIR/gitdir"

"$SKILL_SCRIPTS_DIR/install-wt-scripts.sh" .

if command -v python3 >/dev/null 2>&1; then
    python3 ".scripts/devcontainer-override.py" "$DEFAULT_DIR"
elif [ -d "$DEFAULT_DIR/.devcontainer" ] || [ -f "$DEFAULT_DIR/.devcontainer.json" ]; then
    echo "⚠️ Skipped devcontainer.override.json (python3 not found)."
fi

echo "✨ Repository ready at '$TARGET_DIR'!"
echo "📁 Layout:"
echo "   ├── .git/"
echo "   ├── .scripts/"
echo "   ├── wt-add.sh"
echo "   └── $DEFAULT_DIR/"
echo ""
echo "👉 Add a worktree:          cd $TARGET_DIR && ./wt-add.sh <branch-name>"
echo "👉 Configure copied files:  edit $TARGET_DIR/.scripts/copy-list"
