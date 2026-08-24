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
git clone --bare "$REPO_URL" .git

# 2. Configure fetch refspec for all remote branches
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin

# 3. Detect default branch (main or master)
DEFAULT_BRANCH="main"
if git show-ref --verify --quiet refs/remotes/origin/master && ! git show-ref --verify --quiet refs/remotes/origin/main; then
    DEFAULT_BRANCH="master"
fi

# 4. Create primary worktree
git worktree add "$DEFAULT_BRANCH"

# Make primary worktree pointers relative for host/container portability
echo "gitdir: ../.git/worktrees/$DEFAULT_BRANCH" > "$DEFAULT_BRANCH/.git"
echo "../../../$DEFAULT_BRANCH/.git" > ".git/worktrees/$DEFAULT_BRANCH/gitdir"

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
if [ -d "$DEFAULT_BRANCH/.devcontainer" ]; then
    echo "🐳 Found .devcontainer in './$DEFAULT_BRANCH', configuring devcontainer.override.json for git mounts..."
    DC_IMAGE=$(detect_devcontainer_image "$DEFAULT_BRANCH")
    cat << EOF > "$DEFAULT_BRANCH/.devcontainer/devcontainer.override.json"
{
  "image": "$DC_IMAGE",
  "mounts": [
    "source=\${localWorkspaceFolder}/../.git,target=\${containerWorkspaceFolder}/../.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $DEFAULT_BRANCH/.devcontainer/devcontainer.override.json (image: $DC_IMAGE)"
fi

# 5. Install wt-add.sh helper script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/wt-add.sh" ]; then
    cp "$SCRIPT_DIR/wt-add.sh" ./wt-add.sh
    chmod +x ./wt-add.sh
else
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
  "mounts": [
    "source=\${localWorkspaceFolder}/../.git,target=\${containerWorkspaceFolder}/../.git,type=bind"
  ]
}
EOF
    echo "  ✅ Created: $DIR_NAME/.devcontainer/devcontainer.override.json (image: $DC_IMAGE)"
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"
WT_ADD_EOF
    chmod +x ./wt-add.sh
fi

echo "✨ Repository ready at '$TARGET_DIR'!"
echo "📁 Layout:"
echo "   ├── .git/"
echo "   ├── wt-add.sh"
echo "   └── $DEFAULT_BRANCH/"
echo ""
echo "👉 To add a new worktree: cd $TARGET_DIR && ./wt-add.sh <branch-name>"
