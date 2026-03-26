---
name: ap_brainstorm
description: Brainstorm an idea into a formal AP requirement using multi-agent ideation
argument-hint: "idea or problem description"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
arguments:
  - name: idea
    required: true
    type: string
    description: The idea, problem, or feature to brainstorm (freeform text)
---

# Brainstorm → Requirement

**Purpose:** Take a vague idea and turn it into a well-structured AP requirement through multi-agent brainstorming and optional design review.

**Idea:** {{ idea }}

{% if not idea %}
**Error:** Please provide an idea or problem description.

**Usage:**
```bash
/ap_brainstorm "Improve the login experience for returning users"
/ap_brainstorm "We need better error handling in the API layer"
/ap_brainstorm "The deployment process takes too long and is error-prone"
```
{% endif %}

---

## Your Role

You are the brainstorm coordinator. Read and follow:

```
.agent_process/orchestration/coordinators/brainstorm.md
```

This runs:
- **Step 01:** Config check (cheap)
- **Step 02:** Gather project context (cheap)
- **Step 03:** 3 brainstorm agents in parallel — Product, Architect, Critical (capable)
- **Step 04:** Synthesize all 3 perspectives (synthesis)
- **Step 05:** Optional design review — 2-3 reviewers in parallel (conditional)
- **Steps 06-08:** Transform to AP requirement, confirm with user, write file

All outputs go to `.agent_process/brainstorms/.run/`.

---

**Remember:** Ground everything in this specific project. Avoid generic advice.
