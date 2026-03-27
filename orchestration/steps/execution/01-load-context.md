# Step 01: Load Context

**Model tier:** capable
**Tools needed:** Read, Bash
**Input:** scope, iteration
**Output:** `.run/execution/01-context.md`

---

## Your Task

Read the iteration plan and extract everything the implementation agent needs. Handle sub-iteration context loading and vague-instruction detection.

## Read the Plan

```bash
cat .agent_process/work/{scope}/iteration_plan.md
```

Extract and summarize:
- Acceptance Criteria (LOCKED)
- Technical Assessment (implementation guidance)
- Files in Scope
- Validation Requirements (which commands to RUN vs SKIP)
- Out of Scope
- Known Patterns & Constraints (from knowledge base)
- Documentation in Scope

## Sub-iteration Handling

If this is a sub-iteration (e.g., `iteration_01_a`), also read:

1. **Current iteration placeholder** (created by orchestrator):
   `.agent_process/work/{scope}/{iteration}/results.md`
   Extract: required fixes (1-3 specific issues)

2. **Previous iteration results** (what was already tried):
   - `iteration_01_a` → read `iteration_01/results.md`
   - `iteration_01_b` → read `iteration_01_a/results.md`
   - `iteration_01_c` → read `iteration_01_b/results.md`
   - `iteration_02_a` → read `iteration_02/results.md`
   Extract: what worked (don't break), what didn't (don't repeat)

## Vague Instruction Detection

Check the required fixes for vague indicators:
- Line ranges >50 lines
- No before/after examples for CSS/markup
- Action verbs without specifics ("scope", "refactor", "improve")
- "Remaining" or "various" without enumeration

If vague: set `CLARIFICATION_NEEDED: true` in output with specific questions.

## Branch and Config Verification

Ensure correct branch:
```bash
EXPECTED="scope/{scope}"
CURRENT=$(git branch --show-current)
[ "$CURRENT" != "$EXPECTED" ] && git checkout "$EXPECTED" 2>/dev/null || git checkout -b "$EXPECTED"
```

Ensure `current_iteration.conf` matches:
```bash
cat > .agent_process/work/current_iteration.conf <<EOF
SCOPE={scope}
ITERATION={iteration}
EOF
```

Create iteration folder:
```bash
mkdir -p .agent_process/work/{scope}/{iteration}
```

## Output Format

Write to `.run/execution/01-context.md`:

```markdown
# Execution Context

**Scope:** {scope}
**Iteration:** {iteration}
**Type:** first_iteration / sub_iteration
CLARIFICATION_NEEDED: true/false

## Acceptance Criteria (LOCKED)
{Criteria verbatim from plan}

## Implementation Guidance
{Technical assessment summary}

## Files in Scope
{File list}

## Validation
**RUN:** {commands}
**SKIP:** {commands with reasons}

## Sub-iteration Fixes (if applicable)
{1-3 specific fixes from orchestrator}

## Previous Results (if sub-iteration)
{What worked, what didn't}

## Clarification Questions (if any)
{Numbered questions}
```
