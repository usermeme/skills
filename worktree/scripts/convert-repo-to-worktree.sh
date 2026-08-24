#!/bin/bash
set -e

# Target directory is current directory or passed argument
REPO_DIR="${1:-.}"
cd "$REPO_DIR"

# 1. Verify this is a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository (no .git directory found in $REPO_DIR)."
    exit 1
fi

if [ "$(git config --bool core.bare 2>/dev/null)" = "true" ]; then
    echo "ℹ️ This repository is already configured with bare worktrees."
    exit 0
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

# 5. Configure core.bare on .git
git config --bool core.bare true

# 6. Configure remote fetch refspec if origin exists
if git remote get-url origin >/dev/null 2>&1; then
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
fi

# 7. Clean existing root directory files (except .git)
find . -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +

# 8. Add primary worktree for current branch
git worktree add "$CURRENT_DIR" "$CURRENT_BRANCH"

# Make primary worktree pointers relative for host/container portability
echo "gitdir: ../.git/worktrees/$CURRENT_DIR" > "$CURRENT_DIR/.git"
echo "../../../$CURRENT_DIR/.git" > ".git/worktrees/$CURRENT_DIR/gitdir"

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

# Configure devcontainer mounts if .devcontainer exists in primary worktree
if [ -d "$CURRENT_DIR/.devcontainer" ]; then
    echo "🐳 Found .devcontainer in './$CURRENT_DIR', configuring devcontainer.override.json for git mounts..."
    DC_IMAGE=$(detect_devcontainer_image "$CURRENT_DIR")
    cat << EOF > "$CURRENT_DIR/.devcontainer/devcontainer.override.json"
{
  "image": "$DC_IMAGE",
  "workspaceFolder": "/workspaces/\${localWorkspaceFolderBasename}",
  "workspaceMount": "source=\${localWorkspaceFolder},target=/workspaces/\${localWorkspaceFolderBasename},type=bind,consistency=cached",
  "mounts": [
    "source=\${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $CURRENT_DIR/.devcontainer/devcontainer.override.json (image: $DC_IMAGE)"
fi

# 9. Restore backed up .env files into the primary worktree
if [ -d "$TMP_UNTRACKED" ]; then
    find "$TMP_UNTRACKED" -type f | while read -r f; do
        rel="${f#$TMP_UNTRACKED/}"
        mkdir -p "$CURRENT_DIR/$(dirname "$rel")"
        cp "$f" "$CURRENT_DIR/$rel"
    done
    rm -rf "$TMP_UNTRACKED"
fi

# 10. Install wt-add.sh script into the wrapper directory
SCRIPT_SOURCE="$(dirname "$0")/wt-add.sh"
if [ -f "$SCRIPT_SOURCE" ]; then
    cp "$SCRIPT_SOURCE" ./wt-add.sh
    chmod +x ./wt-add.sh
else
    # Fallback: embedded wt-add.sh creation
    cat << 'WT_ADD_EOF' > ./wt-add.sh
#!/bin/bash
set -e

BRANCH_NAME=$1
BASE_BRANCH=${2:-}

if [ -z "$BRANCH_NAME" ]; then
    echo "❌ Error: Please provide a branch name."
    echo "Usage: ./wt-add.sh <branch-name> [base-branch]"
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
echo "gitdir: ../.git/worktrees/$DIR_NAME" > "$DIR_NAME/.git"
echo "../../../$DIR_NAME/.git" > ".git/worktrees/$DIR_NAME/gitdir"

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

# Configure devcontainer mounts if .devcontainer exists
if [ -d "$DIR_NAME/.devcontainer" ]; then
    echo "🐳 Found .devcontainer in './$DIR_NAME', configuring devcontainer.override.json for git mounts..."
    DC_IMAGE=$(detect_devcontainer_image "$DIR_NAME" "$BASE_DIR_NAME")
    cat << EOF > "$DIR_NAME/.devcontainer/devcontainer.override.json"
{
  "image": "$DC_IMAGE",
  "workspaceFolder": "/workspaces/\${localWorkspaceFolderBasename}",
  "workspaceMount": "source=\${localWorkspaceFolder},target=/workspaces/\${localWorkspaceFolderBasename},type=bind,consistency=cached",
  "mounts": [
    "source=\${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $DIR_NAME/.devcontainer/devcontainer.override.json (image: $DC_IMAGE)"
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"
WT_ADD_EOF
    chmod +x ./wt-add.sh
fi

echo "✨ Successfully converted to bare worktree layout!"
echo "📁 Layout:"
echo "   ├── .git/"
echo "   ├── wt-add.sh"
echo "   └── $CURRENT_DIR/"
echo ""
echo "👉 To add a new worktree: ./wt-add.sh <branch-name>"
