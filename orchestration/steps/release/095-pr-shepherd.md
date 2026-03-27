# Step 9.5: PR Shepherd (CONDITIONAL)

**Model tier:** capable (Agent tool — spawns a monitoring sub-agent)
**Tools needed:** Agent/Task
**Input:** PR URL from `.run/release/07-09-git-ops.md`
**Output:** `.run/release/095-shepherd.md`

---

## Your Task

Launch a shepherd agent to monitor the PR through CI and review until merge-ready. This step is conditional — check the launch criteria before spawning.

## Launch Criteria

1. Read `quality-config.json` → `pr_shepherd.enabled`
2. Check CLI flags:
   - `--no-shepherd` → skip regardless of config
   - `--shepherd` → run regardless of config
   - Neither → follow config setting

## Shepherd Agent

Spawn with Agent/Task tool:

```
Agent({
  subagent_type: "general-purpose",
  description: "Shepherd PR through CI and review",
  prompt: "You are a PR shepherd. Monitor PR {URL} until merge-ready.

    1. Check CI: gh pr checks {NUMBER}
    2. If checks fail: diagnose and fix within scope files
    3. Check for review comments: gh pr view {NUMBER} --comments
    4. Respond to questions, implement change requests within scope
    5. Report when all checks pass and threads resolved

    Boundaries: only modify PR files, no force-push, no merge, max 3 fix attempts per issue."
})
```

## Output Format

Write to `.run/release/095-shepherd.md`:

```markdown
# PR Shepherd

**Launched:** YES / SKIPPED
**Reason:** {config enabled / flag override / config disabled / --no-shepherd}

## Report (if launched)
**PR:** {URL}
**Status:** MERGE-READY / IN PROGRESS / BLOCKED
**CI:** {all passing / N failing}
**Reviews:** {approved / changes requested / none}
**Actions taken:** {list fixes committed, if any}
```
