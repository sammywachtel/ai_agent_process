# Step 3.5: Documentation Verification Gate

**Model tier:** cheap
**Tools needed:** Read, Grep
**Input:** scope, iteration
**Output:** `.run/review/035-doc-verify.md`

---

## Your Task

Verify documentation was updated per "Zero Documentation Drift" rule. Docs must be updated in the same commit as code changes.

## Check Dual-Audience Coverage

1. **End User Docs:** Were user-facing docs updated (if behavior changed)?
2. **Developer Docs:** Were API/architecture docs updated (if applicable)?

## Read

- `.agent_process/work/{scope}/{iteration}/results.md` — "Documentation" section
- `.agent_process/work/{scope}/iteration_plan.md` — "Documentation in Scope" section

## Verify

- Do claimed doc updates actually exist in the codebase?
- Search for orphaned references to removed/renamed code:
  ```bash
  grep -r "OldComponentName" docs/ 2>/dev/null
  grep -r "deprecatedFunction" docs/ 2>/dev/null
  ```

## Fast-Track

If ALL true, docs are likely adequate:
- Internal refactor (no API/UI changes)
- Bug fix with no behavior change
- Test-only changes
- results.md explicitly notes "Internal implementation, no external impact"

## Gate Criteria

**BLOCK if:**
- Code changes external behavior AND no docs updated AND no explanation
- Breaking change with no migration path documented

**PASS if:**
- Docs appropriately updated for both audiences
- Clear justification why no docs needed
- Internal-only changes with no external impact

## Output Format

Write to `.run/review/035-doc-verify.md`:

```markdown
# Documentation Verification

**Gate:** PASS / FAIL

## Assessment
- End user docs: {Updated / N/A — reason}
- Developer docs: {Updated / N/A — reason}
- Orphaned references: {None found / Found: list}

## Details
{What was checked, what was found}
```
