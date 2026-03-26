# Steps 07-09: Commit, Tag, Push, PR (SEQUENTIAL — do NOT parallelize)

**Model tier:** capable
**Tools needed:** Bash
**Input:** mode, version info, build number, context mode, scope, changelog entry
**Output:** `.run/release/07-09-git-ops.md`

---

## Your Task

Execute git operations in strict sequence. These CANNOT be parallelized.

## Step 7: Commit

```bash
git add .
git status --short  # sanity check — verify only expected files
```

Review staged files. Unstage anything unexpected (`git reset HEAD <file>`).

**Commit message by mode:**

Scope mode:
- `pr`: `docs(changelog): add entries for {scope}`
- `beta`: `chore(release): prepare v{version}-beta.{N}`
- `release`: `chore(release): release v{version}`

No-scope mode:
- `pr`: `{type}({area}): {description}`
- `beta`: `chore(release): prepare v{version}-beta.{N}`
- `release`: `chore(release): release v{version}`

Include trailers: `Scope:`, `Iteration:`, `Build:` (scope mode) or just `Build:` (noscope).

## Step 8: Create Tags

**ALL modes — build tag (lightweight):**
```bash
git tag "build/{BUILD_NUM}"
```

**`beta` mode — release tag (annotated):**
```bash
git tag -a "v{version}-beta.{N}" -m "Beta release v{version}-beta.{N}..."
```

**`release` mode — release tag (annotated):**
```bash
git tag -a "v{version}" -m "Release v{version}..."
```

## Step 9: Push and Create PR

**Push branch + tags:**
```bash
# pr mode: branch + build tag
git push -u origin $(git branch --show-current) "build/{BUILD_NUM}"

# beta: branch + build tag + beta tag
git push -u origin $(git branch --show-current) "build/{BUILD_NUM}" "v{version}-beta.{N}"

# release: branch + build tag + release tag
git push -u origin $(git branch --show-current) "build/{BUILD_NUM}" "v{version}"
```

**Create PR with `gh pr create`:**
- Title follows conventional commits
- Body includes changelog entry and scope/build metadata
- Label `beta` or `release` as appropriate

## Central Repo Sync (optional)

```bash
grep "ENABLED:" .agent_process/process/ap_release_central_sync.md 2>/dev/null
```

If `ENABLED: false` or file missing → skip, write "skipped" in output.

If `ENABLED: true`:
```bash
# Read config
CENTRAL_REPO_PATH=$(grep "CENTRAL_REPO_PATH:" .agent_process/process/ap_release_central_sync.md | sed 's/CENTRAL_REPO_PATH: *//')
PROJECT_FOLDER=$(grep "PROJECT_FOLDER:" .agent_process/process/ap_release_central_sync.md | sed 's/PROJECT_FOLDER: *//')

# Navigate, commit, push
cd "$CENTRAL_REPO_PATH"
git add "$PROJECT_FOLDER/"
git commit -m "docs($PROJECT_FOLDER): sync for {scope} build/{BUILD_NUM}"
git push origin main
cd -
```

## Output Format

Write to `.run/release/07-09-git-ops.md`:

```markdown
# Git Operations

**Commit:** {sha}
**Build tag:** build/{N}
**Release tag:** {tag or "none"}
**Pushed to:** origin/{branch}
**PR:** {URL}
**Central sync:** {committed/skipped}
```
