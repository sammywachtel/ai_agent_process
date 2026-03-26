# Step 0.7d: Supplemental Context — Recent Changes to Files in Scope

**Model tier:** cheap
**Tools needed:** Bash, Grep
**Input:** scope
**Output:** `.run/execution/007d-git-context.md`

---

## Your Task

Load recent git history for files this scope will touch. This gives the implementation agent awareness of recent changes that the iteration plan may not capture.

## Steps

1. Extract file paths from the iteration plan:
```bash
grep -A 50 "## Files in Scope\|## Files Expected to Change" \
  .agent_process/work/{scope}/iteration_plan.md 2>/dev/null \
  | grep "^- \`" | sed 's/^- `//;s/`.*$//'
```

2. Get recent commits touching these files:
```bash
git log --oneline -5 -- {files_in_scope} 2>/dev/null
```

## Output Format

Write to `.run/execution/007d-git-context.md`:

```markdown
# Recent Changes to Files in Scope

**Scope:** {scope}
**Files checked:** {count}

## Recent Commits
{git log output — last 5 commits touching scope files}

## Summary
{Brief note on recent activity — e.g., "3 commits in last week, mostly refactoring" or "No recent changes"}
```

If no git history exists (new files): write "No prior history — all files are new."
