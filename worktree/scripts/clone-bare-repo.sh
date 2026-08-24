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

# Make primary worktree pointers relative for host/container portability
echo "gitdir: ../.bare/worktrees/$DEFAULT_BRANCH" > "$DEFAULT_BRANCH/.git"
echo "../../../$DEFAULT_BRANCH/.git" > ".bare/worktrees/$DEFAULT_BRANCH/gitdir"

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

echo "✨ Repository ready at '$TARGET_DIR'!"
echo "📁 Layout:"
echo "   ├── .bare/"
echo "   ├── .git"
echo "   ├── .wt-add.sh"
echo "   └── $DEFAULT_BRANCH/"
echo ""
echo "👉 To add a new worktree: cd $TARGET_DIR && ./.wt-add.sh <branch-name>"
