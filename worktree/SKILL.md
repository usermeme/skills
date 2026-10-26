---
name: worktree
description: Automated management of bare git worktrees, .env/config file syncing, and devcontainer overrides. Use when converting or cloning repos to bare worktrees, adding/removing worktrees, or configuring copied files.
---

# Automated Bare Git Worktrees

Manage repositories as a central bare `.git` plus sibling worktrees. Helper logic lives in small single-purpose scripts installed into the wrapper root:

```text
my-project/
├── .git/                          # Bare git repository
├── .scripts/
│   ├── copy-list                  # Per-repo config: which files wt-add copies
│   └── copy-worktree-files.sh     # Copies the files listed in copy-list
├── wt-add.sh                      # Thin orchestrator: worktree + copy
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
- Installs `wt-add.sh` + `.scripts/`.
- **Afterwards, run the copy-list interview (section 2)** and, when the repo has a devcontainer, create the override file (section 3).

### Clone a new repo

```bash
<skill-path>/scripts/clone-bare-repo.sh <repo-url> [target-directory]
```

Clones bare, creates the default-branch worktree, and installs `wt-add.sh` + `.scripts/`. **Afterwards, run the copy-list interview (section 2)** and, when the repo has a devcontainer, create the override file (section 3).

### Add a worktree

Run from the wrapper root:

```bash
./wt-add.sh <branch-name> [base-branch]
```

1. Validates the branch name; folder name slugs slashes (`feat/x` → `./feat-x`, branch stays `feat/x`).
2. Fetches origin (offline-safe), then checks out an existing local/remote branch or creates a new one off the base (`main`/`master` auto-detected).
3. Sets relative `gitdir` pointers for host/container portability.
4. Runs `.scripts/copy-worktree-files.sh` — copies the files listed in `.scripts/copy-list` from the base worktree, recreating the directory hierarchy. This includes `.devcontainer/devcontainer.override.json` when it is listed and exists in the base worktree (it is in the default copy-list).

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
3. Write the chosen patterns to `.scripts/copy-list`, keeping the format comment header. If the repo has a devcontainer, keep the `./.devcontainer/devcontainer.override.json` entry (section 3) in the list.

When the user later says "also copy X in this repo", add the pattern to that repo's `.scripts/copy-list`. If `.scripts/` is missing in an older wrapper, re-run `install-wt-scripts.sh` first.

## 3. Devcontainer integration — `usermeme/devcontainer-features`

There is no override generator script. When a repo has a devcontainer, the override file is created **manually, once, in the base worktree**, and `wt-add.sh` propagates it to every new worktree through the copy-list (the default copy-list already contains `./.devcontainer/devcontainer.override.json`).

### Setup (per repo, one-time)

1. Create `<base-worktree>/.devcontainer/devcontainer.override.json`. Start from the original `devcontainer.json` settings (so nothing is lost), then set `workspaceFolder` / `workspaceMount` and add the worktree feature from [usermeme/devcontainer-features](https://github.com/usermeme/devcontainer-features):

   ```json
   {
     "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
     "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind,consistency=cached",
     "features": {
       "ghcr.io/usermeme/devcontainer-features/worktree:1": {}
     }
   }
   ```

   Notes:
   - Remove any manual `target=/workspaces/.git` mounts — the worktree feature provides that mount.
   - If the config has no `image` / `build` / `dockerComposeFile` of its own, add a fallback such as `"image": "mcr.microsoft.com/devcontainers/javascript-node:24"`.
2. Make sure `./.devcontainer/devcontainer.override.json` is in `.scripts/copy-list` (the installed default already lists it).
3. Keep it untracked — `install-wt-scripts.sh` adds `.devcontainer/devcontainer.override.json` to the bare repo's `.git/info/exclude`.

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
- **Local overrides stay untracked**: `.devcontainer/devcontainer.override.json` and copied config files must never be committed ([git-hygiene](../git-hygiene/SKILL.md)). They are excluded locally in `.git/info/exclude` (and should be listed in `.gitignore` / `~/.config/git/ignore`).
- **One worktree per branch** — enforced by git.
- **Keep the base updated**: `cd main && git pull` before branching.
- **Port isolation**: run dev servers in sibling worktrees on separate ports.
