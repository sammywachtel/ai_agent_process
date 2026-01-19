---
description: Update changelog, create PR, and optionally tag a release
argument-hint: [noscope] pr | beta | release [patch|minor|major]
---

## Arguments

**`$1` (context)** - Optional. Use `noscope` to skip scope context and analyze git diff instead.

**`$1` or `$2` (mode)** - Required. One of:
- `pr` - Update changelog under [Unreleased], create PR, no tag
- `beta` - Move [Unreleased] to beta version, create beta tag, create PR
- `release` - Move [Unreleased] to new version, update version files, tag release

**Last arg (version_type)** - Required for `release` mode only:
- `patch` - Bug fixes (1.0.0 → 1.0.1)
- `minor` - New features (1.0.0 → 1.1.0)
- `major` - Breaking changes (1.0.0 → 2.0.0)

**Examples:**
- `/ap_release pr` - Scope mode, PR only
- `/ap_release noscope pr` - No-scope mode, PR only
- `/ap_release release minor` - Scope mode, minor release
- `/ap_release noscope release patch` - No-scope mode, patch release

---

## Your Role

You are the release coordinator. Your job: update version files and changelog, commit changes, create tags (if applicable), and create/update the PR.

**Two context modes:**
- **Scope mode** (default): Reads from `.agent_process/work/` after orchestrator approval
- **No-scope mode** (use `noscope` arg): Analyzes git diff for ad-hoc releases

---

## Mode Reference

| Mode | Updates Changelog | Creates PR | Creates Build Tag | Creates Release Tag | Moves [Unreleased] |
|------|-------------------|------------|-------------------|---------------------|-------------------|
| `pr` | Yes (under Unreleased) | Yes | Yes (`build/N`) | No | No |
| `beta` | Yes | Yes | Yes (`build/N`) | Yes (`vX.Y.Z-beta.N`) | Yes → beta version |
| `release patch` | Yes | Yes | Yes (`build/N`) | Yes (`vX.Y.Z+1`) | Yes → new version |
| `release minor` | Yes | Yes | Yes (`build/N`) | Yes (`vX.Y+1.0`) | Yes → new version |
| `release major` | Yes | Yes | Yes (`build/N`) | Yes (`vX+1.0.0`) | Yes → new version |

**Build tags:** Every mode creates a `build/N` tag (monotonically increasing). This tracks deployable artifacts independently from semantic releases.

**Version types (for `release` mode):**
- `patch` - Bug fixes, no new features (1.0.0 → 1.0.1)
- `minor` - New features, backward compatible (1.0.0 → 1.1.0)
- `major` - Breaking changes (1.0.0 → 2.0.0)

---

## Workflow

### Step 1: Gather Context

**First, check arguments for context mode:**

If `$1` is `noscope`:
```
CONTEXT_MODE=no-scope
MODE=$2
VERSION_TYPE=$3  # if MODE is "release"
```

Otherwise (default):
```
CONTEXT_MODE=scope
MODE=$1
VERSION_TYPE=$2  # if MODE is "release"
```

---

#### Step 1A: Scope Mode (default, no `noscope` argument)

**Read current scope info:**
```bash
cat .agent_process/work/current_iteration.conf
```

**Extract scope and iteration:**
```
SCOPE=<scope_name>
ITERATION=<iteration_name>
CONTEXT_MODE=scope
```

**Read the approved results:**
```
.agent_process/work/<scope>/<iteration>/results.md
```

**Read iteration plan for context:**
```
.agent_process/work/<scope>/iteration_plan.md
```

**From results.md, extract:**
- Summary of what was implemented
- Files that were changed
- Whether this is a new feature, bug fix, or breaking change
- Any user-facing behavior changes

**Skip to Step 1.5.**

---

#### Step 1B: No-Scope Mode (when `noscope` argument provided)

**Set context mode:**
```
SCOPE=none
ITERATION=none
CONTEXT_MODE=no-scope
```

