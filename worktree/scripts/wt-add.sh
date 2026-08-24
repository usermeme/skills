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

# Helper function to generate devcontainer.override.json preserving original settings and merging mounts
generate_devcontainer_override() {
    local target_dir="$1"
    local base_dir="${2:-}"
    local dc_file=""

    if [ -f "$target_dir/.devcontainer/devcontainer.json" ]; then
        dc_file="$target_dir/.devcontainer/devcontainer.json"
    elif [ -f "$target_dir/.devcontainer.json" ]; then
        dc_file="$target_dir/.devcontainer.json"
    elif [ -n "$base_dir" ] && [ -f "$base_dir/.devcontainer/devcontainer.json" ]; then
        dc_file="$base_dir/.devcontainer/devcontainer.json"
    elif [ -n "$base_dir" ] && [ -f "$base_dir/.devcontainer.json" ]; then
        dc_file="$base_dir/.devcontainer.json"
    elif [ -f "$target_dir/.devcontainer/devcontainer.override.json" ]; then
        dc_file="$target_dir/.devcontainer/devcontainer.override.json"
    elif [ -n "$base_dir" ] && [ -f "$base_dir/.devcontainer/devcontainer.override.json" ]; then
        dc_file="$base_dir/.devcontainer/devcontainer.override.json"
    fi

    mkdir -p "$target_dir/.devcontainer"
    local out_file="$target_dir/.devcontainer/devcontainer.override.json"
    local generated=false

    # 1. Try python3
    if [ "$generated" = false ] && command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, re, sys

dc_file = sys.argv[1] if len(sys.argv) > 1 else ""
content = ""
if dc_file:
    try:
        with open(dc_file, "r") as f:
            content = f.read()
    except Exception:
        pass

pattern = r"""("(?:\\.|[^"\\])*")|(//[^\n]*)|(/\*.*?\*/)"""
cleaned = re.sub(pattern, lambda m: m.group(1) if m.group(1) else "", content, flags=re.VERBOSE | re.DOTALL)
cleaned = re.sub(r",\s*([}\]])", r"\1", cleaned)

try:
    data = json.loads(cleaned) if cleaned.strip() else {}
except Exception:
    data = {}

if not isinstance(data, dict):
    data = {}

data["workspaceFolder"] = "/workspaces/${localWorkspaceFolderBasename}"
data["workspaceMount"] = "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached"

git_mount = "source=${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"
raw_mounts = data.get("mounts", [])
if not isinstance(raw_mounts, list):
    raw_mounts = []

has_git_mount = False
for m in raw_mounts:
    if isinstance(m, str) and ("target=/workspaces/.git" in m or "target=\"/workspaces/.git\"" in m):
        has_git_mount = True
        break
    elif isinstance(m, dict) and m.get("target") == "/workspaces/.git":
        has_git_mount = True
        break

if not has_git_mount:
    raw_mounts.insert(0, git_mount)

data["mounts"] = raw_mounts

if "image" not in data and "build" not in data and "dockerComposeFile" not in data:
    data["image"] = "mcr.microsoft.com/devcontainers/javascript-node:24"

print(json.dumps(data, indent=2))
' "$dc_file" > "$out_file" 2>/dev/null && generated=true || true
    fi

    # 2. Try node
    if [ "$generated" = false ] && command -v node >/dev/null 2>&1; then
        node -e '
const fs = require("fs");
const dcFile = process.argv[1] || "";
let content = "";
if (dcFile) {
  try { content = fs.readFileSync(dcFile, "utf8"); } catch(e) {}
}

let data = {};
try {
  const cleaned = content
    .replace(/("(?:\\.|[^"\\])*")|(\/\/[^\n]*)|(\/\*[\s\S]*?\*\/)/g, (m, s) => s || "")
    .replace(/,\s*([}\]])/g, "$1");
  if (cleaned.trim()) data = JSON.parse(cleaned);
} catch(e) {}

if (typeof data !== "object" || data === null || Array.isArray(data)) {
  data = {};
}

data.workspaceFolder = "/workspaces/${localWorkspaceFolderBasename}";
data.workspaceMount = "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached";

const gitMount = "source=${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind";
let mounts = Array.isArray(data.mounts) ? data.mounts : [];
let hasGitMount = mounts.some(m =>
  (typeof m === "string" && (m.includes("target=/workspaces/.git") || m.includes("target=\"/workspaces/.git\""))) ||
  (typeof m === "object" && m !== null && m.target === "/workspaces/.git")
);

if (!hasGitMount) {
  mounts.unshift(gitMount);
}
data.mounts = mounts;

if (!data.image && !data.build && !data.dockerComposeFile) {
  data.image = "mcr.microsoft.com/devcontainers/javascript-node:24";
}

fs.writeFileSync(process.argv[2], JSON.stringify(data, null, 2));
' "$dc_file" "$out_file" 2>/dev/null && generated=true || true
    fi

    # 3. Try jq
    if [ "$generated" = false ] && command -v jq >/dev/null 2>&1; then
        if [ -n "$dc_file" ] && [ -f "$dc_file" ]; then
            sed -e 's,//.*$,,g' -e 's,/\*.*\*/,,g' "$dc_file" | jq '
                . + {
                  workspaceFolder: "/workspaces/${localWorkspaceFolderBasename}",
                  workspaceMount: "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached",
                  mounts: (["source=${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"] + (.mounts // [] | map(select(tostring | contains("target=/workspaces/.git") | not))))
                }
            ' > "$out_file" 2>/dev/null && generated=true || true
        fi
    fi

    # 4. Fallback if still not generated
    if [ "$generated" = false ]; then
        cat << 'EOF_OVERRIDE' > "$out_file"
{
  "image": "mcr.microsoft.com/devcontainers/javascript-node:24",
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached",
  "mounts": [
    "source=${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"
  ]
}
EOF_OVERRIDE
    fi
}

# 6. Configure devcontainer mounts if .devcontainer or devcontainer.json exists
if [ -d "$DIR_NAME/.devcontainer" ] || [ -f "$DIR_NAME/.devcontainer.json" ]; then
    echo "🐳 Found .devcontainer in './$DIR_NAME', configuring devcontainer.override.json for git mounts..."
    generate_devcontainer_override "$DIR_NAME" "$BASE_DIR_NAME"
    echo "  ✅ Created: $DIR_NAME/.devcontainer/devcontainer.override.json"
fi

echo "🎉 Worktree '$BRANCH_NAME' is ready at './$DIR_NAME'!"

