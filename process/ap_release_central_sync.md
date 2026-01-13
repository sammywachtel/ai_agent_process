# Agent Process Central Repo Sync

This file configures syncing `.agent_process` changes to a central repository after releases.

**This step is OPTIONAL** - the `/ap_release` command checks for this file and only executes the sync if it exists.

---

## Configuration

```
CENTRAL_REPO_PATH: <CENTRAL_REPO_PATH>
PROJECT_FOLDER: <PROJECT_FOLDER>
```

---

## How It Works

When this file exists, `/ap_release` (Step 9.5) will:

1. Navigate to `CENTRAL_REPO_PATH`
2. Check for changes in `PROJECT_FOLDER/` (subdirectory of central repo)
3. Commit and push any changes to the central repo
4. Return to the project directory

**Central repo structure:**
```
CENTRAL_REPO_PATH/
  PROJECT_FOLDER/
    ├── orchestration/
    ├── process/
    ├── work/
    └── ...
```

The project's `.agent_process/` symlinks directly to `CENTRAL_REPO_PATH/PROJECT_FOLDER/`.

See `ap_release.md` Step 9.5 for full details.

---

## Setup

This file is typically created during installation when you answer "yes" to central repo sync.

To manually configure:
1. Replace `<CENTRAL_REPO_PATH>` with your central repo path (e.g., `~/repos/agent-process-central`)
2. Replace `<PROJECT_FOLDER>` with this project's folder name in the central repo
