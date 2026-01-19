# Plan New Scope

## Your Role
You are the orchestrator planning a new development scope. Follow the instructions exactly to create a well-scoped, executable plan.

## ⚠️ SESSION BOUNDARIES

This is designed for a separate orchestration session. Key points:

1. **Fresh Session**: Assume no prior context - load all files explicitly using Read tool
2. **Read-Only Review**: Do not modify application code (only create process artifacts)
3. **Handoff Required**: Stop and provide summary for human approval before execution
4. **Implementation Separate**: A different session will execute the work

**You are NOT the implementation agent.**
Your role: Plan → Review Code → Decide → Handoff to implementation

---

## Step 0: Load Context (READ THESE FILES FIRST)

Before proceeding, use the Read tool to load these files:

**Core context:**
1. `.agent_process/orchestration/00_base_context.md` - Quick onboarding to process rules
2. `.agent_process/README.md` - Process philosophy and principles

**Instructions (detailed steps you'll follow):**
3. `.agent_process/orchestration/01_plan_scope_instructions.md` - Complete planning workflow

**Templates (you'll use these):**
4. `.agent_process/templates/iteration-plan.md` - Template for iteration plan
5. `.agent_process/requirements_docs/_TEMPLATE_requirements.md` - Requirements format

**Validation reference:**
6. `.agent_process/process/validation-playbook.md` - Validation patterns

Once you've loaded context, proceed to Step 1.

---

## Requirements Document

**Location:** `.agent_process/requirements_docs/{{requirements_path}}`

**Work folder name:** Derive using naming convention in `01_plan_scope_instructions.md` Step 2.

---

## Your Task

Follow these steps from `01_plan_scope_instructions.md`:

### Step 1: Load Requirements
Use Read tool to open the requirements document specified above.

### Step 2: Assess Scope Size (5-second check)
- Can explain in one sentence?
- Clear "done" definition?
- Completable in 1-2 weeks?
- Specific name (not "cleanup" or "improve")?

**If TOO LARGE:**
- **OPTION A: Automated Breakdown (Recommended)**
  - Ask human if they want automatic requirements file splitting
  - If approved: Follow "Large Requirements File Breakdown" process from instructions
    - Rename original to `*-breakdown[.ext]` using `git mv`
    - Create numbered split files (`*-01[.ext]`, `*-02[.ext]`, etc.)
    - Update breakdown file with references to new files
    - Each split file references the original and indicates which part it is
- **OPTION B: Manual Splitting**
  - Provide detailed splitting recommendations
  - Wait for human to manually create separate requirements docs
- **Do NOT create work folder until requirements are properly sized**

**If GOOD SIZE:**
- Proceed to Step 3

### Step 3: Review Actual Code (Technical Feasibility)
Before creating scope structure, review the actual code:
- Use Read tool to open files mentioned in requirements
- Document current state
- Assess technical feasibility
- Identify risks and blockers
- Note implementation approach

**If clarifications needed:**
- **STOP** - Return questions to human
- Wait for answers before proceeding

**If feasible and clear:**
- Document findings in Technical Assessment
- Proceed to Step 4

### Step 4-11: Create Scope Structure
Following the detailed instructions:
- Create work folder (use Bash tool)
- Create `iteration_plan.md` with LOCKED criteria (use Write tool)
- Add Technical Assessment section with your code review findings
- Create `requirements_breakdown.md` (use Write tool)
- Create scoped validation script (use Write tool, then Bash to chmod +x)
- Create `iteration_01/` placeholder (use Bash and Write tools)
- Update current iteration config (use Write tool)
- Update roadmap if it exists: increment work scope count, change status 📋→🚧, add to Active Work section

### Step 12: Provide Handoff Summary
Summarize scope for human approval using this template:

```markdown
## Scope Ready: <scope_name>

**Objective:** [One sentence]

**Acceptance Criteria:** [Count] locked criteria

**Files in Scope:** [Count] files

**Technical Assessment Summary:**
- Current state: [Brief summary from code review]
- Recommended approach: [Brief summary]
- Known risks: [Brief summary]

**Validation:** Scoped script created at `.agent_process/scripts/after_edit/validate-<scope-name>.sh`

**Artifacts Created:**
- `.agent_process/work/<scope_name>/iteration_plan.md`
- `.agent_process/work/<scope_name>/requirements_breakdown.md`
- `.agent_process/work/<scope_name>/iteration_01/results.md` (placeholder)
- `.agent_process/scripts/after_edit/validate-<scope-name>.sh`
- `.agent_process/work/current_iteration.conf`

**Next Step:**
Human approval required. If approved, run in implementation session:
`/ap_exec <scope_name> iteration_01`
```

⏸️ **STOP HERE - Wait for human approval before execution.**

---

## Tools Available

Use these tools throughout:

- **Read**: Load requirements, review code files, load context
- **Write**: Create new files (iteration_plan.md, validation scripts, etc.)
- **Edit**: Modify existing files if needed
- **Bash**: Create directories, make scripts executable (chmod +x)
- **Glob/Grep**: Search for code patterns when assessing feasibility

---

## Human Notes (Optional)
[Any additional context not in requirements doc]

---

**Remember:**
- Load context files first (Step 0)
- Follow iteration budget rules (max 3 sub-iterations per iteration)
- Review actual code before creating scope (Step 3)
- Stop and provide handoff summary for approval
