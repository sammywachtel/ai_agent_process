# Step 03: Review Actual Code (Technical Feasibility)

**Model tier:** capable
**Tools needed:** Read, Grep, Glob
**Input:** Requirement file path
**Output:** `.run/planning/03-code-review.md`

---

## Your Task

Review the actual codebase to assess technical feasibility of the requirement. This is NOT implementation — you're gathering intelligence for the planner.

## Review Process

### 1. Read CLAUDE.md Files

Check for development patterns and conventions:
- Root: `.claude/CLAUDE.md` or `CLAUDE.md`
- For each directory that will be modified, check `{directory}/CLAUDE.md`

Focus on: code patterns, testing requirements, architectural constraints, naming conventions.

### 2. Read Files Mentioned in Requirements

Open each file the requirement says will be modified or created. For files to modify:
- Understand current implementation
- Identify patterns and architecture
- Note dependencies (imports, exports, API contracts)

### 3. Assess Technical Feasibility

- Is the requirement achievable with current codebase structure?
- Are there framework limitations?
- What's the recommended implementation approach?

### 4. Identify Risks

- External dependencies?
- Breaking changes to APIs or contracts?
- Performance considerations?
- Files that look fragile or heavily coupled?

### 5. Check for Clarification Needs

If anything in the requirement is ambiguous or technically impossible, document the questions.

## Output Format

Write to `.run/planning/03-code-review.md`:

```markdown
# Code Review — Technical Feasibility

**Requirement:** {id}

## CLAUDE.md Patterns
{Key patterns and conventions found in CLAUDE.md files relevant to this scope}

## Current State
{What exists today in the files this scope will touch}

## Technical Assessment
- **Feasible:** YES/NO
- **Approach:** {recommended implementation strategy}
- **Complexity:** simple/moderate/complex

## Dependencies
{List of files/modules/APIs this scope depends on}

## Risks
{Identified risks with severity: low/medium/high}

## Implementation Guidance
{Specific patterns to follow, pitfalls to avoid, conventions to maintain}

## Clarification Questions
CLARIFICATION_NEEDED: true/false

{If true, list numbered questions that must be answered before planning continues}
```
