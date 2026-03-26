# Step 02: Derive Work Folder Name

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** Requirement file path
**Output:** `.run/planning/02-folder-name.txt`

---

## Your Task

Determine the work folder name for this scope. The folder name is the single source of truth for all subsequent steps.

## Rules

### Primary: Use Frontmatter ID

Read the requirement file's YAML frontmatter. Extract the `id:` field. Use it **verbatim** as the folder name.

```
Frontmatter:  id: decomp_scope_01_planning
Folder name:  decomp_scope_01_planning
```

### Fallback: Ad-hoc Work (no requirement file)

If there's no requirement doc (hotfixes, quick tasks):
```
hotfix_<area>_<brief_description>
```

## Validation

Before writing output, verify:
- Folder name matches the requirement's `id:` exactly
- No category prefix accidentally doubled from path derivation
- Name is specific (not "cleanup" or "improve")

Check if the work folder already exists:
```bash
ls .agent_process/work/{folder_name} 2>/dev/null
```

If it exists, note this in the output — the coordinator will handle it.

## Output

Write ONLY the folder name (single line, no markdown) to `.run/planning/02-folder-name.txt`.

If the folder already exists, write:
```
{folder_name}
EXISTS: true
```
