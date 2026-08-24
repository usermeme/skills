---
name: worktree
description: Fully automated management of git repositories using bare worktrees — automatic conversion/parsing of standard git repos into bare worktree layout (.bare, .git pointer, main/master worktree), creating sibling worktrees via .wt-add.sh with automatic recursive .env copying (ignoring node_modules), cloning new repos into bare worktrees, switching contexts, and automated cleanup. Use whenever the user asks to work with worktrees, convert a repository to worktrees, add or create a worktree for a branch/feature, or clean up worktrees.
---

# Automated Bare Git Worktrees

Manage and operate git repositories using bare worktrees with zero manual steps. The repository is structured with a central bare `.git`, a `.git` pointer, a primary `main`/`master` worktree, and sibling feature worktrees created side-by-side.

```text
my-project/
├── .bare/                # Bare git repository
├── .git                  # Pointer file: "gitdir: ./.bare"
├── .wt-add.sh            # Automated worktree creation & .env copy script
├── main/                 # Primary worktree (tracking origin/main or origin/master)
├── feat-auth/            # Sibling worktree (feature branch)
└── fix-login-bug/        # Sibling worktree (bugfix branch)
```

---

## 1. Automated Operations

Execute the bundled scripts directly. Never ask the user to run manual git renames or copy commands.

### Convert an Existing Normal Repo to Bare Worktrees

When the user asks to parse or convert an existing standard repository into the worktree layout:

Run [convert-repo-to-worktree.sh](./scripts/convert-repo-to-worktree.sh):

```bash
<skill-path>/scripts/convert-repo-to-worktree.sh [repo-path]
```

**Automated actions performed by the script:**
1. Backs up any untracked `.env*` files across all subdirectories.
2. Moves `.git` to `.bare` and configures `core.bare = true`.
3. Creates the `.git` pointer file (`gitdir: ./.bare`) at the wrapper root.
4. Configures `remote.origin.fetch` to track all remote branches.
5. Cleans root files and creates the primary worktree (`main` or `master`).
6. Restores all `.env*` files into the primary worktree with full directory hierarchy.
7. Installs and permissions [`.wt-add.sh`](./scripts/.wt-add.sh) into the wrapper root.

---

### Add a New Worktree (`.wt-add.sh`)

When the user asks to create a new branch or worktree:

Run [`.wt-add.sh`](./scripts/.wt-add.sh) from the wrapper root:

```bash
./.wt-add.sh <branch-name> [base-branch]
```

**Automated actions performed by the script:**
1. Checks out the branch (or creates a new branch off `main`/`master`) into `./<branch-name>`.
2. Recursively scans `main/` for all `.env*` files (e.g. `.env`, `.env.local`, nested app configs).
3. Recreates the directory hierarchy in the new worktree and copies the `.env*` files.
4. Skips `node_modules` and `.git`.

---

### Clone a New Repo into Bare Worktrees

When cloning a new repository from a remote URL:

Run [clone-bare-repo.sh](./scripts/clone-bare-repo.sh):

```bash
<skill-path>/scripts/clone-bare-repo.sh <repo-url> [target-directory]
```

**Automated actions performed by the script:**
1. Clones `--bare` into `<target-directory>/.bare`.
2. Creates the root `.git` pointer file and configures remote refspecs.
3. Initializes the primary worktree (`main` or `master`).
4. Installs [`.wt-add.sh`](./scripts/.wt-add.sh) into the wrapper root.

---

### Remove / Cleanup a Worktree

When a branch is merged or finished:

```bash
# 1. Remove the worktree folder and metadata
git worktree remove <branch-name>

# 2. Prune any stale references
git worktree prune

# 3. Delete local branch if merged
git branch -d <branch-name>
```

---

## 2. Invariants & Safety Rails

- **No manual file wrangling**: Always use the automated scripts to guarantee `.env` file preservation and proper gitdir metadata links.
- **One worktree per branch**: Git prevents checking out the same branch in multiple worktrees at once.
- **Never commit `.env` files**: Untracked `.env` files copied by `.wt-add.sh` remain untracked in git ([git-hygiene](../git-hygiene/SKILL.md)).
- **Keep base worktree updated**: Pull `main/` before branching:
  ```bash
  cd main && git pull && cd ..
  ```
- **Port isolation**: When running dev servers across multiple sibling worktrees, run them on separate ports.
