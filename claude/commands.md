# Claude Code Commands

Copy the command files from this directory into your project's `.claude/commands/` folder.

## Available Commands

### Iteration Workflow

- **ap_exec.md** – `/ap_exec <scope> <iteration>` – Performs implementation and validation for a single iteration, then triggers `/ap_iteration_results`.

- **ap_iteration_results.md** – `/ap_iteration_results <scope> <iteration>` – Documents iteration results using `test-output.txt`.

### Release Workflow

- **ap_release.md** – `/ap_release <mode> [version-type]` – Updates changelog, creates PR, and optionally tags a release. Run after orchestrator approves scope work.

  **Modes:**
  - `pr` – Add to [Unreleased] changelog, create PR, no tag
  - `beta` – Move [Unreleased] to beta version, create beta tag (vX.Y.Z-beta.N), create PR
  - `release patch|minor|major` – Move [Unreleased] to new version, update version files, tag release

- **ap_changelog_init.md** – `/ap_changelog_init [starting-version]` – Initialize CHANGELOG.md from git history for projects that haven't been tracking releases. One-time setup command.

  **What it does:**
  - Analyzes git tags and commit history
  - Creates historical summary grouped by era/milestone
  - Sets up [Unreleased] section for future `/ap_release` use
  - Links to full git history for transparency

## Setup

After copying, restart Claude Code (or reload commands) so the new shortcuts are available.
