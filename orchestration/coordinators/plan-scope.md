# Plan Scope Coordinator (Lean)

Plan a scope in 4 steps instead of 13.

## Model Tiers

| Tier | Use For | Claude Code | Codex |
|------|---------|-------------|-------|
| **cheap** | Scope setup, size check | haiku | gpt-5.4-mini |
| **capable** | Technical assessment | sonnet | gpt-5.4 |
| **synthesis** | Defining frozen criteria, creating final plan | opus | gpt-5.4 |

## Prohibitions

- Do NOT commit, push, or modify application code during planning
- Planning artifacts go to `<project_root>/.agent_process/work/{scope}/.run/planning/` only

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
    Output: <project_root>/.agent_process/work/{scope}/.run/planning/01-setup.md"
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
    Output: <project_root>/.agent_process/work/{scope}/.run/planning/02-assess.md"
})
```

---

## Step 3: Define Scope

Spawn **synthesis** agent — frozen criteria cascade through the entire pipeline:

```
Agent({
  model: "{synthesis}",  // Claude Code: "opus" | Codex: use best available
  description: "Define {scope}",
  prompt: "Read orchestration/steps/planning/03-define.md and execute.
    Requirement: {requirement_path}
    Scope: {scope}
    Input: <project_root>/.agent_process/work/{scope}/.run/planning/02-assess.md
    
    Define files, create frozen criteria, assess doc impact.
    Output: <project_root>/.agent_process/work/{scope}/.run/planning/03-define.md"
})
```

---

## Step 4: Create Plan

Spawn **synthesis** (best model) agent:

```
Agent({
  model: "{synthesis}",  // Claude Code: "opus" | Codex: use best available
  description: "Create plan for {scope}",
  prompt: "Read orchestration/steps/planning/04-plan.md and execute.
    Requirement: {requirement_path}
    Scope: {scope}
    Inputs: All <project_root>/.agent_process/work/{scope}/.run/planning/*.md files
    
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

Preferred template (keeps extraction simple and the gate unambiguous):
```markdown
# Human Prerequisites — {scope}

## Pre-execution (ask before work starts)
- [ ] {decision or action the human must resolve up front}

## Mid-execution (pause before live / external / destructive steps)
- [ ] {action and the trigger — e.g. "before hitting prod API"}

## Post-execution (ask after work completes)
- [ ] {follow-up, cutover, notification, prod parity confirmation}

## Allowed Responses
- **proceed** — prerequisites satisfied, continue execution
- **blocked** — cannot proceed, stop and report
- **local-only** — skip live/external validation, note limitation in results
```

**Looser formats are also accepted.** If a planner writes the file as "Required Decisions and Actions" + "Blocking Assumptions" + a numbered list, that is fine — the executor will classify items (defaulting to pre-execution) and surface them to the user. Structure helps, but the gate runs either way.

This file is optional — only create it if the scope genuinely needs human checkpoints. When it exists, the execution coordinator is required to present its contents to the human at Step 0.5 (before work) and Step 6 (after work) of `execute.md`; it will never silently skip.

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
- `<project_root>/.agent_process/work/{scope}/.run/planning/01-setup.md`
- `<project_root>/.agent_process/work/{scope}/.run/planning/02-assess.md`
- `<project_root>/.agent_process/work/{scope}/.run/planning/03-define.md`
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
