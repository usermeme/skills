#!/bin/bash
set -e

REPO_URL=$1
TARGET_DIR=${2:-}

if [ -z "$REPO_URL" ]; then
    echo "❌ Error: Please provide a repository URL."
    echo "Usage: ./clone-bare-repo.sh <repo-url> [target-directory]"
    exit 1
fi

# Determine target directory name if not provided
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(basename "$REPO_URL" .git)
fi

echo "🚀 Cloning '$REPO_URL' into bare worktree layout at './$TARGET_DIR'..."

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 1. Clone bare repository
git clone --bare "$REPO_URL" .bare

# 2. Configure .git pointer
echo "gitdir: ./.bare" > .git

# 3. Configure fetch refspec for all remote branches
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin

# 4. Detect default branch (main or master)
DEFAULT_BRANCH="main"
if git show-ref --verify --quiet refs/remotes/origin/master && ! git show-ref --verify --quiet refs/remotes/origin/main; then
    DEFAULT_BRANCH="master"
fi

# 5. Create primary worktree
git worktree add "$DEFAULT_BRANCH"

# 6. Install .wt-add.sh helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.wt-add.sh" ]; then
    cp "$SCRIPT_DIR/.wt-add.sh" ./.wt-add.sh
    chmod +x ./.wt-add.sh
else
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

if [ -z "$BASE_BRANCH" ]; then
    if [ -d "main" ]; then
        BASE_BRANCH="main"
    elif [ -d "master" ]; then
        BASE_BRANCH="master"
    else
        BASE_BRANCH="main"
    fi
fi

echo "🌿 Creating worktree for '$BRANCH_NAME' (based on '$BASE_BRANCH')..."

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    git worktree add "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$BRANCH_NAME" "$BASE_BRANCH"
fi

if [ -d "$BASE_BRANCH" ]; then
    echo "🔍 Scanning '$BASE_BRANCH' for .env files..."
    BASE_DIR="$(pwd)/$BASE_BRANCH"
    TARGET_DIR="$(pwd)/$BRANCH_NAME"
    
    while IFS= read -r -d '' envfile; do
        rel_path="${envfile#$BASE_DIR/}"
        dest_file="$TARGET_DIR/$rel_path"
        mkdir -p "$(dirname "$dest_file")"
        cp "$envfile" "$dest_file"
        echo "  ✅ Copied: $rel_path"
    done < <(find "$BASE_DIR" -type f \( -name ".env" -o -name ".env.*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
    
    echo "🎉 Worktree '$BRANCH_NAME' is ready at './$BRANCH_NAME'!"
fi
EOF
    chmod +x ./.wt-add.sh
fi

echo "✨ Repository ready at '$TARGET_DIR'!"
echo "📁 Layout:"
echo "   ├── .bare/"
echo "   ├── .git"
echo "   ├── .wt-add.sh"
echo "   └── $DEFAULT_BRANCH/"
echo ""
echo "👉 To add a new worktree: cd $TARGET_DIR && ./.wt-add.sh <branch-name>"
