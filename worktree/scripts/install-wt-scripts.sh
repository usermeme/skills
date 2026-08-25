#!/bin/bash
set -e

# Installs/updates the worktree helper scripts into a bare-worktree wrapper:
#   <wrapper>/wt-add.sh
#   <wrapper>/.scripts/copy-worktree-files.sh
#   <wrapper>/.scripts/devcontainer-override.py
#   <wrapper>/.scripts/copy-list        (created from default only if missing)
#
# Usage: install-wt-scripts.sh [wrapper-root]

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-.}"

if [ ! -d "$DEST/.git" ]; then
    echo "❌ Error: '$DEST' does not look like a worktree wrapper (no .git directory)."
    exit 1
fi

mkdir -p "$DEST/.scripts"
cp "$SRC_DIR/wt-add.sh" "$DEST/wt-add.sh"
cp "$SRC_DIR/lib/copy-worktree-files.sh" "$DEST/.scripts/copy-worktree-files.sh"
cp "$SRC_DIR/lib/devcontainer-override.py" "$DEST/.scripts/devcontainer-override.py"
chmod +x "$DEST/wt-add.sh" "$DEST/.scripts/copy-worktree-files.sh" "$DEST/.scripts/devcontainer-override.py"

if [ ! -f "$DEST/.scripts/copy-list" ]; then
    cp "$SRC_DIR/lib/copy-list.default" "$DEST/.scripts/copy-list"
    echo "📝 Created default .scripts/copy-list (copies .env / .env.* files)."
fi

echo "✅ Installed worktree scripts into '$DEST' (wt-add.sh + .scripts/)."
