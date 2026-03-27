# Step 04: Define Files in Scope

**Model tier:** capable
**Tools needed:** Read, Glob
**Input:** Requirement file, code review output (`.run/planning/03-code-review.md`)
**Output:** `.run/planning/04-files-in-scope.md`

---

## Your Task

Create the definitive list of files this scope will create, modify, or delete. This list drives the validation script and scope boundary enforcement.

## Rules

- **Target:** 4-10 files. If >15, the scope may need splitting.
- List files by action: **New**, **Modified**, **Deleted**
- Include test files — they're part of the scope
- Use the code review output to verify paths exist and catch missing files

## Shared-API Check

If this scope changes an API or payload consumed by other clients:
- Note each consumer (web, mobile, CLI, partner service)
- Note the file defining the contract
- This info feeds into the iteration plan's `## Contract Consumers` section

## Output Format

Write to `.run/planning/04-files-in-scope.md`:

```markdown
# Files in Scope

**Scope:** {scope_name}
**Total:** {count} files

## New Files
- `path/to/new-file.md` — {purpose}

## Modified Files
- `path/to/existing-file.ts` — {what changes}

## Deleted Files
- `path/to/old-file.md` — {why deleted}

## Contract Consumers
{If API changes: list consumers and contract files}
{If no API changes: "N/A — no public API changes"}

## Size Assessment
{count} files — {"within target" or "exceeds target, consider splitting"}
```
