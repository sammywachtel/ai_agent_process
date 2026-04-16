# Plan Scope Coordinator (Lean)

Plan a scope in 4 steps instead of 13.

## Prohibitions

- Do NOT commit, push, or modify application code during planning
- Planning artifacts go to `.agent_process/work/{scope}/.run/planning/` only

---

## Step 0: Resolve Input

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{input}}"
```

Returns: `scope`, `requirement_path`, `gh_issue`. 

If `requirement_path` is null, ask user for the requirement path.

Read the requirement file.

---

## Step 1: Scope Setup (HARD GATE)

Spawn **cheap** agent:

```
Agent({
  description: "Setup scope {scope}",
  prompt: "Read orchestration/steps/planning/01-setup.md and execute.
    Requirement: {requirement_path}
    
    Check scope size, derive names, create work folder.
    If FAIL: offer breakdown or override.
    Output: .run/planning/01-setup.md"
})
```

**Gate:** If `VERDICT: FAIL`, stop and offer breakdown. Do not proceed until PASS/WARN.

---

## Step 2: Technical Assessment

Spawn **capable** agent:

```
Agent({
  description: "Assess {scope}",
  prompt: "Read orchestration/steps/planning/02-assess.md and execute.
    Requirement: {requirement_path}
    Scope: {scope}
    
    Query knowledge base, review code feasibility, document design decisions.
    Capture WHY decisions were made, not just WHAT.
    Output: .run/planning/02-assess.md"
})
```

---

## Step 3: Define Scope

Spawn **capable** agent:

```
Agent({
  description: "Define {scope}",
  prompt: "Read orchestration/steps/planning/03-define.md and execute.
    Requirement: {requirement_path}
    Scope: {scope}
    Input: .run/planning/02-assess.md
    
    Define files, create frozen criteria, assess doc impact.
    Output: .run/planning/03-define.md"
})
```

---

## Step 4: Create Plan

Spawn **synthesis** (best model) agent:

```
Agent({
  description: "Create plan for {scope}",
  prompt: "Read orchestration/steps/planning/04-plan.md and execute.
    Requirement: {requirement_path}
    Scope: {scope}
    Inputs: All .run/planning/*.md files
    
    Document pre-existing issues, create validation script, write iteration plan.
    Include Design Decisions table from assessment.
    Output: .agent_process/work/{scope}/iteration_plan.md"
})
```

---

## Human Prerequisites (if needed)

If this scope requires human collaboration during execution (environment setup, credentials, manual verification, production sign-off), create:

```
.agent_process/work/{scope}/human-prereqs.md
```

Template:
```markdown
# Human Prerequisites

## Pause Point
{before live validation / before deploy / before external API calls}

## Human Actions Required
- [ ] {action 1}
- [ ] {action 2}

## Allowed Responses
- **proceed** — prerequisites satisfied, continue execution
- **blocked** — cannot proceed, stop and report
- **local-only** — skip live/external validation, note limitation in results
```

This file is optional — only create it if the scope genuinely needs human checkpoints. The executor will pause at the specified point and wait for the human response.

---

## GitHub Issues (if enabled)

After plan created:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh start {scope}
```

This creates/adopts the issue and sets `status:planning`.

---

## Completion

Verify outputs:
- `.run/planning/01-setup.md`
- `.run/planning/02-assess.md`
- `.run/planning/03-define.md`
- `.agent_process/work/{scope}/iteration_plan.md`

Report to user:

```markdown
## Planning Complete

**Scope:** {scope}
**Plan:** `.agent_process/work/{scope}/iteration_plan.md`

- Files: {N}
- Criteria: {N}
- Pre-existing issues: {N} (will SKIP)

**Next:** `/ap_exec {scope} iteration_01`
```
