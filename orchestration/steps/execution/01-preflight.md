# Step 01: Preflight Checks

**Output:** `.run/execution/01-preflight.md`

---

Run these checks before implementation. All can run in parallel EXCEPT branch check runs first (it may change branches).

## 1. Branch Check (FIRST)

```bash
CURRENT=$(git branch --show-current)
EXPECTED="scope/{scope}"
```

- **On correct branch:** Proceed
- **Branch exists, not on it:** Flag for human — may have prior work
- **Branch doesn't exist:** Create it: `git checkout -b "scope/{scope}"`

## 2. Session Recovery

Check for uncommitted work from interrupted sessions:

```bash
git status --porcelain | head -5
```

If changes exist in scope files, present options:
- Stash and continue
- Commit and continue  
- Abort and let user handle

## 3. Working Tree Check

Verify clean working state:

```bash
git diff --stat HEAD 2>/dev/null | head -10
```

Flag if significant uncommitted changes exist outside `.agent_process/`.

## 4. Git Context

Get recent changes to scope files for context:

```bash
git log --oneline -5 -- {scope_files}
```

This helps the executor understand recent work.

## 5. Tracker Sync

Ensure the tracker reflects the iteration being executed:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-iteration {scope} {iteration}
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} executing
```

This prevents tracker drift when review post-decision is skipped or a new iteration is started manually. The tracker should always match execution reality. Setting status to `executing` transitions from `planning` (set by `start`) to active work.

---

## Output

```markdown
# Preflight Results

**Scope:** {scope}
**Iteration:** {iteration}

## Branch
- Current: {branch}
- Expected: scope/{scope}
- Status: OK / CREATED / NEEDS_DECISION

## Working State
- Uncommitted changes: {none / N files — listed}
- Recovery needed: YES / NO

## Git Context
- Recent commits touching scope: {count}
- Last change: {date} — {message}

## Gate
PREFLIGHT: PASS / BLOCKED
{If blocked: reason and recommended action}
```
