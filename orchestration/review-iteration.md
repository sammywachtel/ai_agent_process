# Review Iteration Results

## Your Role
You are the orchestrator reviewing completed iteration work. You will follow a coordinator that breaks review into focused sub-agent steps, including 5 verification gates that run in parallel.

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
1. `.agent_process/orchestration/context/base-context.md` - Quick onboarding to process rules
2. `.agent_process/README.md` - Process philosophy and principles

**Coordinator (your step-by-step orchestration guide):**
3. `.agent_process/orchestration/coordinators/review-iteration.md` - **Follow this file.** It tells you which sub-agents to spawn, in what order, and how to pass data between steps.

**Iteration artifacts:**
4. `.agent_process/work/[scope]/iteration_plan.md` - Frozen criteria
5. `.agent_process/work/[scope]/[iteration]/results.md` - Implementation self-report
6. `.agent_process/work/[scope]/[iteration]/test-output.txt` - Validation results

Once you've loaded context, follow the coordinator from its first step.

---

## Iteration to Review

**Scope:** {scope_name}
**Iteration:** iteration_01
**Notes:** See QA results in results.md

---

## Your Task

**Follow the coordinator at `orchestration/coordinators/review-iteration.md`.**

The coordinator breaks review into focused steps:
- **Step 01:** Load context and determine iteration state
- **Step 1.5:** BEADS verification (direct bash)
- **Parallel Gates:** 5 verification gates run simultaneously:
  - Criteria evaluation, code verification, doc verification, integration verification, adversarial review
- **Step 04-05:** Aggregate gates + count attempts
- **Step 06:** HIGH STAKES decision (APPROVE/ITERATE/BLOCK/PIVOT) — uses best model
- **Steps 07-10:** Post-decision actions (artifacts, knowledge, BEADS, handoff)

Each step writes output to `.agent_process/work/{scope}/.run/` so subsequent steps can read it.

---

## Tools Available

- **Read**: Load context, artifacts, and actual code files
- **Write**: Create follow-up artifacts if ITERATE decision
- **Bash**: Create directories, run BEADS lifecycle commands
- **Grep/Glob**: Search code patterns during verification gates
- **Agent/Task**: Spawn focused sub-agents for each step (Claude Code)

---

## Human Notes (Optional)
[Manual testing observations, concerns, specific areas to check]

---

**Remember:**
- Load context files first (Step 0)
- Follow the coordinator — it handles sequencing and parallelism
- 5 verification gates run in parallel for faster review
- The decision step uses the best available model — it's the highest-stakes call in AP
- Stop and wait for human approval before executing post-decision actions
