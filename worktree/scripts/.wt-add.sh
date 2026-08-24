#!/bin/bash
set -e

BRANCH_NAME=$1
BASE_BRANCH=${2:-}

# 1. Validate branch name argument
if [ -z "$BRANCH_NAME" ]; then
    echo "❌ Error: Please provide a branch name."
    echo "Usage: ./.wt-add.sh <branch-name> [base-branch]"
    exit 1
fi

# 2. Detect base worktree / branch (main or master) if not explicitly passed
if [ -z "$BASE_BRANCH" ]; then
    if [ -d "main" ]; then
        BASE_BRANCH="main"
    elif [ -d "master" ]; then
        BASE_BRANCH="master"
    else
        BASE_BRANCH="main"
    fi
fi

# 3. Create the new worktree
echo "🌿 Creating worktree for '$BRANCH_NAME' (based on '$BASE_BRANCH')..."

# If branch exists locally or on remote, add it directly; otherwise create new branch
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    git worktree add "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$BRANCH_NAME" "$BASE_BRANCH"
fi

# 4. Recursively copy .env files from base worktree into new worktree
if [ -d "$BASE_BRANCH" ]; then
    echo "🔍 Scanning '$BASE_BRANCH' for .env files..."
    
    BASE_DIR="$(pwd)/$BASE_BRANCH"
    TARGET_DIR="$(pwd)/$BRANCH_NAME"
    
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
        echo "ℹ️ No .env files found in '$BASE_BRANCH'."
    fi
    
    echo "🎉 Worktree '$BRANCH_NAME' is ready at './$BRANCH_NAME'!"
else
    echo "⚠️ Base folder '$BASE_BRANCH' not found. Skipped .env file copy."
fi
