---
description: Execute one iteration - implement changes, validate, and document results
argument-hint: [scope] [iteration]
---

## Local Environment Instructions

**BEFORE proceeding, check for local environment instructions:**

```bash
cat .agent_process/process/local_environment_instructions.md 2>/dev/null
```

If this file exists and contains instructions beyond the default placeholder, follow them in addition to the workflow below.

---

## Quality Configuration

**Load quality gate settings:**

```bash
cat .agent_process/quality-config.json 2>/dev/null
```

Key settings: `pre_flight.enabled`, `adversarial_review.enabled`, `work_unit_decomposition.enabled`, `github_issues.enabled`.

---

## Arguments

**`$1` (scope)** - Required. Scope folder name under `.agent_process/work/`.

**`$2` (iteration)** - Required. Iteration folder name (e.g., `iteration_01`, `iteration_01_a`).

---

## Your Role

You are the implementation agent executing a planned iteration. Follow the two-part execution workflow: preflight checks, then implementation.

---

## Part 1: Preflight

Read and follow the preflight coordinator:

```
.agent_process/orchestration/coordinators/execute-preflight.md
```

This runs:
- **Step 0.4:** GitHub Issues health check (conditional)
- **Step 0.5:** Scope tracking init (direct bash call)
- **Step 0.7:** Pre-flight checks — session recovery, working tree, branch, git context (4 parallel sub-agents)
- **Step 1:** Load context from iteration plan (capable sub-agent)
- **Step 1.25:** Assess work unit decomposition (capable sub-agent)
- **Step 1.5:** Select specialized agent (cheap sub-agent)

All outputs go to `.agent_process/work/{scope}/.run/`. If any gate check fails, the coordinator will stop and tell you what to do.

---

## Part 2: Implementation

After preflight completes, read and follow the main execution prompt:

```
.agent_process/orchestration/coordinators/execute-main.md
```

This handles:
- **Step 2:** Implement changes (Agent tool with selected specialist)
- **Step 3:** Validate (hook fires automatically)
- **Step 4:** Run full validation commands
- **Step 4.5:** Adversarial review (fresh agent, if enabled)
- **Step 5:** Document results via `/ap_iteration_results`
- **Step 6:** Report completion to user

The main prompt reads all preflight outputs from `.run/` — it does not repeat any preflight logic.

---

## Workflow Summary

```
ap_exec {scope} {iteration}
  │
  ├── Preflight (sub-agents)
  │   ├── GH Issues health check (bash)
  │   ├── Scope tracking init (bash)
  │   ├── 4 parallel checks (cheap)
  │   ├── Load context (capable)
  │   ├── Decomposition assessment (capable)
  │   └── Agent selection (cheap)
  │
  └── Implementation (main session)
      ├── Implement with selected agent(s)
      ├── Validate (hook + full commands)
      ├── Adversarial review (fresh agent)
      ├── Document results
      └── Report completion
```

---

**Remember:** This is implementation only. Orchestrator review comes next.
