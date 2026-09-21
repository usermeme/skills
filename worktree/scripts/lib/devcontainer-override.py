#!/usr/bin/env python3
"""Generate .devcontainer/devcontainer.override.json for a bare-worktree checkout.

Preserves all original devcontainer.json settings and configures the
workspaceFolder/workspaceMount plus the usermeme worktree devcontainer feature
(ghcr.io/usermeme/devcontainer-features/worktree:1) that mounts the parent bare
.git repository, configures Git safe.directory, sets up monorepo cache permissions,
and auto-repairs container worktree pointers. Exits silently when the target
worktree has no devcontainer config.

Usage: devcontainer-override.py <target-worktree> [base-worktree]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WORKTREE_FEATURE = "ghcr.io/usermeme/devcontainer-features/worktree:1"
WORKSPACE_FOLDER = "/workspaces/${localWorkspaceFolderBasename}"
WORKSPACE_MOUNT = (
    "source=${localWorkspaceFolder},"
    "target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached"
)
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


def has_worktree_feature(features: dict) -> bool:
    for feat in features:
        if "devcontainer-features/worktree" in feat or feat.endswith("/worktree") or feat == "worktree":
            return True
    return False


def filter_git_mounts(mounts: list) -> list:
    """Removes manual /workspaces/.git mounts since the worktree feature provides it."""
    cleaned = []
    for mount in mounts:
        if isinstance(mount, str) and "target=/workspaces/.git" in mount:
            continue
        if isinstance(mount, dict) and mount.get("target") == "/workspaces/.git":
            continue
        cleaned.append(mount)
    return cleaned


def ensure_git_exclude(target: Path) -> None:
    """Ensure .devcontainer/devcontainer.override.json is in .git/info/exclude of the bare repo."""
    exclude_file = target.parent / ".git" / "info" / "exclude"
    if exclude_file.parent.is_dir():
        pattern = ".devcontainer/devcontainer.override.json"
        try:
            content = exclude_file.read_text() if exclude_file.exists() else ""
            lines = [line.strip() for line in content.splitlines()]
            if pattern not in lines:
                with open(exclude_file, "a") as f:
                    if content and not content.endswith("\n"):
                        f.write("\n")
                    f.write(f"{pattern}\n")
        except OSError:
            pass


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

    features = data.get("features")
    if not isinstance(features, dict):
        features = {}
    if not has_worktree_feature(features):
        features[WORKTREE_FEATURE] = {}
    data["features"] = features

    if "mounts" in data and isinstance(data["mounts"], list):
        data["mounts"] = filter_git_mounts(data["mounts"])

    if "image" not in data and "build" not in data and "dockerComposeFile" not in data:
        data["image"] = FALLBACK_IMAGE

    out_file = target / ".devcontainer" / "devcontainer.override.json"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(data, indent=2) + "\n")
    ensure_git_exclude(target)
    print(f"  ✅ Created: {out_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
