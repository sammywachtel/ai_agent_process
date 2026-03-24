---
name: ap_brainstorm
description: Brainstorm an idea into a formal AP requirement using multi-agent ideation
argument-hint: "idea or problem description"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite]
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

## Step 1: Check Metaswarm Configuration

Read `.agent_process/quality-config.json` and check:
- `metaswarm.enabled` — master switch
- `metaswarm.features.brainstorm` — brainstorm feature flag

**If metaswarm is disabled or `features.brainstorm` is `false`:**
This command works without metaswarm — it uses built-in multi-agent brainstorming.
No action needed, proceed to Step 2.

**If metaswarm is enabled:**
Check if metaswarm agents are available for enhanced brainstorming
(e.g., `~/.claude/agents/brainstorm*.md` or `.claude/agents/brainstorm*.md`).
If found, note them for use in Step 2. If not found, use built-in approach.

## Step 2: Gather Project Context

Before brainstorming, collect context that grounds the ideation:

1. **Read the project README** (if exists) — understand what this project does
2. **Scan existing requirements:**
   ```bash
   ls .agent_process/requirements_docs/ 2>/dev/null
   ```
3. **Check the backlog** for related items:
   ```bash
   grep -i "relevant_keywords" .agent_process/roadmap/backlog.md 2>/dev/null
   ```
4. **Query knowledge base** for related patterns/gotchas:
   ```bash
   for f in .agent_process/knowledge/*.jsonl; do
     grep -i "relevant_keywords" "$f" 2>/dev/null
   done
   ```

Summarize the context in a few bullet points for the brainstorm agents.

## Step 3: Multi-Agent Brainstorm

Spawn **3 brainstorm agents in parallel** using the Agent tool. Each agent gets a different perspective to ensure diverse thinking. All agents receive the same idea and project context.

```
Agent({
  subagent_type: "general-purpose",
  description: "Brainstorm: Product perspective",
  prompt: `You are a Product Strategist brainstorming a feature idea.

IDEA: {{ idea }}

PROJECT CONTEXT:
[Insert context from Step 2]

Your job is to explore this idea from a product perspective. Produce a structured
analysis covering:

1. **Problem Statement** — What user pain or business need does this address?
   Be specific about who is affected and how.

2. **Proposed Approach** — 2-3 possible solutions, from simplest to most ambitious.
   For each, describe the core mechanism and key trade-offs.

3. **Success Criteria** — How would we know this worked? List 3-5 measurable
   outcomes (not implementation tasks).

4. **Risks & Open Questions** — What could go wrong? What do we not know yet?
   What assumptions are we making?

5. **Scope Boundaries** — What is explicitly NOT part of this? Where should we
   draw the line to keep this shippable?

Be concrete and specific to this project. Avoid generic advice.
Output in markdown format.`
})

Agent({
  subagent_type: "general-purpose",
  description: "Brainstorm: Architecture perspective",
  prompt: `You are a Software Architect brainstorming a feature idea.

IDEA: {{ idea }}

PROJECT CONTEXT:
[Insert context from Step 2]

Your job is to explore this idea from a technical architecture perspective.
Produce a structured analysis covering:

1. **Technical Feasibility** — Can this be done with the current stack?
   What new components or dependencies would be needed?

2. **Implementation Approach** — Describe the high-level technical design.
   What systems are involved? What's the data flow?

3. **Files & Components Likely Affected** — Based on the project structure,
   which areas of the codebase would this touch?

4. **Integration Points** — Where does this connect to existing systems?
   What interfaces need to change?

5. **Technical Risks** — Performance implications, scalability concerns,
   migration complexity, backwards compatibility issues.

6. **Complexity Assessment** — Simple (1-2 files, single domain),
   Moderate (3-5 files, 2 domains), or Complex (6+ files, 3+ domains)?

Be concrete and specific to this project. Avoid generic advice.
Output in markdown format.`
})

Agent({
  subagent_type: "general-purpose",
  description: "Brainstorm: Critical perspective",
  prompt: `You are a Devil's Advocate reviewing a feature idea.

IDEA: {{ idea }}

PROJECT CONTEXT:
[Insert context from Step 2]

Your job is to stress-test this idea by finding weaknesses, alternatives,
and hidden assumptions. Produce a structured analysis covering:

1. **Assumption Check** — What assumptions does this idea make?
   Which of those might be wrong?

2. **Alternative Approaches** — Are there simpler ways to achieve the same
   outcome? Could we solve this without building anything new?

3. **Failure Modes** — How could this go wrong? What are the worst-case
   scenarios? What happens if we ship this and it doesn't work?

4. **Dependencies & Blockers** — What external factors could block this?
   What needs to be true for this to succeed?

5. **Honest Assessment** — Should we do this at all? Is this the highest-impact
   thing we could work on? What's the opportunity cost?

