# Step 0.7c: Branch Check (runs FIRST — before other pre-flight checks)

**Model tier:** cheap
**Tools needed:** Bash
**Input:** scope
**Output:** `.run/execution/007c-branch-check.md`

---

## Why This Runs First

This step may change which branch we're on. Other pre-flight checks (working tree, git context) read from the current branch — if we switch branches mid-check, their results could be wrong. Branch check runs alone, completes, then the other checks run in parallel on the correct branch.

## Your Task

Verify the current branch matches the expected scope branch. If the expected branch already exists from a previous run, flag it — the coordinator will ask the user what to do.

## Checks

```bash
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
EXPECTED_BRANCH="scope/{scope}"
echo "Current: $CURRENT_BRANCH"
echo "Expected: $EXPECTED_BRANCH"
```

### Case 1: Already on correct branch
Nothing to do. Proceed.

### Case 2: Expected branch exists but we're not on it
This is ambiguous — the branch may be from a previous incomplete run, or the user may have work there. **Do not switch automatically.** Flag for human decision.

```bash
git show-ref --verify --quiet "refs/heads/scope/{scope}" && echo "exists" || echo "new"
```

### Case 3: Expected branch doesn't exist
Create and switch to it:
```bash
git checkout -b "scope/{scope}"
```

## Output Format

Write to `.run/execution/007c-branch-check.md`:

```markdown
# Branch Check

**Current:** {current_branch}
**Expected:** scope/{scope}

EXISTING_BRANCH: true/false

## Result
- {Case 1: "Already on correct branch. No action needed."}
- {Case 2: "Branch scope/{scope} already exists but we're on {current_branch}. Flagging for human decision — branch may have prior work."}
- {Case 3: "Created new branch scope/{scope} from {current_branch}."}
```
