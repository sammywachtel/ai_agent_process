# Plan New Scope

## Context for Codex
Load the following before proceeding:
- `.agent_process/codex/00_base_context.md` (base rules)
- `.agent_process/codex/01_plan_scope_instructions.md` (detailed steps)

Follow the instructions exactly.

---

## Requirements Document
**Location:** `.agent_process/requirements_docs/lexical_stress_rendering_containment_requirements.md`

---

## Instructions for Codex

###  1. Load Requirements
Read the requirements document specified above

### 2. Assess Scope Size
Run the 5-second scope check from instructions:
- Can explain in one sentence?
- Clear "done" definition?
- Completable in 1-2 weeks?
- Specific name (not "cleanup" or "improve")?

**If TOO LARGE:**
- STOP - Do not create work folder
- Provide splitting recommendations
- Suggest multiple smaller scopes
- Wait for human to create separate requirements docs

**If GOOD SIZE:**
- Proceed to Step 3

### 3. Review Actual Code (Technical Feasibility)
Before creating scope structure, review the code files mentioned in requirements:
- Read each file
- Document current state
- Identify risks
- Recommend implementation approach
- Ask clarification questions if needed

**If clarifications needed:**
- STOP - Return questions to human
- Wait for answers before proceeding

**If feasible and clear:**
- Proceed to Step 4

### 4. Create Scope Structure
Following the instructions:
- Create work folder
- Create `iteration_plan.md` with LOCKED criteria
- Create `requirements_breakdown.md` (split requirements by iteration)
- Create scoped validation script
- Create `iteration_01/` placeholder

### 5. Provide Summary
Summarize scope for human approval before execution

---

## Human Notes (Optional)
[Any additional context not in requirements doc]

---

**Remember:** Follow iteration budget rules (max 3 sub-iterations per iteration)
