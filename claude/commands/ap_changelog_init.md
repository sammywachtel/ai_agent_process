---
description: Initialize CHANGELOG.md from git history for projects that haven't been tracking releases
argument-hint: [starting-version]
---

## Arguments

**`$1` (starting_version)** - Optional. Version number to use as the "detailed tracking starts here" point. Defaults to `1.0.0` if not specified.

---

## Your Role

You are initializing a changelog for a project that hasn't been tracking releases. Your job: analyze git history, create a meaningful historical summary, and set up the changelog structure for future tracking with `/ap_release`.

---

## Workflow Overview

1. **Analyze Git History** - Examine tags, commits, and PR merges
2. **Detect Project Structure** - Determine current version (if any)
3. **Generate Historical Summary** - Categorize past work by era/milestone
4. **Create CHANGELOG.md** - With historical context and [Unreleased] section
5. **Report** - Show what was created for human review

---

## Step 1: Analyze Git History

**Check for existing tags:**
```bash
git tag -l --sort=-version:refname
```

**Get commit count and date range:**
```bash
# Total commits
git rev-list --count HEAD

# First commit date
git log --reverse --format="%ci" | head -1

# Recent commits (last 50)
git log --oneline -50
```

**Check for merge commits (PRs):**
```bash
# PR merge commits often have richer context
git log --merges --oneline -30
```

**Look for conventional commit patterns:**
```bash
# Check if commits follow conventional format (feat:, fix:, etc.)
git log --oneline -50 | grep -E "^[a-f0-9]+ (feat|fix|chore|docs|refactor|test|style)(\(.+\))?:"
```

**Document findings:**
```markdown
## Git History Analysis

**Repository age:** [X months/years]
**Total commits:** [N]
**Existing tags:** [list or "none"]
**Merge commits:** [N] (indicates PR workflow)
**Conventional commits:** [Yes/No/Partial]
```

---

## Step 2: Detect Project Structure & Version

**Check for existing version files:**
```bash
# Look for version indicators
cat package.json 2>/dev/null | grep '"version"'
cat pyproject.toml 2>/dev/null | grep -E '^version\s*='
cat setup.py 2>/dev/null | grep -E 'version\s*='
cat VERSION 2>/dev/null
```

**Determine starting version:**
- If version file exists → Use that version as "detailed tracking starts"
- If tags exist → Use latest tag as reference point
- If neither → Use provided argument or default to `1.0.0`

**Check for existing CHANGELOG.md:**
```bash
ls -la CHANGELOG.md CHANGELOG HISTORY.md HISTORY 2>/dev/null
```

**⚠️ CRITICAL: If CHANGELOG.md already exists:**
- **STOP IMMEDIATELY** - do not proceed to Step 3
- Ask user which option they prefer:
  1. **Backup and replace** - Move existing to CHANGELOG.md.bak, create new
  2. **Abort** - Keep existing, do not create new
- Do NOT overwrite without explicit user confirmation
- This check applies on EVERY run, not just the first time

---

## Step 3: Generate Historical Summary

**Analyze git history to identify eras/milestones:**

Use commit messages and dates to identify natural groupings:

```bash
# Get commits grouped by month (helps identify active periods)
git log --format="%ci %s" | cut -d' ' -f1-2 | uniq -c | head -20

# Get commits with full messages for context
git log --format="---commit---%n%h %ci%n%s%n%b" | head -200
```

**Categorize historical work into themes:**

Read through the commit history and identify major themes:
- **Core Features** - What does this project fundamentally do?
- **Infrastructure** - Setup, CI/CD, tooling
- **API/Interface** - Public interfaces, endpoints
- **Bug Fixes** - Major fixes (skip minor ones)
- **Documentation** - Docs, README updates

**If tags exist, group by tag:**

For each tag, summarize what that release contained:
```bash
# Commits in each tagged release
git log v0.1.0..v0.2.0 --oneline --no-merges 2>/dev/null
```

**Create era summaries:**

Group into logical eras (examples):
- "Initial Development (2023)"
- "Alpha Release (Q1 2024)"
- "Beta & Stabilization (Q2-Q3 2024)"
- "Production Ready (Q4 2024)"

For each era, write 3-5 bullet points summarizing major work.

---

## Step 4: Create CHANGELOG.md

