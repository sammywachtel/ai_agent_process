# Step 3.6: Integration Verification Gate

**Model tier:** capable
**Tools needed:** Read, Grep, Glob
**Input:** scope, iteration
**Output:** `.run/review/036-integration-verify.md`

---

## Your Task

Verify that changes don't break integration points with related code outside scope. Files in scope interact with code NOT in scope — changes can break these integration points even when in-scope validation passes.

## Common Integration Failures

- Frontend changes API call structure → Backend expects different schema
- Component changes props interface → Parent components pass wrong props
- Service changes method signature → Callers use old signature
- Database schema changes → Queries use old column names
- Config changes → Consumers expect old config structure

## Verification Process

For each file in scope with changed interfaces:

```bash
# Find API endpoint usages
grep -r "api/endpoint-path" src/ 2>/dev/null

# Find component usages
grep -r "<ComponentName" src/ 2>/dev/null

# Find function call sites
grep -r "functionName(" src/ 2>/dev/null

# Find config readers
grep -r "config.settingName" src/ 2>/dev/null
```

## Fast-Track

If ALL true, integration verification likely not needed:
- Internal implementation only (no API/interface changes)
- Test-only or documentation-only changes
- Bug fix with no signature/schema changes
- results.md explicitly notes "No integration points affected"

## Gate Criteria

**BLOCK if:**
- Frontend API call doesn't match backend endpoint schema
- Component interface changed but call sites use old interface
- Integration verification not performed (no evidence)

**ITERATE if:**
- Integration gaps found but fixable

**PASS if:**
- All integration points verified compatible
- No interface/schema changes (internal refactor only)

## Output Format

Write to `.run/review/036-integration-verify.md`:

```markdown
# Integration Verification

**Gate:** PASS / FAIL / FAST-TRACKED

## Integration Points Checked
- {Endpoint/component/service}: {verified compatible / gap found}

## Files Checked Outside Scope
- {list files verified that weren't in original scope}

## Gaps Found
- {None / list schema mismatches, interface incompatibilities}

## Details
{What was checked, how compatibility was verified}
```
