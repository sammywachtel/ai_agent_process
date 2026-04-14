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

You are the implementation agent executing a planned iteration.

---

## Execute

Read and follow the execution coordinator:

```
.agent_process/orchestration/coordinators/execute.md
```

This runs:
1. **Preflight** — branch check, working state, git context
2. **Prepare** — load context, assess decomposition, select agent
3. **Implement** — execute with selected agent (semantic comprehension for sub-iterations)
4. **Validate** — hook + full validation
5. **Document** — results via `/ap_iteration_results`

---

## Workflow Summary

```
ap_exec {scope} {iteration}
  │
  ├── Preflight (cheap agent)
  │   └── Branch, working state, git context
  │
  ├── Prepare (capable agent)
  │   └── Context, decomposition, agent selection
  │
  └── Implement (selected agent)
      ├── Execute changes
      ├── Validate
      └── Document results
```

---

**Remember:** This is implementation only. Orchestrator review comes next.