**Analyze changes from git:**
```bash
# Get the default branch name
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Show what's changed vs the default branch
git diff --stat ${DEFAULT_BRANCH}...HEAD

# Show staged changes if on default branch
git diff --stat --cached

# Show unstaged changes
git diff --stat
```

**Review changed files:**
```bash
# List all modified/added files (staged and unstaged)
git status --short
```

**Read key changed files to understand the work:**
- Read modified source files to understand what was implemented
- Look for patterns: new features, bug fixes, refactoring, documentation
- Identify user-facing vs internal changes

**Summarize findings:**
```markdown
## Changes Detected (No-Scope Mode)

**Files changed:** <count>
**Change type:** [feature | fix | refactor | docs | chore]

**Summary:**
- <bullet points describing what changed>

**User-facing:** [Yes/No]
```

**Note:** Without scope context, changelog entries may need more manual refinement. Review the generated entry carefully.

---

### Step 1.5: Create Build Tag (ALL modes)

**Build tags track every release action, regardless of mode.**

Build numbers are monotonically increasing integers that identify deployable artifacts. They're independent from semantic versions - every `pr`, `beta`, and `release` gets a build number.

**Get the next build number:**
```bash
# Find the highest existing build number
LAST_BUILD=$(git tag -l "build/*" | sed 's|build/||' | sort -n | tail -1)

# Handle case where no build tags exist yet
if [ -z "$LAST_BUILD" ]; then
  LAST_BUILD=0
fi

# Calculate next build number
BUILD_NUM=$((LAST_BUILD + 1))

echo "Build number: ${BUILD_NUM}"
```

**Store the build number for later steps:**
```
BUILD_NUM=<calculated value>
```

This build number will be:
- Used in commit message trailers
- Created as a lightweight tag after committing
- Pushed alongside any release tags

**Note:** The actual `build/N` tag is created in Step 8 (after committing), but we calculate the number now to include it in commit messages.

---

### Step 2: Detect Project Structure

**Determine project type and version file locations:**

Examine the repository structure to identify what version files need updating:

```bash
# Check for common version file patterns
ls -la package.json pyproject.toml setup.py VERSION 2>/dev/null
ls -la frontend/package.json backend/pyproject.toml 2>/dev/null
```

**Project Type Detection:**

| Structure Found | Project Type | Version Files to Update |
|-----------------|--------------|------------------------|
| `pyproject.toml` only | Python library | `pyproject.toml` |
| `setup.py` only | Python library (legacy) | `setup.py`, `<pkg>/__init__.py` |
| `package.json` only | TypeScript/Node | `package.json` |
| `frontend/package.json` | Full-stack with frontend | `frontend/package.json` + backend version |
| `frontend/` + `backend/pyproject.toml` | TS frontend + Python backend | Both `frontend/package.json` and `backend/pyproject.toml` |
| `frontend/` + `backend/package.json` | TS frontend + Node backend | Both package.json files |

**Changelog location:**
- If `frontend/` exists → User-facing changelog: `CHANGELOG.md` in project root
- If Python library only → `CHANGELOG.md` in project root (developer-facing)
- Always maintain one canonical `CHANGELOG.md` at project root

**Document your detection:**
```markdown
## Project Structure Detected

**Type:** [Python library | TypeScript only | Full-stack TS+Python | etc.]

**Version files to update:**
- `path/to/version/file`

**Changelog:** `CHANGELOG.md`

**User-facing:** [Yes/No - Yes if frontend exists or if library has end users]
```

---

### Step 3: Get Current Version

**Read current version from detected files:**

For `pyproject.toml`:
```bash
grep -E '^version\s*=' pyproject.toml
```

For `package.json`:
```bash
grep '"version"' package.json | head -1
```

For `setup.py`:
```bash
grep -E "version\s*=" setup.py
```

**Parse current version:**
```
Current version: X.Y.Z
```

**Calculate next version (for release mode):**

| Current | Mode | Next Version |
|---------|------|--------------|
| 1.2.3 | `release patch` | 1.2.4 |
| 1.2.3 | `release minor` | 1.3.0 |
| 1.2.3 | `release major` | 2.0.0 |

