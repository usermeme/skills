#!/bin/bash
set -e

# Copies the files listed in .scripts/copy-list (next to this script) from a
# base worktree into a target worktree, recreating the directory hierarchy.
#
# copy-list entries, one per line:
#   <name-pattern>     matched recursively by file name (e.g. ".env*", "staging.json")
#   ./<relative/path>  one exact file relative to the worktree root
# Blank lines and # comments are ignored. node_modules/ and .git/ are always excluded.
#
# Usage: copy-worktree-files.sh <base-worktree> <target-worktree>

BASE_DIR_NAME="$1"
TARGET_DIR_NAME="$2"

if [ -z "$BASE_DIR_NAME" ] || [ -z "$TARGET_DIR_NAME" ]; then
    echo "Usage: copy-worktree-files.sh <base-worktree> <target-worktree>"
    exit 1
fi

if [ ! -d "$BASE_DIR_NAME" ]; then
    echo "⚠️ Base worktree '$BASE_DIR_NAME' not found. Skipped file copy."
    exit 0
fi

if [ ! -d "$TARGET_DIR_NAME" ]; then
    echo "❌ Error: Target worktree '$TARGET_DIR_NAME' not found."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COPY_LIST="$SCRIPT_DIR/copy-list"
BASE_DIR="$(cd "$BASE_DIR_NAME" && pwd)"
TARGET_DIR="$(cd "$TARGET_DIR_NAME" && pwd)"

name_patterns=()
exact_paths=()

if [ -f "$COPY_LIST" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # trim surrounding whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        case "$line" in
            "" | \#*) continue ;;
            ./*)
                rel="${line#./}"
                case "$rel" in
                    *..*)
                        echo "  ⚠️ Ignoring unsafe path in copy-list: $line"
                        continue
                        ;;
                esac
                exact_paths+=("$rel")
                ;;
            *) name_patterns+=("$line") ;;
        esac
    done < "$COPY_LIST"
else
    echo "ℹ️ No copy-list at '$COPY_LIST' — defaulting to .env / .env.* files."
    name_patterns=(".env" ".env.*")
fi

echo "🔍 Copying configured files from '$BASE_DIR_NAME' into '$TARGET_DIR_NAME'..."

copied=0

copy_file() {
    local rel="$1"
    mkdir -p "$TARGET_DIR/$(dirname "$rel")"
    cp "$BASE_DIR/$rel" "$TARGET_DIR/$rel"
    echo "  ✅ Copied: $rel"
    copied=$((copied + 1))
}

if [ ${#name_patterns[@]} -gt 0 ]; then
    find_expr=()
    for pattern in "${name_patterns[@]}"; do
        if [ ${#find_expr[@]} -gt 0 ]; then
            find_expr+=(-o)
        fi
        find_expr+=(-name "$pattern")
    done

    while IFS= read -r -d '' file; do
        copy_file "${file#"$BASE_DIR"/}"
    done < <(find "$BASE_DIR" -type f \( "${find_expr[@]}" \) \
        -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
fi

if [ ${#exact_paths[@]} -gt 0 ]; then
    for rel in "${exact_paths[@]}"; do
        if [ -f "$BASE_DIR/$rel" ]; then
            copy_file "$rel"
        else
            echo "  ⚠️ In copy-list but not found in base worktree: ./$rel"
        fi
    done
fi

if [ "$copied" -eq 0 ]; then
    echo "ℹ️ No matching files found in '$BASE_DIR_NAME'."
fi
