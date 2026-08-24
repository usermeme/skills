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
echo "gitdir: ../.git/worktrees/$DIR_NAME" > "$DIR_NAME/.git"
echo "../../../$DIR_NAME/.git" > ".git/worktrees/$DIR_NAME/gitdir"

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

# Helper function to detect base image from devcontainer.json or fallback
detect_devcontainer_image() {
    local target_dir="$1"
    local base_dir="${2:-}"
    local default_image="mcr.microsoft.com/devcontainers/javascript-node:24"
    local dc_file=""

    if [ -f "$target_dir/.devcontainer/devcontainer.json" ]; then
        dc_file="$target_dir/.devcontainer/devcontainer.json"
    elif [ -f "$target_dir/.devcontainer.json" ]; then
        dc_file="$target_dir/.devcontainer.json"
    elif [ -n "$base_dir" ] && [ -f "$base_dir/.devcontainer/devcontainer.json" ]; then
        dc_file="$base_dir/.devcontainer/devcontainer.json"
    elif [ -n "$base_dir" ] && [ -f "$base_dir/.devcontainer.json" ]; then
        dc_file="$base_dir/.devcontainer.json"
    fi

    if [ -n "$dc_file" ] && [ -f "$dc_file" ]; then
        local detected_image=""
        # Try jq if available (ignoring json comments if any)
        if command -v jq >/dev/null 2>&1; then
            detected_image=$(sed -e 's,//.*$,,g' -e 's,/\*.*\*/,,g' "$dc_file" | jq -r '.image // empty' 2>/dev/null || true)
        fi

        # Fallback to python3 if jq wasn't found or failed
        if [ -z "$detected_image" ] && command -v python3 >/dev/null 2>&1; then
            detected_image=$(python3 -c '
import json, re, sys
try:
    with open(sys.argv[1], "r") as f:
        content = f.read()
    content = re.sub(r"//.*", "", content)
    content = re.sub(r"/\*.*?\*/", "", content, flags=re.DOTALL)
    data = json.loads(content)
    if "image" in data and isinstance(data["image"], str):
        print(data["image"])
except Exception:
    pass
' "$dc_file" 2>/dev/null || true)
        fi

        # Fallback to node if still empty
        if [ -z "$detected_image" ] && command -v node >/dev/null 2>&1; then
            detected_image=$(node -e '
const fs = require("fs");
try {
  let content = fs.readFileSync(process.argv[1], "utf8");
  content = content.replace(/\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "");
  const data = JSON.parse(content);
  if (data.image && typeof data.image === "string") console.log(data.image);
} catch(e) {}
' "$dc_file" 2>/dev/null || true)
        fi

        # Pure grep/sed fallback if no parser succeeded
        if [ -z "$detected_image" ]; then
            detected_image=$(grep -E '^[[:space:]]*"image"[[:space:]]*:' "$dc_file" | head -n 1 | sed -E 's/.*"image"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)
        fi

        if [ -n "$detected_image" ] && [ "$detected_image" != "null" ]; then
            echo "$detected_image"
            return
        fi
    fi

    echo "$default_image"
}

# 6. Configure devcontainer mounts if .devcontainer exists
if [ -d "$DIR_NAME/.devcontainer" ]; then
    echo "🐳 Found .devcontainer in './$DIR_NAME', configuring devcontainer.override.json for git mounts..."
    DC_IMAGE=$(detect_devcontainer_image "$DIR_NAME" "$BASE_DIR_NAME")
    cat << EOF > "$DIR_NAME/.devcontainer/devcontainer.override.json"
{
  "image": "$DC_IMAGE",
  "mounts": [
    "source=\${localWorkspaceFolder}/../.git,target=\${containerWorkspaceFolder}/../.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $DIR_NAME/.devcontainer/devcontainer.override.json (image: $DC_IMAGE)"
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"

