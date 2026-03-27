# Steps 09-12: Finalize Scope

**Model tier:** cheap
**Tools needed:** Bash, Write, Read
**Input:** Scope name, iteration plan path
**Output:** `.run/planning/09-12-finalize.md`

---

## Your Task

Create the remaining infrastructure for the scope: iteration placeholder, config, roadmap update, and handoff summary.

## Step 9: Create iteration_01 Placeholder

```bash
mkdir -p .agent_process/work/{scope}/iteration_01
```

Write placeholder results file:
```markdown
# Iteration Results — {scope}/iteration_01

**Status:** TODO - Awaiting execution

Run: /ap_exec {scope} iteration_01
```

Save to `.agent_process/work/{scope}/iteration_01/results.md`

## Step 10: Update Current Iteration Config

Write to `.agent_process/work/current_iteration.conf`:
```
SCOPE={scope}
ITERATION=iteration_01
```

## Step 11: Update Roadmap (if exists)

Check: `ls .agent_process/roadmap/master_roadmap.md 2>/dev/null`

**If roadmap exists:**

1. Find the requirement row in "Requirements by Category" — change status from 📋 to 🚧, increment work scope count
2. Add row to "Active Work (In Progress)" table
3. Update summary statistics (decrement Not Started, increment In Progress)
4. Update "Last Updated" timestamp

**If no roadmap:** Skip this step.

## Step 12: Validation Script Placement

Verify the validation script from Step 07 exists at:
`.agent_process/scripts/after_edit/validate-{scope}.sh`

If it doesn't exist yet (Step 07 only wrote the content to `.run/planning/`), create it now and make executable:
```bash
chmod +x .agent_process/scripts/after_edit/validate-{scope}.sh
```

## Output Format

Write to `.run/planning/09-12-finalize.md`:

```markdown
# Finalize Results

## Created
- `.agent_process/work/{scope}/iteration_01/results.md` — placeholder
- `.agent_process/work/current_iteration.conf` — updated

## Roadmap
- Updated: YES/NO (no roadmap found)
- Status change: 📋 → 🚧

## Validation Script
- Path: `.agent_process/scripts/after_edit/validate-{scope}.sh`
- Executable: YES/NO

## Ready for Handoff
All infrastructure in place. Scope is ready for human approval.
```
