#!/bin/bash
set -e

# Target directory is current directory or passed argument
REPO_DIR="${1:-.}"
cd "$REPO_DIR"

# 1. Verify this is a git repository
if [ ! -d ".git" ]; then
    if [ -f ".git" ] && [ -d ".bare" ]; then
        echo "ℹ️ This repository is already configured with bare worktrees."
        exit 0
    else
        echo "❌ Error: Not a git repository (no .git directory found in $REPO_DIR)."
        exit 1
    fi
fi

# 2. Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️ Warning: You have uncommitted changes. Please commit or stash them before converting."
    exit 1
fi

# 3. Detect current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main"
fi
CURRENT_DIR="${CURRENT_BRANCH//\//-}"

echo "🔄 Converting repository to bare worktree layout on branch '$CURRENT_BRANCH' (folder './$CURRENT_DIR')..."

# 4. Backup untracked .env files temporarily
TMP_UNTRACKED=$(mktemp -d)
find . -type f \( -name ".env" -o -name ".env.*" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | while read -r f; do
    clean="${f#./}"
    mkdir -p "$TMP_UNTRACKED/$(dirname "$clean")"
    cp "$f" "$TMP_UNTRACKED/$clean"
done

# 5. Convert .git to .bare
mv .git .bare
git --git-dir=.bare config --bool core.bare true
echo "gitdir: ./.bare" > .git

# 6. Configure remote fetch refspec if origin exists
if git --git-dir=.bare remote get-url origin >/dev/null 2>&1; then
    git --git-dir=.bare config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
fi

# 7. Clean existing root directory files (except .bare and .git)
find . -mindepth 1 -maxdepth 1 ! -name ".bare" ! -name ".git" -exec rm -rf {} +

# 8. Add primary worktree for current branch
git worktree add "$CURRENT_DIR" "$CURRENT_BRANCH"

# Make primary worktree pointers relative for host/container portability
echo "gitdir: ../.bare/worktrees/$CURRENT_DIR" > "$CURRENT_DIR/.git"
echo "../../../$CURRENT_DIR/.git" > ".bare/worktrees/$CURRENT_DIR/gitdir"

# 9. Restore backed up .env files into the primary worktree
if [ -d "$TMP_UNTRACKED" ]; then
    find "$TMP_UNTRACKED" -type f | while read -r f; do
        rel="${f#$TMP_UNTRACKED/}"
        mkdir -p "$CURRENT_DIR/$(dirname "$rel")"
        cp "$f" "$CURRENT_DIR/$rel"
    done
    rm -rf "$TMP_UNTRACKED"
fi

# 10. Install .wt-add.sh script into the wrapper directory
SCRIPT_SOURCE="$(dirname "$0")/.wt-add.sh"
if [ -f "$SCRIPT_SOURCE" ]; then
    cp "$SCRIPT_SOURCE" ./.wt-add.sh
    chmod +x ./.wt-add.sh
else
    # Fallback: embedded .wt-add.sh creation
    cat << 'EOF' > ./.wt-add.sh
#!/bin/bash
set -e

BRANCH_NAME=$1
BASE_BRANCH=${2:-}

if [ -z "$BRANCH_NAME" ]; then
    echo "❌ Error: Please provide a branch name."
    echo "Usage: ./.wt-add.sh <branch-name> [base-branch]"
    exit 1
fi

DIR_NAME="${BRANCH_NAME//\//-}"

if [ -z "$BASE_BRANCH" ]; then
    if [ -d "main" ]; then
        BASE_BRANCH="main"
    elif [ -d "master" ]; then
        BASE_BRANCH="master"
    else
        BASE_BRANCH="main"
    fi
fi

BASE_DIR_NAME="$BASE_BRANCH"
if [ ! -d "$BASE_DIR_NAME" ] && [ -d "${BASE_BRANCH//\//-}" ]; then
    BASE_DIR_NAME="${BASE_BRANCH//\//-}"
fi

echo "🌿 Creating worktree for branch '$BRANCH_NAME' in folder './$DIR_NAME' (based on '$BASE_BRANCH')..."

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    git worktree add "$DIR_NAME" "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$DIR_NAME" "$BASE_BRANCH"
fi

# Make worktree pointers relative for host/container portability
echo "gitdir: ../.bare/worktrees/$DIR_NAME" > "$DIR_NAME/.git"
echo "../../../$DIR_NAME/.git" > ".bare/worktrees/$DIR_NAME/gitdir"

if [ -d "$BASE_DIR_NAME" ]; then
    echo "🔍 Scanning '$BASE_DIR_NAME' for .env files..."
    BASE_DIR="$(pwd)/$BASE_DIR_NAME"
    TARGET_DIR="$(pwd)/$DIR_NAME"
    
    while IFS= read -r -d '' envfile; do
        rel_path="${envfile#$BASE_DIR/}"
        dest_file="$TARGET_DIR/$rel_path"
        mkdir -p "$(dirname "$dest_file")"
        cp "$envfile" "$dest_file"
        echo "  ✅ Copied: $rel_path"
    done < <(find "$BASE_DIR" -type f \( -name ".env" -o -name ".env.*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
    
    echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"
fi
EOF
    chmod +x ./.wt-add.sh
fi

echo "✨ Successfully converted to bare worktree layout!"
echo "📁 Layout:"
echo "   ├── .bare/"
echo "   ├── .git"
echo "   ├── .wt-add.sh"
echo "   └── $CURRENT_DIR/"
echo ""
echo "👉 To add a new worktree: ./.wt-add.sh <branch-name>"