Be constructively critical. The goal is to make the requirement stronger,
not to kill the idea. Output in markdown format.`
})
```

**Launch all 3 agents in parallel** (single message, multiple Agent tool calls).

## Step 4: Synthesize Results

After all 3 agents return, synthesize their outputs into a unified brainstorm document:

### Brainstorm Synthesis Format

```markdown
# Brainstorm: {{ idea }}

**Date:** {{ current_date }}
**Perspectives:** Product, Architecture, Critical

---

## Problem Statement
[Synthesized from Product agent — the clearest articulation of the problem]

## Proposed Approach
[Synthesized from all three — the approach that best balances feasibility,
impact, and risk. Note where agents disagreed and why you chose this direction.]

## Success Criteria
[From Product agent, refined by Architecture and Critical perspectives]
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Assessment
- **Complexity:** [From Architecture agent]
- **Key components:** [From Architecture agent]
- **Files likely affected:** [From Architecture agent]

## Risks & Mitigations
[Merged from all three agents, deduplicated]
- Risk 1: [mitigation]
- Risk 2: [mitigation]

## Scope Boundaries (Out of Scope)
[From Product + Critical agents]

## Open Questions
[Unresolved items from all three agents that need human input]

## Alternative Approaches Considered
[From Critical agent — what we chose NOT to do and why]
```

Save this to `.agent_process/brainstorms/{{ normalized_idea_name }}.md`:
```bash
mkdir -p .agent_process/brainstorms
```

## Step 5: Optional Design Review

**Check `quality-config.json`:** If `metaswarm.features.design_review` is `true`:

Ask the user:
> "Brainstorm complete. Want to run a multi-agent design review before creating the requirement?
> This gets feedback from Architect, Security, and Product/UX perspectives on the proposed approach.
>
> 1. **Yes, run design review** (recommended for complex features)
> 2. **Skip, create requirement now**"

**If yes:** Spawn 2-3 design review agents in parallel using the same Agent tool pattern,
following the reviewer prompts in `templates/design-review-prompt.md`. Feed them the
brainstorm synthesis as the "plan" to review.

Append the design review verdicts to the brainstorm document under a
`## Design Review Feedback` section.

**If no or if design review is disabled:** Proceed to Step 6.

## Step 6: Transform to AP Requirement

Map the brainstorm synthesis into the AP requirement template:

```markdown
---
id: {{ requirement_id }}
type: requirement
category: {{ category }}
status: not_started
priority: {{ priority }}
complexity: {{ simple | moderate | complex }}
source: ap-brainstorm
---

# Requirements: {{ derived_title }}

---

## Objective
{{ From brainstorm Problem Statement — one clear sentence }}

## Background
{{ From brainstorm Problem Statement — expanded context and motivation }}

---

## Technical Requirements
{{ From brainstorm Proposed Approach — as numbered list of specific requirements }}

---

## Success Criteria
{{ From brainstorm Success Criteria — as checkboxes }}

---

## Files Expected to Change
{{ From brainstorm Technical Assessment — files likely affected }}

---

## Out of Scope
{{ From brainstorm Scope Boundaries }}

---

## Known Risks
{{ From brainstorm Risks & Mitigations }}

---

## Notes

### Brainstorm Source
- **Brainstorm doc:** `.agent_process/brainstorms/{{ name }}.md`
- **Date:** {{ current_date }}
- **Perspectives consulted:** Product, Architecture, Critical

### Design Review
{{ If design review ran, summarize verdicts. Otherwise: "Not run." }}

### Open Questions
{{ From brainstorm — items needing human input before execution }}
```

## Step 7: Confirm with User

Present the transformed requirement for user review:

> "Here's the requirement generated from the brainstorm:"
>
> [Show key fields: title, category, priority, complexity, criteria count]
>
> "Confirm or adjust:"
> - **Title:** {{ derived_title }}
> - **Category:** [ask if not obvious from project context]
> - **Priority:** [suggest based on brainstorm urgency signals]
> - **Complexity:** [from Architecture agent's assessment]

## Step 8: Determine Location and Write

1. Ask user where to place (or suggest based on category):
   - Existing category (`requirements_docs/{category}/`)
   - New category
2. Generate requirement ID (same logic as `/ap_requirements add`):
   - Find existing IDs in the category
   - Suggest next available number + descriptor
3. Write the requirement file
4. Update master roadmap with NOT_STARTED status

## Step 9: Report Completion

```
✓ Brainstorm complete: {{ requirement_id }}
  Requirement: requirements_docs/{{ category }}/{{ requirement_id }}.md
  Brainstorm:  .agent_process/brainstorms/{{ name }}.md
  Category:    {{ category }}
  Priority:    {{ priority }}
  Complexity:  {{ complexity }}
  Criteria:    {{ count }} acceptance criteria

Next steps:
  1. Review and refine the requirement details
  2. Feed to orchestrator for scope planning
  3. Execute with /ap_exec
```