**For beta mode:**
- If current is `1.2.3` → Tag will be `v1.2.4-beta.1` (next patch + beta)
- If previous beta was `v1.2.4-beta.1` → Next is `v1.2.4-beta.2`

---

### Step 4: Determine Change Type

**Analyze the scope work to categorize:**

| Category | When to Use | Example |
|----------|-------------|---------|
| **Added** | New feature or capability | "Dark mode toggle in settings" |
| **Changed** | Modified existing behavior | "Improved loading performance" |
| **Fixed** | Bug fix | "Session timeout now extends properly" |
| **Removed** | Removed feature | "Deprecated legacy export removed" |
| **Security** | Security fix | "Fixed XSS vulnerability in comments" |
| **Breaking Changes** | API/behavior breaking change | "Config format changed from .ini to .yaml" |

**Draft changelog entry:**

Write a user-facing summary (1-2 sentences max):
- Focus on WHAT changed from user perspective
- Don't mention internal implementation details
- Reference issue/PR number if applicable

**Examples:**

Good:
```
- Added dark mode toggle in Settings → Appearance
- Fixed session timeout not extending on user activity (#142)
- **Breaking:** Config file format changed to YAML (see Migration Guide)
```

Bad (too technical):
```
- Refactored ThemeProvider to use React context
- Fixed race condition in SessionManager.extend()
- Updated config parser to use PyYAML instead of configparser
```

---

### Step 5: Update CHANGELOG.md

**Ensure CHANGELOG.md exists:**

If it doesn't exist, create it:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

```

**For `pr` mode only:**

Append entry to [Unreleased] section under appropriate category:

```markdown
## [Unreleased]

### Added
- Dark mode toggle in Settings → Appearance
- CSV export for usage data

