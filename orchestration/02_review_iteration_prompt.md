# Review Iteration Results

## Your Role
You are the orchestrator reviewing completed iteration work. Follow the instructions exactly to make an evidence-based decision.

## ⚠️ SESSION BOUNDARIES

This is designed for a separate orchestration session. Key points:

1. **Fresh Session**: Assume no prior context - load all files explicitly using Read tool
2. **Read-Only Review**: Do not modify application code (only create review artifacts)
3. **Code Verification Required**: Read actual files to verify implementation (don't just trust documentation)
4. **Implementation Separate**: You are reviewing work done by a different session

**You are NOT the implementation agent.**
Your role: Load → Review Code → Decide → Document

---

## Step 0: Load Context (READ THESE FILES FIRST)

Before proceeding, use the Read tool to load these files:

**Core context:**
1. `.agent_process/orchestration/00_base_context.md` - Quick onboarding to process rules
2. `.agent_process/README.md` - Process philosophy and principles

**Instructions (detailed steps you'll follow):**
3. `.agent_process/orchestration/02_review_iteration_instructions.md` - Complete review workflow

**Iteration artifacts:**
4. `.agent_process/work/[scope]/iteration_plan.md` - Frozen criteria for this major iteration (check `## Criteria History` if a PIVOT occurred)
5. `.agent_process/work/[scope]/[iteration]/results.md` - Implementation self-report
6. `.agent_process/work/[scope]/[iteration]/test-output.txt` - Validation results

**Templates (you'll use if needed):**
7. `.agent_process/templates/iteration-feedback.md` - Template for ITERATE decisions

---

## Iteration to Review

**Scope:** {scope_name}
**Iteration:** iteration_01
**Notes:** See QA results in results.md

---

## Your Task

Follow the complete workflow in `02_review_iteration_instructions.md`.

**CRITICAL REMINDERS:**

1. **Step 3 (Review Actual Code) is MANDATORY**
   - Do NOT skip reading the actual code files
   - Cross-check results.md claims against reality
   - Include code verification in your decision

2. **Evaluate against the frozen criteria for THIS major iteration**
   - Use the current `## Acceptance Criteria` section in iteration_plan.md
   - After a PIVOT, criteria were revised — use the revised version, not v1
   - Do NOT add new criteria discovered during iteration
   - New issues → backlog, not this review

3. **Enforce iteration budget**
   - Max 3 sub-iterations (a/b/c)
   - If iteration_01_c: Can APPROVE if criteria met, cannot ITERATE (must BLOCK if criteria not met)

4. **Choose exactly one decision**
   - ✅ APPROVE - All criteria met, code verified (allowed at any iteration including _c)
   - 🔄 ITERATE - Fixable issues, attempts remaining (NOT allowed at _c - no _d iteration)
   - 🚫 BLOCK - External blocker OR criteria not met after iteration_01_c
   - 🔀 PIVOT - Scope change needed (requires human approval)

---

## Output Format

Use the decision templates from `02_review_iteration_instructions.md`.

**Required elements:**
- Decision type (APPROVE/ITERATE/BLOCK/PIVOT)
- Code verification section (what you found in actual files)
- Criteria status (checked against frozen criteria for this major iteration)
- Next step

**After providing your decision, ask the human:**

- **If ITERATE:** "Should I proceed to create iteration_01_a folder and update iteration_plan.md?"
- **If APPROVE:** "Should I mark the scope approved and update iteration_plan.md and the requirement doc status?"
- **If BLOCK:** "This requires human decision - no further action from me."
- **If PIVOT:** "Should I update iteration_plan.md with the proposed scope change (requires your approval first)?"

⏸️ **STOP and wait for human response before executing Steps 7-8.**

---

## Tools Available

- **Read**: Load context, artifacts, and actual code files
- **Write**: Create follow-up artifacts if ITERATE decision
- **Bash**: Create directories if needed for ITERATE
- **Grep**: Search code patterns during code review

---

## Human Notes (Optional)
[Manual testing observations, concerns, specific areas to check]

---

**Remember:** Follow `02_review_iteration_instructions.md` exactly. Step 3 (code review) is mandatory.
