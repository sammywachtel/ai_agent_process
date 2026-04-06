# Plan New Scope

## Your Role
You are the orchestrator planning a new development scope. You will follow a coordinator that breaks planning into focused sub-agent steps.

## ⚠️ SESSION BOUNDARIES

This is designed for a separate orchestration session. Key points:

1. **Fresh Session**: Assume no prior context - load all files explicitly using Read tool
2. **Read-Only Review**: Do not modify application code (only create process artifacts)
3. **No Commits**: Do NOT commit or push — the user decides when to commit planning artifacts
4. **Handoff Required**: Stop and provide summary for human approval before execution
5. **Implementation Separate**: A different session will execute the work

**You are NOT the implementation agent.**
Your role: Plan → Review Code → Decide → Handoff to implementation

---

## Step 0: Load Context (READ THESE FILES FIRST)

Before proceeding, use the Read tool to load these files:

**Core context:**
1. `.agent_process/orchestration/context/base-context.md` - Quick onboarding to process rules
2. `.agent_process/README.md` - Process philosophy and principles

**Coordinator (your step-by-step orchestration guide):**
3. `.agent_process/orchestration/coordinators/plan-scope.md` - **Follow this file.** It tells you which sub-agents to spawn, in what order, and how data flows between steps.

**Templates (sub-agents will use these):**
4. `.agent_process/templates/iteration-plan.md` - Template for iteration plan
5. `.agent_process/requirements_docs/_TEMPLATE_requirements.md` - Requirements format

**Validation reference:**
6. `.agent_process/process/validation-playbook.md` - Validation patterns

Once you've loaded context, follow the coordinator from its first step.

---

## Input (Flexible)

You can receive ANY of these input formats:
- **GitHub issue number:** `#165`, `165`, or full URL
- **Scope name:** `transcript_pipeline_poc2-01`
- **Requirement path:** `architecture-refactor/transcript_pipeline_poc2-01.md`

**Step 0.1: Resolve Input**

Run this command to resolve the input to structured scope info:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{input}}"
```

This returns JSON with:
- `scope`: The scope name (used for work folder)
- `requirement_path`: Path to requirement doc
- `gh_issue`: Linked GitHub issue number (may be null)
- `input_type`: What you provided (issue, scope, or requirement_path)

Use the `requirement_path` from this output to load the requirement doc.

---

## Your Task

**Follow the coordinator at `orchestration/coordinators/plan-scope.md`.**

The coordinator breaks planning into focused steps, each executed by a sub-agent that receives only its own instructions (~40-80 lines). This prevents critical checks from being skipped.

Key steps the coordinator will guide you through:
- **Step 01:** Scope size check (hard gate — planning stops if scope too large)
- **Step 02:** Derive folder name from requirement ID
- **Parallel A:** Knowledge base query + code review (run simultaneously)
- **Step 04-05:** Define files in scope + create frozen criteria
- **Parallel B:** Doc impact + pre-existing issues + validation script (run simultaneously)
- **Step 08:** Aggregate all outputs into `iteration_plan.md`
- **Step 08.5:** Design review (conditional, for complex scopes only)
- **Steps 09-12:** Create folders, config, roadmap update, handoff

Each step writes its output to `.agent_process/work/{scope}/.run/` so subsequent steps can read it.

---

## Tools Available

Use these tools throughout:

- **Read**: Load requirements, review code files, load context
- **Write**: Create new files (iteration_plan.md, validation scripts, etc.)
- **Edit**: Modify existing files if needed
- **Bash**: Create directories, make scripts executable (chmod +x)
- **Glob/Grep**: Search for code patterns when assessing feasibility
- **Agent/Task**: Spawn focused sub-agents for each step (Claude Code)

---

## Human Notes (Optional)
[Any additional context not in requirements doc]

---

**Remember:**
- Load context files first (Step 0)
- Follow the coordinator — it handles sequencing and parallelism
- Each sub-agent sees only its step file (~40-80 lines), keeping focus sharp
- Stop and provide handoff summary for approval
