---
name: worktree
description: Fully automated management of git repositories using bare worktrees — convert standard repos into the bare layout (.git + main/ + siblings), clone new repos, create sibling worktrees with wt-add.sh (copies per-repo configured files from .scripts/copy-list and generates devcontainer.override.json with the usermeme worktree devcontainer feature when a devcontainer exists), and clean up. Use whenever the user asks to work with worktrees, convert a repository to worktrees, add or create a worktree for a branch/feature, configure which files are copied into new worktrees, or clean up worktrees.
---

# Automated Bare Git Worktrees

Manage repositories as a central bare `.git` plus sibling worktrees. Helper logic lives in small single-purpose scripts installed into the wrapper root:

```text
my-project/
├── .git/                          # Bare git repository
├── .scripts/
│   ├── copy-list                  # Per-repo config: which files wt-add copies
│   ├── copy-worktree-files.sh     # Copies the files listed in copy-list
│   └── devcontainer-override.py   # Generates devcontainer.override.json
├── wt-add.sh                      # Thin orchestrator: worktree + copy + devcontainer
├── main/                          # Primary worktree
└── feat-auth/                     # Sibling worktree (branch feat/auth)
```

Execute the bundled scripts directly. Never ask the user to run manual git renames or copy commands.

## 1. Operations

### Convert an existing repo

```bash
<skill-path>/scripts/convert-repo-to-worktree.sh [repo-path]
```

- Requires a clean tracked tree (untracked files are fine).
- Preserves **all** untracked files (env files, local configs, `node_modules`) by moving the whole working tree into the primary worktree — nothing is deleted, no reinstall needed.
- Installs `wt-add.sh` + `.scripts/`, generates the devcontainer override with the worktree feature when a devcontainer exists.
- **Afterwards, run the copy-list interview (section 2).**

### Clone a new repo

```bash
<skill-path>/scripts/clone-bare-repo.sh <repo-url> [target-directory]
```

Clones bare, creates the default-branch worktree, installs `wt-add.sh` + `.scripts/`, generates the devcontainer override. **Afterwards, run the copy-list interview (section 2).**

### Add a worktree

Run from the wrapper root:

```bash
./wt-add.sh <branch-name> [base-branch]
```

1. Validates the branch name; folder name slugs slashes (`feat/x` → `./feat-x`, branch stays `feat/x`).
2. Fetches origin (offline-safe), then checks out an existing local/remote branch or creates a new one off the base (`main`/`master` auto-detected).
3. Sets relative `gitdir` pointers for host/container portability.
4. Runs `.scripts/copy-worktree-files.sh` — copies the files listed in `.scripts/copy-list` from the base worktree, recreating the directory hierarchy.
5. Runs `.scripts/devcontainer-override.py` — when a devcontainer config exists, writes `.devcontainer/devcontainer.override.json` preserving all original settings, configuring `workspaceFolder` and `workspaceMount`, and injecting the `ghcr.io/usermeme/devcontainer-features/worktree:1` feature.

### Update installed scripts

After the skill's scripts change, refresh a wrapper's installed copies (the existing `copy-list` is kept):

```bash
<skill-path>/scripts/install-wt-scripts.sh <wrapper-root>
```

### Remove / cleanup

```bash
git worktree remove --force <dir-name>   # --force needed: copied .env files count as untracked
git worktree prune                       # prune stale references
git branch -d <branch-name>              # delete local branch if merged
```

Before removing, confirm the worktree has no un-pushed work: `git -C <dir-name> status`.

## 2. Per-repo copy config — `.scripts/copy-list`

`wt-add.sh` copies only what this file lists (the installed default is `.env` / `.env.*`). One entry per line:

```text
# Name patterns match recursively by file name:
.env
.env.*
staging.json
# "./" prefix = one exact file, relative to the worktree root:
./config/prod.json
```

Blank lines and `#` comments are ignored; `node_modules/` and `.git/` are always excluded.

### Copy-list interview — ALWAYS run after convert/clone

The right copy-list differs per repo, so ask the user instead of assuming:

1. Detect candidates — untracked-but-ignored files in the base worktree are usually the local configs worth copying:
   ```bash
   git -C <base-worktree> ls-files --others --ignored --exclude-standard --directory | grep -v '/$'
   ```
2. Ask the user (AskUserQuestion, multiSelect) which of the detected files/patterns new worktrees should receive, with `.env` / `.env.*` as the recommended default option.
3. Write the chosen patterns to `.scripts/copy-list`, keeping the format comment header.

When the user later says "also copy X in this repo", add the pattern to that repo's `.scripts/copy-list`. If `.scripts/` is missing in an older wrapper, re-run `install-wt-scripts.sh` first.

## 3. Devcontainer integration — `usermeme/devcontainer-features`

When a worktree contains a `.devcontainer` configuration, `.scripts/devcontainer-override.py` generates `.devcontainer/devcontainer.override.json` referencing the official worktree feature from [usermeme/devcontainer-features](https://github.com/usermeme/devcontainer-features):

```json
{
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached",
  "features": {
    "ghcr.io/usermeme/devcontainer-features/worktree:1": {}
  }
}
```

### What `ghcr.io/usermeme/devcontainer-features/worktree:1` does:
- **Mounts the parent `.git`**: Binds `${localWorkspaceFolder}/../.git` to `/workspaces/.git` so containers can access the central bare repository.
- **Configures Git `safe.directory`**: Automatically runs `git config --global --add safe.directory "*"` to eliminate ownership mismatch errors between host UID and container user UID.
- **Ensures monorepo cache permissions**: Ensures `/workspaces/.nx` cache directory exists with appropriate permissions.
- **Auto-repairs container `gitdir` pointers**: If `.git` contains absolute host paths or broken relative links, the feature's `setup-worktree.sh` post-create hook detects and points `.git` to `/workspaces/.git/worktrees/<dir>` and runs `git worktree repair`.

### Feature options:
| Option | Description | Type | Default |
|---|---|---|---|
| `safeDirectory` | Configure Git `safe.directory "*"` for all paths | boolean | `true` |
| `setupNx` | Ensure `/workspaces/.nx` cache directory exists with proper permissions | boolean | `true` |

Additional features from [usermeme/devcontainer-features](https://github.com/usermeme/devcontainer-features) (such as `dotfiles`, `pnpm`, `yarn`, `antigravity`, `neovim`, and `node-modules-volume`) can also be added into `.devcontainer/devcontainer.override.json` as needed.

## 4. Invariants & safety rails

- **Relative gitdir pointers** (`../.git/worktrees/...` / `../../../<dir>/.git`) keep worktrees portable across host, Docker, and devcontainers.
- **Devcontainer feature**: Worktree devcontainer support is powered by `ghcr.io/usermeme/devcontainer-features/worktree:1`, ensuring the bare `.git` bind mount, `safe.directory`, cache permissions, and worktree pointer repair are managed reliably without manual configuration drift.
- **Local overrides stay untracked**: `.devcontainer/devcontainer.override.json` and copied config files must never be committed ([git-hygiene](../git-hygiene/SKILL.md)). They are excluded locally in `.git/info/exclude` (and should be listed in `.gitignore` / `~/.config/git/ignore`).
- **One worktree per branch** — enforced by git.
- **Keep the base updated**: `cd main && git pull` before branching.
- **Port isolation**: run dev servers in sibling worktrees on separate ports.
