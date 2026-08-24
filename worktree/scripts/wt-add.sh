#!/bin/bash
set -e

BRANCH_NAME=$1
BASE_BRANCH=${2:-}

# 1. Validate branch name argument
if [ -z "$BRANCH_NAME" ]; then
    echo "❌ Error: Please provide a branch name."
    echo "Usage: ./wt-add.sh <branch-name> [base-branch]"
    exit 1
fi

# 2. Normalize folder name (replace slashes with hyphens, e.g. feat/asdasd -> feat-asdasd)
DIR_NAME="${BRANCH_NAME//\//-}"

# 3. Detect base worktree / branch (main or master) if not explicitly passed
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

# 4. Create the new worktree
echo "🌿 Creating worktree for branch '$BRANCH_NAME' in folder './$DIR_NAME' (based on '$BASE_BRANCH')..."

# If branch exists locally or on remote, add it directly; otherwise create new branch
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    git worktree add "$DIR_NAME" "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$DIR_NAME" "$BASE_BRANCH"
fi

# Make worktree pointers relative for host/container portability
echo "gitdir: ../.bare/worktrees/$DIR_NAME" > "$DIR_NAME/.git"
echo "../../../$DIR_NAME/.git" > ".bare/worktrees/$DIR_NAME/gitdir"

# 5. Recursively copy .env files from base worktree into new worktree
if [ -d "$BASE_DIR_NAME" ]; then
    echo "🔍 Scanning '$BASE_DIR_NAME' for .env files..."
    
    BASE_DIR="$(pwd)/$BASE_DIR_NAME"
    TARGET_DIR="$(pwd)/$DIR_NAME"
    
    found_any=false
    while IFS= read -r -d '' envfile; do
        found_any=true
        rel_path="${envfile#$BASE_DIR/}"
        dest_file="$TARGET_DIR/$rel_path"
        
        # Ensure target directory structure exists and copy the file
        mkdir -p "$(dirname "$dest_file")"
        cp "$envfile" "$dest_file"
        echo "  ✅ Copied: $rel_path"
    done < <(find "$BASE_DIR" -type f \( -name ".env" -o -name ".env.*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
    
    if [ "$found_any" = false ]; then
        echo "ℹ️ No .env files found in '$BASE_DIR_NAME'."
    fi
else
    echo "⚠️ Base folder '$BASE_DIR_NAME' not found. Skipped .env file copy."
fi

# 6. Configure devcontainer mounts if .devcontainer exists
if [ -d "$DIR_NAME/.devcontainer" ]; then
    echo "🐳 Found .devcontainer in './$DIR_NAME', configuring devcontainer.override.json for git mounts..."
    cat << 'EOF' > "$DIR_NAME/.devcontainer/devcontainer.override.json"
{
  "mounts": [
    "source=${localWorkspaceFolder}/../.bare,target=${containerWorkspaceFolder}/../.bare,type=bind",
    "source=${localWorkspaceFolder}/../.git,target=${containerWorkspaceFolder}/../.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $DIR_NAME/.devcontainer/devcontainer.override.json"
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"

