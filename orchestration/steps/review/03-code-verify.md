# Step 03: Code Verification

**Model tier:** capable
**Tools needed:** Read, Grep, Glob
**Input:** scope, iteration
**Output:** `.run/review/03-code-verify.md`

---

## Your Task

Verify what was actually done by reading the code — not just trusting results.md. This is ground truth.

## Process

1. **Read results.md** for claimed changes
2. **Open each file listed as changed** and verify the claims
3. **Cross-check:** Do the actual code changes match what results.md says?

## Assessment Areas

- **Documentation accuracy:** Does results.md match reality?
- **Code quality:** Clean, maintainable, follows existing patterns?
- **Test coverage:** Do tests actually exercise the changes?
- **Architecture fit:** Changes align with existing codebase?
- **Completeness:** Are changes actually complete?

## Output Format

Write to `.run/review/03-code-verify.md`:

```markdown
# Code Verification

**Documentation accuracy:** Match / Partial / Mismatch

## Claimed vs Actual

| Claim (from results.md) | Actual (from code) | Match? |
|--------------------------|-------------------|--------|
| {claim 1} | {what code shows} | YES/NO |
| {claim 2} | {what code shows} | YES/NO |

## Quality Assessment
- {observation 1}
- {observation 2}

## Completeness
- ✅ {completed aspect}
- ⚠️ {incomplete aspect}
- ❌ {missing aspect}

## Recommendation Basis
{Why APPROVE/ITERATE/BLOCK/PIVOT based on actual code, not documentation}
```