**Use this template structure:**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [{starting_version}] - {today's date}

**Detailed changelog tracking begins with this version.**

For historical context, see the summary below and the [full git history]({repo_url}/commits/main).

---

## Historical Summary

### {Era/Tag Name} ({date range})

{If tags exist, use tag versions. If not, use descriptive era names.}

**Highlights:**
- {Major feature or capability added}
- {Another significant change}
- {Infrastructure/tooling milestone}

**Key commits:**
- `{short_sha}` {commit message} ({date})
- `{short_sha}` {commit message} ({date})

### {Previous Era/Tag} ({date range})

**Highlights:**
- {Summary point}
- {Summary point}

{Continue for 2-4 major eras, don't go overboard}

### Project Inception ({earliest date})

Initial project setup and proof of concept.

---

*For complete historical details, see the [commit history]({repo_url}/commits/main).*
```

---

## Step 5: Write the File

**Create CHANGELOG.md:**

Use the Write tool to create the file at the project root.

**Important formatting rules:**
- **CRITICAL: Use EXACT dates from git log output** - never infer, guess, or use placeholder dates
- Use ISO date format: YYYY-MM-DD
- Link to commit history for transparency
- Keep historical summaries concise (3-5 bullets per era)
- Include select "key commits" with sha links for the curious
- Make it clear where detailed tracking begins
- Do NOT include internal comments like `<!-- instructions -->` - the changelog is user-facing

---

## Step 6: Report Completion

**Provide summary to user:**

```markdown
## Changelog Initialized

**Created:** `CHANGELOG.md`

**Structure:**
- [Unreleased] section ready for `/ap_release`
- Starting version: {version} ({today's date})
- Historical summary: {N} eras covering {date range}

**Historical Coverage:**
{List the eras/tags summarized}

**Git Analysis:**
- Analyzed {N} commits
- Found {N} tags
- Date range: {first commit} to {today}

**Next Steps:**
1. Review the generated CHANGELOG.md
2. Edit historical summaries if needed (add context I may have missed)
3. Use `/ap_release pr|beta|release` for all future changes

**Sample of what was generated:**
```
{Show first ~30 lines of the changelog}
```
```

---

## Guidelines for Historical Summaries

**DO include:**
- Major features that users would recognize
- Significant architectural decisions
- Breaking changes (even historical ones)
- Migration from one system to another
- Public API additions

**DON'T include:**
- Every bug fix (just major ones)
- Internal refactoring details
- Dependency updates (unless significant)
- Typo fixes, formatting changes
- Implementation details users don't see

**Write for the audience:**
- If project has end users → Focus on features and fixes they'd notice
- If project is a library → Focus on API changes and capabilities
- If internal tool → Focus on capabilities and major improvements

---

## Handling Edge Cases

**No tags, few commits (< 50):**
- Single "Initial Development" era
- List the most significant commits directly

**No tags, many commits (> 200):**
- Group by quarter or half-year
- Focus on merge commits (PRs) which often have better summaries
- Identify "milestone" commits by message content

**Many tags (> 10):**
- Summarize only the most recent 3-5 tagged releases in detail
- Group older tags into eras: "v0.x Series (2023)"
- Don't try to document every patch release

**Existing CHANGELOG.md found:**
```markdown
⚠️ CHANGELOG.md already exists!

Options:
1. **Backup and replace** - Move existing to CHANGELOG.md.bak, create new
2. **Abort** - Keep existing, don't run initialization

Which would you like?
```

**Wait for user response before proceeding.**

---

## Example Output

For a project with some tags and ~150 commits:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [1.0.0] - {TODAY'S ACTUAL DATE}

**Detailed changelog tracking begins with this version.**

For historical context, see the summary below and the [full git history](https://github.com/user/repo/commits/main).

---

## Historical Summary

### Beta & Stabilization ({DATE RANGE FROM GIT})

**Highlights:**
- Implemented real-time sync between frontend and backend
- Added comprehensive E2E test suite with Playwright
- Migrated from REST to GraphQL for main data endpoints
- Fixed critical session management bugs

**Key commits:**
- `a1b2c3d` feat: add real-time WebSocket sync ({DATE FROM GIT LOG})
- `e4f5g6h` feat: GraphQL migration complete ({DATE FROM GIT LOG})
- `i7j8k9l` fix: session timeout race condition ({DATE FROM GIT LOG})

### Alpha Development ({DATE RANGE FROM GIT})

**Highlights:**
- Core application architecture established
- Initial frontend with React + TypeScript
- Backend API with FastAPI
- Basic authentication system

**Key commits:**
- `m1n2o3p` feat: initial React frontend scaffold ({DATE FROM GIT LOG})
- `q4r5s6t` feat: FastAPI backend with auth ({DATE FROM GIT LOG})

### Project Inception ({DATE FROM GIT LOG})

Initial project setup, proof of concept, and early experimentation.

---

*For complete historical details, see the [commit history](https://github.com/user/repo/commits/main).*
```

**⚠️ CRITICAL: All dates must come directly from git log output. Do not infer, guess, or use example dates.**

---

## Success Checklist

Before completing, verify:

- [ ] Analyzed git history (tags, commits, date range)
- [ ] Checked for existing CHANGELOG.md (don't overwrite without asking)
- [ ] Identified logical eras/milestones from history
- [ ] Created meaningful historical summaries (not just commit dumps)
- [ ] Set clear "detailed tracking starts here" demarcation
- [ ] [Unreleased] section is ready for `/ap_release`
- [ ] Included links to full git history for transparency
- [ ] Reported what was created for human review

---

**Remember:** This is a one-time initialization. The goal is "good enough" historical context, not perfect documentation of the past. Focus on setting up a solid foundation for tracking changes going forward.
