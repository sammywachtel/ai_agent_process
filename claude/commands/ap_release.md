---
name: /ap_release
description: Update changelog, create PR, and optionally tag a release
argument-hint: pr | beta | release [patch|minor|major]
arguments:
  - name: mode
    type: string
    description: "pr (changelog + PR) | beta (+ beta tag) | release (+ version bump + release tag)"
    required: true
  - name: version_type
    type: string
    description: "patch | minor | major (required for 'release' mode only)"
    required: false
---

## Your Role

You are the release coordinator. Your job: update version files and changelog, commit changes, create tags (if applicable), and create/update the PR. This command runs AFTER scope work is approved by the orchestrator.

---

## Mode Reference

| Mode | Updates Changelog | Creates PR | Creates Tag | Moves [Unreleased] |
|------|-------------------|------------|-------------|-------------------|
| `pr` | Yes (under Unreleased) | Yes | No | No |
| `beta` | Yes (under Unreleased) | Yes | Yes (`vX.Y.Z-beta.N`) | No |
| `release patch` | Yes | Yes | Yes (`vX.Y.Z+1`) | Yes → new version |
| `release minor` | Yes | Yes | Yes (`vX.Y+1.0`) | Yes → new version |
| `release major` | Yes | Yes | Yes (`vX+1.0.0`) | Yes → new version |

**Version types (for `release` mode):**
- `patch` - Bug fixes, no new features (1.0.0 → 1.0.1)
- `minor` - New features, backward compatible (1.0.0 → 1.1.0)
- `major` - Breaking changes (1.0.0 → 2.0.0)

---

## Workflow

### Step 1: Gather Context

**Read current scope info:**
```bash
cat .agent_process/work/current_iteration.conf
```

**Extract scope and iteration:**
```
SCOPE=<scope_name>
ITERATION=<iteration_name>
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

**For `pr` and `beta` modes:**

Append entry to [Unreleased] section under appropriate category:

```markdown
## [Unreleased]

### Added
- Dark mode toggle in Settings → Appearance
- CSV export for usage data

### Fixed
- Session timeout now extends properly on activity (#142)
```

**For `release` mode:**

Move [Unreleased] contents to new version header:

```markdown
## [1.3.0] - 2025-01-04

### Added
- Dark mode toggle in Settings → Appearance
- CSV export for usage data

### Fixed
- Session timeout now extends properly on activity (#142)

## [1.2.3] - 2024-12-15
...
```

Then create empty [Unreleased] section:
```markdown
## [Unreleased]

## [1.3.0] - 2025-01-04
...
```

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

For `pr` mode:
```bash
git commit -m "$(cat <<'EOF'
docs(changelog): add entries for <scope>

Scope: <scope_name>
Iteration: <iteration_name>
EOF
)"
```

For `beta` mode:
```bash
git commit -m "$(cat <<'EOF'
chore(release): prepare v1.3.0-beta.1

Scope: <scope_name>
Iteration: <iteration_name>
EOF
)"
```

For `release` mode:
```bash
git commit -m "$(cat <<'EOF'
chore(release): release v1.3.0

- <summary of main changes>

Scope: <scope_name>
Iteration: <iteration_name>
EOF
)"
```

---

### Step 8: Create Tag (beta and release modes only)

**For `beta` mode:**
```bash
# Determine beta number
BETA_NUM=$(git tag -l "v*-beta.*" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$" | sort -V | tail -1 | sed 's/.*beta\.//' || echo "0")
NEXT_BETA=$((BETA_NUM + 1))

# Create beta tag
git tag -a "v1.3.0-beta.${NEXT_BETA}" -m "Beta release v1.3.0-beta.${NEXT_BETA}

Changes in this beta:
- <list changes from changelog>

Scope: <scope_name>
"
```

**For `release` mode:**
```bash
git tag -a "v1.3.0" -m "Release v1.3.0

$(cat <<'EOF'
## What's Changed

### Added
- <entries from changelog>

### Fixed
- <entries from changelog>

Full changelog: CHANGELOG.md
EOF
)"
```

---

### Step 9: Push and Create PR

**Push branch and tags:**
```bash
# Push branch
git push -u origin $(git branch --show-current)

# Push tags (if created)
git push --tags
```

**Create PR:**

For `pr` mode:
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
EOF
)"
```

For `beta` mode:
```bash
gh pr create --title "chore(release): v1.3.0-beta.1" --body "$(cat <<'EOF'
## Beta Release v1.3.0-beta.1

<changelog entries>

## Testing This Beta
<instructions for testing if applicable>

---
Tag: `v1.3.0-beta.1`
EOF
)" --label "beta"
```

For `release` mode:
```bash
gh pr create --title "chore(release): v1.3.0" --body "$(cat <<'EOF'
## Release v1.3.0

<full changelog section for this version>

## Upgrade Notes
<any migration or upgrade notes>

---
Tag: `v1.3.0`
EOF
)" --label "release"
```

---

### Step 10: Report Completion

**Provide summary:**

```markdown
## Release Complete: <mode>

**Scope:** <scope_name>
**Iteration:** <iteration_name>

**Actions Taken:**
- ✅ Changelog updated: [Unreleased] / [X.Y.Z]
- ✅ Version files updated: [list files] (release mode only)
- ✅ Committed: <commit sha>
- ✅ Tagged: <tag> (beta/release mode only)
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
- One entry per scope (not per commit)
- User-facing language (not implementation details)
- Categorize correctly (Added/Changed/Fixed/etc.)
- Breaking changes get their own section

**Tag conventions:**
- Release tags: `v1.2.3` (semantic versioning)
- Beta tags: `v1.2.3-beta.N` (incrementing beta number)
- Tags are annotated (with message), not lightweight

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
- Creates PR with changelog in description
- No version bump, no tag

### Example 2: Beta release for testing
```bash
/ap_release beta
```
- Adds entry to [Unreleased] in CHANGELOG.md
- Creates tag `v1.3.0-beta.1`
- Creates PR with beta label

### Example 3: Minor feature release
```bash
/ap_release release minor
```
- Moves [Unreleased] to [1.3.0] in CHANGELOG.md
- Updates version files to 1.3.0
- Creates tag `v1.3.0`
- Creates PR with release label

### Example 4: Hotfix release
```bash
/ap_release release patch
```
- Moves [Unreleased] to [1.2.4] in CHANGELOG.md
- Updates version files to 1.2.4
- Creates tag `v1.2.4`
- Creates PR with release label

---

**Remember:** This command runs AFTER orchestrator approval. It's the final step before code is merged and (optionally) released.
