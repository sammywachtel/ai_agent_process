# Step 01: Scope Size Check (HARD GATE)

**Model tier:** cheap
**Tools needed:** Read
**Input:** Requirement file path (provided by coordinator)
**Output:** Return result to coordinator (do NOT create folders or write to `.run/`)

---

## Important: No Folder Creation

This step runs BEFORE the work folder exists. Do NOT:
- Create `.agent_process/work/{scope}/`
- Write to `.run/planning/`
- Create any GitHub issues

Simply evaluate the requirement and return the result. The coordinator will handle folder creation if the check passes, or run breakdown if it fails.

---

## Your Task

1. Read `orchestration/scope-sizing-rules.md` — it defines the thresholds and override mechanism.
2. Read the requirement file.
3. Evaluate the requirement against the rules. This is a hard gate — if the scope exceeds Fail thresholds (and no `scope_override: true` in frontmatter), planning stops here.

## Evaluation

Apply the 5-Second Check and Size Thresholds from `scope-sizing-rules.md`. Check the requirement's frontmatter for `scope_override: true` — if present, shift Fail thresholds to Warning (see the rules file for details).

## Output Format

Write to `.run/planning/01-scope-check.md`:

```markdown
# Scope Check Results

**Requirement:** {id from frontmatter}

## 5-Second Check
1. One sentence: YES/NO — "{the sentence or why it fails}"
2. Done definition: YES/NO — "{summary or concern}"
3. Timeframe: YES/NO — "{estimate or concern}"
4. Specific name: YES/NO — "{name assessment}"

## Size Indicators
- Criteria count: {N} (target: 3-7)
- Files to change: {N} (target: 4-10)
- Subsystems: {N} (target: 1-3)

## VERDICT: PASS/FAIL

{If FAIL: explain why and suggest how to split. Example:
"This scope touches 3 subsystems with 12 criteria. Recommend splitting into:
1. {subsystem-a}: criteria 1-4
2. {subsystem-b}: criteria 5-8
3. {subsystem-c}: criteria 9-12"}
```
