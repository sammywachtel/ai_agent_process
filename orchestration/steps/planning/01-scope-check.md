# Step 01: Scope Size Check (HARD GATE)

**Model tier:** cheap
**Tools needed:** Read
**Input:** Requirement file path (provided by coordinator)
**Output:** Return result to coordinator (do NOT create folders or write to `.run/`)

---

## Instructions

Follow the standard scope-sizing check process in **`process/scope-sizing-check.md`**.

Read the thresholds from **`orchestration/scope-sizing-rules.md`**.

## Context for This Step

- **You are:** The planning coordinator's scope gatekeeper
- **Your goal:** Catch oversized requirements before planning begins
- **Blocking gate:** If `VERDICT: FAIL`, planning stops until breakdown or override

## Important: No Folder Creation

This step runs BEFORE the work folder exists. Do NOT:
- Create `.agent_process/work/{scope}/`
- Write to `.run/planning/`
- Create any GitHub issues

Simply evaluate and return the result.

## What Happens Next

- If `VERDICT: PASS` or `WARN` → Continue to Step 02
- If `VERDICT: FAIL` → Coordinator offers breakdown (Step 01b)

## Output

Return your assessment to the coordinator using the output format from `process/scope-sizing-check.md`.
