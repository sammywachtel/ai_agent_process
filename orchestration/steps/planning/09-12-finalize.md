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

## Step 10.5: Update Requirement Status to Scoped

Update the requirement file's frontmatter `status:` to `scoped` and add a status banner. This reflects that a work scope has been created but execution hasn't started yet.

Read the requirement file path from the iteration plan's "Requirements Source" line:

```python
python3 << 'PYEOF'
import re, yaml
from pathlib import Path

# Read iteration_plan.md to find the requirement file
plan = Path(".agent_process/work/{scope}/iteration_plan.md").read_text()
req_match = re.search(r'Requirements Source[:\s]*[`]?([^\n`]+)[`]?', plan)

if req_match:
    req_path = Path(req_match.group(1).strip())
    if req_path.exists():
        content = req_path.read_text()
        if content.startswith("---"):
            end = content.index("---", 3)
            fm = yaml.safe_load(content[3:end])
            body = content[end+3:]
            fm["status"] = "scoped"
            new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---" + body

            # Add/update status banner (after frontmatter, before first heading)
            banner = '''
> [!NOTE]
> **🔧 SCOPED** — *Work scope created, awaiting execution*
>
> Planning complete. Iteration plan ready at `.agent_process/work/{scope}/iteration_plan.md`.
> Run `/ap_exec {scope} iteration_01` to begin implementation.
'''
            # Remove existing banner if present
            new_content = re.sub(r'\n> \[!(NOTE|TIP|WARNING|CAUTION)\]\n> \*\*[^\n]+\n(> [^\n]*\n)*', '', new_content, count=1)
            # Insert banner after frontmatter
            parts = new_content.split("---\n", 2)
            if len(parts) >= 3:
                new_content = "---\n" + parts[1] + "---\n" + banner + parts[2]

            req_path.write_text(new_content)
            print(f"✅ Updated {req_path} status to scoped")
PYEOF
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

## Requirement Status
- Updated: YES/NO
- Status change: not_started → scoped
- Banner added: 🔧 SCOPED

## Roadmap
- Updated: YES/NO (no roadmap found)
- Status change: 📋 → 🔧

## Validation Script
- Path: `.agent_process/scripts/after_edit/validate-{scope}.sh`
- Executable: YES/NO

## Ready for Handoff
All infrastructure in place. Scope is ready for human approval.
```
