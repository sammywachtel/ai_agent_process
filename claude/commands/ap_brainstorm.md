---
name: ap_brainstorm
description: Brainstorm an idea into a formal AP requirement using multi-agent ideation
argument-hint: "#43 | idea or problem description"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
arguments:
  - name: idea
    required: true
    type: string
    description: The idea, problem, or feature to brainstorm (freeform text or #N issue reference)
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
/ap_brainstorm "#43"
```
{% endif %}

---

## Step 0: Issue Detection (before brainstorm)

Check if `{{ idea }}` starts with `#` followed by digits (e.g., `#43`):

**If issue reference detected:**

1. Read `.agent_process/quality-config.json` — check `github_issues.enabled`
2. If GH enabled:
   - Extract the issue number (strip `#`)
   - Read the issue: `gh issue view <N> --repo <REPO> --json title,body,labels`
   - If issue not found: **STOP** with clear error before brainstorm starts
   - Use the issue **title** as the brainstorm topic
   - Use the issue **body** as additional context (pass to Step 02 context gathering)
   - Store the issue number for post-brainstorm association (Step 9)
3. If GH disabled:
   - Warn: "GitHub Issues tracking is disabled. Cannot read issue #N. Please provide the idea as text instead."
   - **STOP** — don't guess what the issue contains

**If no issue reference:** proceed normally with `{{ idea }}` as the topic.

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

## Step 9: Post-Brainstorm Issue Association (if issue reference was provided)

After the requirement file is created (Steps 06-08):

1. Determine the scope name (the brainstorm directory name chosen in the coordinator)
2. Run: `bash .agent_process/scripts/github-issues-lifecycle.sh associate <scope> <issue_number>`
3. Comment on the issue: `bash .agent_process/scripts/github-issues-lifecycle.sh comment <scope> "Brainstorm complete. Requirement: requirements_docs/<category>/<scope>.md"`

If no issue reference was provided but GH is enabled:
- The issue will be created later during `plan-scope` (Step 0.5) — don't create one here.

**GitHub Issues:** Follow `process/github-issues-handling.md` for all issue operations.

---

**Remember:** Ground everything in this specific project. Avoid generic advice.