### Fixed
- Session timeout now extends properly on activity (#142)
```

**For `beta` and `release` modes:**

Move [Unreleased] contents to new version header:

For `beta` mode (version includes beta suffix):
```markdown
## [1.3.0-beta.1] - {TODAY'S DATE}

### Added
- Dark mode toggle in Settings → Appearance
- CSV export for usage data

### Fixed
- Session timeout now extends properly on activity (#142)

## [1.2.3] - {PREVIOUS RELEASE DATE}
...
```

For `release` mode (clean version number):
```markdown
## [1.3.0] - {TODAY'S DATE}

### Added
- Dark mode toggle in Settings → Appearance
- CSV export for usage data

### Fixed
- Session timeout now extends properly on activity (#142)

## [1.2.3] - {PREVIOUS RELEASE DATE}
...
```

Then create empty [Unreleased] section:
```markdown
## [Unreleased]

## [1.3.0-beta.1] - {DATE}  // or [1.3.0] for release mode
...
```

---

### Step 5.5: Update USER_CHANGELOG.md (beta and release modes only)

**Purpose:** Generate user-facing release notes for in-app display.

**Only for `beta` and `release` modes** (skip for `pr` mode).

**Check if USER_CHANGELOG.md exists:**
```bash
ls -la USER_CHANGELOG.md 2>/dev/null || echo "Not found"
```

**If USER_CHANGELOG.md does NOT exist:**

Create it with user-friendly transformation of the current changelog entry:

```markdown
# What's New

## Version {VERSION} - {DATE}

{Transform CHANGELOG.md entries into user-friendly language}

### ✨ New Features
- {User-facing description of added features}

### 🔧 Improvements
- {User-facing description of changes}

### 🐛 Bug Fixes
- {User-facing description of fixes}

### ⚠️ Breaking Changes
- {User-facing explanation with migration guidance}
```

**Transformation guidelines:**
- Use "You can now..." instead of "Added feature..."
- Focus on user benefits, not implementation details
- Use emojis for visual appeal (✨🔧🐛⚠️📊🎵)
- Skip internal refactoring or developer-only changes
- Link to documentation where helpful
- Explain breaking changes in terms users understand

**If USER_CHANGELOG.md EXISTS:**

⚠️ **CRITICAL: Do NOT modify existing entries without permission**

1. **Read existing content:**
   ```bash
   cat USER_CHANGELOG.md
   ```

2. **Generate new entry** for current release (same transformation as above)

3. **Show preview to user:**
   ```markdown
   ## Proposed USER_CHANGELOG.md Entry

   ```
   {Show the new entry you generated}
   ```

   This will be prepended to the existing USER_CHANGELOG.md.
   Existing entries will NOT be modified.

   Add this entry? (yes/no)
   ```

4. **Wait for user confirmation**

5. **If yes:** Prepend new entry to USER_CHANGELOG.md (after the `# What's New` header, before existing entries)

6. **If no:** Skip USER_CHANGELOG.md update (only CHANGELOG.md will be updated)

**Example transformation:**

CHANGELOG.md entry:
```markdown
### Added
- Dark mode toggle in settings
- CSV export for usage data

### Fixed
- Session timeout not extending on user activity (#142)
```

USER_CHANGELOG.md entry:
```markdown
## Version 1.3.0 - January 4, 2026

### ✨ New Features
- **Dark Mode**: Switch to dark mode in Settings → Appearance for comfortable viewing in low light
- **Data Export**: Export your session history to CSV for analysis in Excel or Google Sheets

### 🐛 Bug Fixes
- Sessions now properly extend when you're actively working, preventing unexpected timeouts
```

**Location:** `USER_CHANGELOG.md` in project root (same directory as CHANGELOG.md)

---

### Step 6: Update Version Files (release mode only)

**Only for `release` mode - update version in all detected files:**

For `pyproject.toml`:
```toml
[project]
version = "1.3.0"  # Updated from 1.2.3
```

For `package.json`:
```json
{
  "version": "1.3.0"
}
```

For `setup.py`:
```python
setup(
    version="1.3.0",
    ...
)
```

**For full-stack projects, update ALL version files to same version.**

---

### Step 7: Commit Changes

**Stage all changes:**
```bash
# Use git add . to ensure no files are missed
# The scope work should already be complete, so all changes are intentional
git add .

# Verify what's staged (sanity check)
git status --short
```

**Review staged files before committing:**
- Verify only expected files are staged
- Check for any unintended changes (temp files, secrets, etc.)
- If something unexpected is staged, unstage it: `git reset HEAD <file>`

**Commit with conventional message:**

#### Scope Mode Commits

For `pr` mode (scope):
```bash
git commit -m "$(cat <<'EOF'
docs(changelog): add entries for <scope>

Scope: <scope_name>
Iteration: <iteration_name>
Build: <BUILD_NUM>
EOF
)"
```

For `beta` mode (scope):
```bash
git commit -m "$(cat <<'EOF'
chore(release): prepare v1.3.0-beta.1

Scope: <scope_name>
Iteration: <iteration_name>
Build: <BUILD_NUM>
EOF
)"
```

For `release` mode (scope):
```bash
git commit -m "$(cat <<'EOF'
chore(release): release v1.3.0

- <summary of main changes>

Scope: <scope_name>
Iteration: <iteration_name>
Build: <BUILD_NUM>
EOF
)"
```

#### No-Scope Mode Commits

For `pr` mode (no-scope):
```bash
git commit -m "$(cat <<'EOF'
<type>(<area>): <brief description>

- <summary of main changes>

Build: <BUILD_NUM>
EOF
)"
```
Where `<type>` is: feat, fix, refactor, docs, chore, etc.
Where `<area>` is derived from changed files (e.g., auth, api, ui).

For `beta` mode (no-scope):
```bash
git commit -m "$(cat <<'EOF'
chore(release): prepare v1.3.0-beta.1

- <summary of main changes>

Build: <BUILD_NUM>
EOF
)"
```

For `release` mode (no-scope):
```bash
git commit -m "$(cat <<'EOF'
chore(release): release v1.3.0

- <summary of main changes>

Build: <BUILD_NUM>
EOF
)"
```

---

### Step 8: Create Tags

**For ALL modes - create build tag (lightweight):**
```bash
# Create lightweight build tag on the commit we just made
git tag "build/${BUILD_NUM}"
```

**For `beta` mode - also create release tag (annotated):**
```bash
# Determine beta number
BETA_NUM=$(git tag -l "v*-beta.*" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$" | sort -V | tail -1 | sed 's/.*beta\.//' || echo "0")
NEXT_BETA=$((BETA_NUM + 1))

# Create beta tag
git tag -a "v1.3.0-beta.${NEXT_BETA}" -m "Beta release v1.3.0-beta.${NEXT_BETA}

Changes in this beta:
- <list changes from changelog>

Scope: <scope_name>
Build: ${BUILD_NUM}
"
```

**For `release` mode - also create release tag (annotated):**
```bash
git tag -a "v1.3.0" -m "Release v1.3.0

$(cat <<'EOF'
## What's Changed

### Added
- <entries from changelog>

### Fixed
- <entries from changelog>

Full changelog: CHANGELOG.md
Build: ${BUILD_NUM}
EOF
)"
```

---

### Step 9: Push and Create PR

**Push branch and tags:**

For `pr` mode (build tag only):
```bash
# Push branch and build tag
git push -u origin $(git branch --show-current) "build/${BUILD_NUM}"
```

For `beta` mode (build tag + beta tag):
```bash
# Push branch and both tags
git push -u origin $(git branch --show-current) "build/${BUILD_NUM}" "v${VERSION}-beta.${NEXT_BETA}"
```

For `release` mode (build tag + release tag):
```bash
# Push branch and both tags
git push -u origin $(git branch --show-current) "build/${BUILD_NUM}" "v${VERSION}"
```

**Create PR:**

#### Scope Mode PRs

For `pr` mode (scope):
```bash
gh pr create --title "feat(<scope>): <brief description>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points from results.md>

## Changelog Entry
<show the entry added to CHANGELOG.md>

## Test Plan
- [ ] <validation items from results.md>

---
Scope: `<scope_name>`
Iteration: `<iteration_name>`
Build: `${BUILD_NUM}`
EOF
)"
```

For `beta` mode (scope):
```bash
gh pr create --title "chore(release): v1.3.0-beta.1" --body "$(cat <<'EOF'
## Beta Release v1.3.0-beta.1

<changelog entries>

## Testing This Beta
<instructions for testing if applicable>

---
Scope: `<scope_name>`
Tag: `v1.3.0-beta.1`
Build: `${BUILD_NUM}`
EOF
)" --label "beta"
```

For `release` mode (scope):
```bash
gh pr create --title "chore(release): v1.3.0" --body "$(cat <<'EOF'
## Release v1.3.0

<full changelog section for this version>

## Upgrade Notes
<any migration or upgrade notes>

---
Scope: `<scope_name>`
Tag: `v1.3.0`
Build: `${BUILD_NUM}`
EOF
)" --label "release"
```

#### No-Scope Mode PRs

For `pr` mode (no-scope):
```bash
gh pr create --title "<type>(<area>): <brief description>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing changes>

## Changelog Entry
<show the entry added to CHANGELOG.md>

## Files Changed
<list key files modified>

## Test Plan
- [ ] <how to verify the changes work>

---
Build: `${BUILD_NUM}`
EOF
)"
```

For `beta` mode (no-scope):
```bash
gh pr create --title "chore(release): v1.3.0-beta.1" --body "$(cat <<'EOF'
## Beta Release v1.3.0-beta.1

<changelog entries>

## Testing This Beta
<instructions for testing if applicable>

---
Tag: `v1.3.0-beta.1`
Build: `${BUILD_NUM}`
EOF
)" --label "beta"
```

For `release` mode (no-scope):
```bash
gh pr create --title "chore(release): v1.3.0" --body "$(cat <<'EOF'
## Release v1.3.0

<full changelog section for this version>

## Upgrade Notes
<any migration or upgrade notes>

---
Tag: `v1.3.0`
Build: `${BUILD_NUM}`
EOF
)" --label "release"
```

---

### Step 9.5: Sync Agent Process Central Repo (OPTIONAL)

**This step is OPTIONAL** - only execute if central repo sync is enabled.

**Check if sync is enabled:**
```bash
cat .agent_process/process/ap_release_central_sync.md | grep "ENABLED:"
```

The sync file will contain:
- `ENABLED: true` or `ENABLED: false`
- `CENTRAL_REPO_PATH`: Path to the central repository (if enabled)
- `PROJECT_FOLDER`: This project's folder name in the central repo (if enabled)

**If `ENABLED: false`, skip to Step 10.** This project manages `.agent_process/` locally.

**If `ENABLED: true`, proceed with sync:**

Read configuration:
```bash
ENABLED=$(grep "ENABLED:" .agent_process/process/ap_release_central_sync.md | sed 's/ENABLED: *//' | tr -d ' ')
CENTRAL_REPO_PATH=$(grep "CENTRAL_REPO_PATH:" .agent_process/process/ap_release_central_sync.md | sed 's/CENTRAL_REPO_PATH: *//' | tr -d ' ')
PROJECT_FOLDER=$(grep "PROJECT_FOLDER:" .agent_process/process/ap_release_central_sync.md | sed 's/PROJECT_FOLDER: *//' | tr -d ' ')
```

**Background:** When `.agent_process` is a symlink to the central repo, changes made during scope work are already in the central repo's working directory. We just need to commit and push them.

**Navigate to central repo:**
```bash
cd ${CENTRAL_REPO_PATH}
```

**Check if there are changes to commit:**
```bash
git status --short ${PROJECT_FOLDER}/
```

**If there are NO changes, skip to Step 10.**

**If there ARE changes, commit them:**

For `pr` mode:
```bash
git add ${PROJECT_FOLDER}/
git commit -m "$(cat <<'EOF'
docs(${PROJECT_FOLDER}): update for <scope>

Project: ${PROJECT_FOLDER}
Scope: <scope_name>
Iteration: <iteration_name>
Build: ${BUILD_NUM}

Synced from main repo commit: <commit_sha_from_main_repo>
EOF
)"
```

For `beta` mode:
```bash
git add ${PROJECT_FOLDER}/
git commit -m "$(cat <<'EOF'
chore(${PROJECT_FOLDER}): prepare v<version>-beta.<N>

Project: ${PROJECT_FOLDER}
Scope: <scope_name>
Iteration: <iteration_name>
Build: ${BUILD_NUM}

Synced from main repo commit: <commit_sha_from_main_repo>
EOF
)"
```

For `release` mode:
```bash
git add ${PROJECT_FOLDER}/
git commit -m "$(cat <<'EOF'
chore(${PROJECT_FOLDER}): release v<version>

Project: ${PROJECT_FOLDER}
Scope: <scope_name>
Iteration: <iteration_name>
Build: ${BUILD_NUM}

<summary of main changes>

Synced from main repo commit: <commit_sha_from_main_repo>
EOF
)"
```

**Push to remote:**
```bash
git push origin main
```

**Return to project directory:**
```bash
cd -
```

**Note:** The central repo uses a simpler workflow (direct commits to main) since it's a private tracking repo. No PRs needed.

---

### Step 10: Report Completion

**Provide summary:**

For scope mode:
```markdown
## Release Complete: <mode>

**Context:** Scope mode
**Scope:** <scope_name>
**Iteration:** <iteration_name>
**Build:** <BUILD_NUM>

**Actions Taken:**
- ✅ Changelog updated: [Unreleased] / [X.Y.Z]
- ✅ Version files updated: [list files] (release mode only)
- ✅ Committed: <commit sha>
- ✅ Build tagged: `build/<BUILD_NUM>`
- ✅ Release tagged: <tag> (beta/release mode only)
- ✅ Pushed to: origin/<branch>
- ✅ PR created: <PR URL>
- ✅ Agent process synced to central repo: <central_commit_sha> (if configured)

**Changelog Entry:**
```
<show the entry that was added>
```

**Next Steps:**
- For `pr`: Merge PR when ready, run `/ap_release release <type>` when ready to ship
- For `beta`: Share beta tag for testing, run more betas or `/ap_release release` when stable
- For `release`: Merge PR, release is complete
```

For no-scope mode:
```markdown
## Release Complete: <mode>

**Context:** No-scope mode (changes detected from git diff)
**Build:** <BUILD_NUM>

**Changes Included:**
- <summary of detected changes>

**Actions Taken:**
- ✅ Changelog updated: [Unreleased] / [X.Y.Z]
- ✅ Version files updated: [list files] (release mode only)
- ✅ Committed: <commit sha>
- ✅ Build tagged: `build/<BUILD_NUM>`
- ✅ Release tagged: <tag> (beta/release mode only)
- ✅ Pushed to: origin/<branch>
- ✅ PR created: <PR URL>

**Changelog Entry:**
```
<show the entry that was added>
```

**Next Steps:**
- For `pr`: Merge PR when ready, run `/ap_release release <type>` when ready to ship
- For `beta`: Share beta tag for testing, run more betas or `/ap_release release` when stable
- For `release`: Merge PR, release is complete
```

---

## Important Rules

**Version file consistency:**
- All version files in project must have same version
- Don't update version for `pr` or `beta` modes (only changelog)
- `release` mode updates both changelog AND version files

**Changelog discipline:**
- Scope mode: One entry per scope (not per commit)
- No-scope mode: One cohesive entry per release describing all changes
- User-facing language (not implementation details)
- Categorize correctly (Added/Changed/Fixed/etc.)
- Breaking changes get their own section

**Tag conventions:**
- Build tags: `build/N` (monotonically increasing, lightweight)
- Release tags: `v1.2.3` (semantic versioning, annotated)
- Beta tags: `v1.2.3-beta.N` (incrementing beta number, annotated)
- Build tags are lightweight; release/beta tags are annotated (with message)

**PR best practices:**
- PR title follows conventional commits
- PR body includes changelog entry for reviewer visibility
- Label PRs appropriately (beta, release)

---

## Troubleshooting

**No version file found:**
- Create a `VERSION` file with just the version number
- Or add to appropriate config file for your language

**Multiple version files out of sync:**
- Sync them all to the same version before running release
- Update all detected files to match

**Beta number collision:**
- Check existing beta tags: `git tag -l "v*-beta.*"`
- Manually specify next beta number if needed

**PR creation fails:**
- Ensure `gh` CLI is authenticated: `gh auth status`
- Check branch is pushed: `git push -u origin <branch>`

---

## Examples

### Example 1: Regular PR (no release yet)
```bash
/ap_release pr
```
- Adds entry to [Unreleased] in CHANGELOG.md
- Creates build tag `build/47`
- Creates PR with changelog in description
- No version bump, no release tag

### Example 2: Beta release for testing
```bash
/ap_release beta
```
- Moves [Unreleased] to [1.3.0-beta.1] in CHANGELOG.md
- Creates build tag `build/48`
- Creates release tag `v1.3.0-beta.1`
- Creates PR with beta label

### Example 3: Minor feature release
```bash
/ap_release release minor
```
- Moves [Unreleased] to [1.3.0] in CHANGELOG.md
- Updates version files to 1.3.0
- Creates build tag `build/49`
- Creates release tag `v1.3.0`
- Creates PR with release label

### Example 4: Hotfix release
```bash
/ap_release release patch
```
- Moves [Unreleased] to [1.2.4] in CHANGELOG.md
- Updates version files to 1.2.4
- Creates build tag `build/50`
- Creates release tag `v1.2.4`
- Creates PR with release label

---

**Remember:** This command runs AFTER orchestrator approval. It's the final step before code is merged and (optionally) released.
