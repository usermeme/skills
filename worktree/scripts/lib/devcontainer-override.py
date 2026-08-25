#!/usr/bin/env python3
"""Generate .devcontainer/devcontainer.override.json for a bare-worktree checkout.

Preserves all original devcontainer.json settings and merges in the
workspaceFolder/workspaceMount configuration plus the ../.git bind mount that
the bare worktree layout needs. Exits silently when the target worktree has no
devcontainer config.

Usage: devcontainer-override.py <target-worktree> [base-worktree]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WORKSPACE_FOLDER = "/workspaces/${localWorkspaceFolderBasename}"
WORKSPACE_MOUNT = (
    "source=${localWorkspaceFolder},"
    "target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached"
)
GIT_MOUNT = "source=${localWorkspaceFolder}/../.git,target=/workspaces/.git,type=bind"
FALLBACK_IMAGE = "mcr.microsoft.com/devcontainers/javascript-node:24"


def find_config_file(target: Path, base: Path | None) -> Path | None:
    candidates = [
        target / ".devcontainer" / "devcontainer.json",
        target / ".devcontainer.json",
    ]
    if base is not None:
        candidates += [
            base / ".devcontainer" / "devcontainer.json",
            base / ".devcontainer.json",
        ]
    candidates.append(target / ".devcontainer" / "devcontainer.override.json")
    if base is not None:
        candidates.append(base / ".devcontainer" / "devcontainer.override.json")
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def parse_jsonc(text: str) -> dict:
    """Parse devcontainer JSONC: strips // and /* */ comments and trailing commas."""
    pattern = r'("(?:\\.|[^"\\])*")|(//[^\n]*)|(/\*.*?\*/)'
    cleaned = re.sub(pattern, lambda m: m.group(1) or "", text, flags=re.DOTALL)
    cleaned = re.sub(r",\s*([}\]])", r"\1", cleaned)
    try:
        data = json.loads(cleaned) if cleaned.strip() else {}
    except ValueError:
        data = {}
    return data if isinstance(data, dict) else {}


def has_git_mount(mounts: list) -> bool:
    for mount in mounts:
        if isinstance(mount, str) and "target=/workspaces/.git" in mount:
            return True
        if isinstance(mount, dict) and mount.get("target") == "/workspaces/.git":
            return True
    return False


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: devcontainer-override.py <target-worktree> [base-worktree]")
        return 1

    target = Path(sys.argv[1])
    base = Path(sys.argv[2]) if len(sys.argv) > 2 else None

    if not (target / ".devcontainer").is_dir() and not (target / ".devcontainer.json").is_file():
        return 0

    print(f"🐳 Found devcontainer config in '{target}', generating devcontainer.override.json...")

    config_file = find_config_file(target, base)
    data = {}
    if config_file is not None:
        try:
            data = parse_jsonc(config_file.read_text())
        except OSError:
            data = {}

    data["workspaceFolder"] = WORKSPACE_FOLDER
    data["workspaceMount"] = WORKSPACE_MOUNT

    mounts = data.get("mounts")
    if not isinstance(mounts, list):
        mounts = []
    if not has_git_mount(mounts):
        mounts.insert(0, GIT_MOUNT)
    data["mounts"] = mounts

    if "image" not in data and "build" not in data and "dockerComposeFile" not in data:
        data["image"] = FALLBACK_IMAGE

    out_file = target / ".devcontainer" / "devcontainer.override.json"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(data, indent=2) + "\n")
    print(f"  ✅ Created: {out_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
