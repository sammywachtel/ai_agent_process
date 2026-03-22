# Instructions – Plan New Scope

**Purpose:** Create new scope with frozen criteria and scoped validation

---

## CRITICAL: Scope Sizing First

**Before creating any scope, validate size:**

### 5-Second Scope Check
1. ✅ Can I explain this in one sentence?
2. ✅ Do I know what "done" looks like?
3. ✅ Can this be done in 1-2 weeks (1-5 iterations)?
4. ✅ Is the name specific (not "cleanup" or "improve")?

**If ANY answer is NO → Scope too large, split it**

### Target Scope Size
```
Duration: 1-2 weeks (5-10 work sessions)
Iterations: 1-5 numbered iterations
Sub-iterations: 0-3 per numbered iteration
Outcome: Shippable feature or measurable improvement
```

### Large Requirements File Breakdown

**If a requirements file is too large for a single scope:**

1. **Ask human for approval to split:**
   ```
   The requirements in [filename] are too large for one scope.

   Would you like me to automatically break this down into multiple
   properly-sized requirements files?

   If yes, I will:
   - Rename the original to [filename-basename]-breakdown[.ext]
   - Create multiple numbered files: [filename-basename]-01[.ext],
     [filename-basename]-02[.ext], etc.
   - Update the breakdown file to reference the new files
   ```

2. **If human approves, perform breakdown:**

   **Step A: Rename original file**
   ```bash
   # Example: requirements.md → requirements-breakdown.md
   # Example: epic-07.txt → epic-07-breakdown.txt
   git mv [original-file] [basename]-breakdown[.extension]
   ```

   **Step B: Create numbered requirement files**

   Files should be numbered to maintain alphanumeric order in the directory:
   ```bash
   # Example: requirements-01.md, requirements-02.md, requirements-03.md
   # Naming: [basename]-[##][.extension]
   ```

   **Step C: Update the breakdown file**

   **CRITICAL:** Change the frontmatter `type` from `requirement` to `breakdown`.
   This prevents the roadmap discovery process from counting the breakdown file
   as a separate requirement (which would duplicate the split files).

   Replace the file's frontmatter and add header with references to new files:
   ```markdown
   ---
   id: [original_id]
   type: breakdown
   category: [original_category]
   status: [original_status]
   priority: [original_priority]
   ---

   # [Original Title] - BREAKDOWN

   **Status:** This is the original requirements document. It has been
   split into multiple properly-sized requirements files for implementation.

   ## Split Requirements Files

   This original document has been broken down into the following files:

   1. `[basename]-01[.ext]` - [Brief description of scope 1]
   2. `[basename]-02[.ext]` - [Brief description of scope 2]
   3. `[basename]-03[.ext]` - [Brief description of scope 3]

   ## Original Content

   [Original content preserved below for reference]

   ---

   [... original requirements content ...]
   ```

   **Step D: Create each split requirements file**

   Each file should:
   - Follow the requirements template format
   - Be properly sized (passes 5-second scope check)
   - Reference the original breakdown file
   - Include header indicating it's part of a split

   ```markdown
   # [Scope-specific Title]

   **Part of:** `[basename]-breakdown[.ext]`
   **Split:** [X] of [N]

   [Properly-scoped requirements content]
   ```

3. **If human declines:**
   - Provide detailed splitting recommendations
   - Wait for human to manually create separate requirements docs
   - Do NOT create work folder

**Benefits of automated breakdown:**
- Preserves original requirements for reference
- Maintains alphanumeric ordering in requirements directory
- Uses `git mv` to preserve file history
- Creates traceable relationship between breakdown and split files
- Each split file is independently actionable

---

## Planning Steps

### Step 1: Clarify the Brief

**Ask human these questions:**

1. **Objective:** What specific outcome should this scope achieve? (one sentence)
2. **Success criteria:** How will we know when it's done? (measurable test/demo)
3. **Boundaries:** What's explicitly out of scope?
4. **Priority:** What's the relative importance (CRITICAL/HIGH/MEDIUM/LOW)?
5. **Risk:** Any known blockers or dependencies?

**Red flags that scope is too large:**
- Objective needs multiple paragraphs
- Success criteria includes "and" 3+ times
- Touches 10+ files
- Has dependencies on other in-progress work
- Uses vague verbs: "cleanup", "improve", "refactor" without specifics

---

### Step 2: Derive Work Folder Name

**Use the requirement's frontmatter `id:` as the work folder name.** This is the single source of truth — one requirement ID = one work folder name. See `process/naming_conventions.md`.

#### Primary: Frontmatter ID (requirements with `type: requirement`)

1. Read the requirement document's YAML frontmatter
2. Extract the `id:` field
3. Use it verbatim as the work folder name

```
Requirement frontmatter:  id: lexical_epic_08_navigation
Work folder:              .agent_process/work/lexical_epic_08_navigation/
```

#### Fallback: Path-Based Derivation (ad-hoc work only)

When there is no requirements doc (hotfixes, quick tasks), derive a name from context:

```
hotfix_<area>_<brief_description>
```
Example: `hotfix_lexical_cursor_jump`

#### Good vs Bad Names

**Good (matches frontmatter ID):**
- `lexical_epic_06_save` (matches `id: lexical_epic_06_save`)
- `code_quality_scope_03_editor_ref` (matches `id: code_quality_scope_03_editor_ref`)
- `hotfix_lexical_cursor_jump` (clear ad-hoc pattern, no requirement doc)

**Bad (diverges from ID or is vague):**
- `lexical_editor_lexical_epic_06_save` (redundant — derived from path instead of ID)
- `lexical_cleanup` (what does "cleanup" mean?)
- `improve_editor` (no boundary)
- `fix_bugs` (which bugs?)

#### Naming Validation

Before creating work folder, verify:
- [ ] Folder name matches the requirement's frontmatter `id:` exactly
- [ ] No category prefix was accidentally doubled from path derivation
- [ ] Ad-hoc work (no requirement doc) uses the `hotfix_` prefix

**Create directory:**
```bash
mkdir -p .agent_process/work/<scope_name>
```

---

### Step 2.5: Query Knowledge Base

**Before reviewing code, check for accumulated project wisdom:**

The knowledge base (`.agent_process/knowledge/`) stores patterns, gotchas, decisions, and anti-patterns from previous iterations. Querying it before code review helps you know what to look for and what to avoid.

**If knowledge directory exists:**

1. **Extract search terms** from the requirement:
   - Category name (e.g., `auth`, `frontend`, `lexical_editor`)
   - Key component or file names from the requirements doc
   - Technical concepts involved (e.g., "JWT", "caching", "API design")

2. **Search all knowledge files:**
   ```bash
   # Search by category/scope
   grep -i "<category>" .agent_process/knowledge/*.jsonl

   # Search by keywords from the requirement
   grep -i "<keyword1>\|<keyword2>" .agent_process/knowledge/*.jsonl
   ```

3. **Record findings** for the `## Known Patterns & Constraints` section of `iteration_plan.md`:
   - Include the entry's `summary` and `source_iteration` for traceability
   - Prioritize entries matching the scope's category over general entries
   - Include gotchas and anti-patterns even if only tangentially related — they're cheap insurance

4. **If no relevant entries found** (common for new categories or early in a project), note it:
   ```markdown
   ## Known Patterns & Constraints
   *No relevant knowledge base entries for this scope.*
   *Keywords searched: auth, session, login*
   ```

**If knowledge directory doesn't exist:** Skip this step. The knowledge base is created by `install.sh` and grows organically through APPROVE deposits.

**Reference:** See `process/knowledge-base.md` for the full knowledge base how-to guide.

---

### Step 3: Review Actual Code (Technical Feasibility)

**Before creating scope structure, review the actual code:**

1. **Review CLAUDE.md files for development patterns:**
   - **Root CLAUDE.md:** Read `.claude/CLAUDE.md` or `CLAUDE.md` for general project-specific instructions
   - **Nested CLAUDE.md files:** For each directory containing files you plan to create/edit, check for `<directory>/CLAUDE.md`
   - **Pattern focus:** These files contain critical instructions on:
     - Code patterns and conventions specific to that module
     - Development workflows and practices
     - Architectural decisions and constraints
     - Testing requirements and standards
   - **Priority:** Focus most on CLAUDE.md files nested within folders where files will be created or edited
   - **Integration:** Incorporate these patterns into your Technical Assessment and Implementation Guidance

2. **Read files mentioned in requirements:**
   - Open each file that will be modified
   - Understand current implementation
   - Identify patterns and architecture

3. **Document current state:**
   - What exists today?
   - What needs to change?
   - What are the dependencies?

4. **Assess technical feasibility:**
   - Is the requirement achievable?
   - Are there framework limitations?
   - What's the implementation approach?

5. **Identify risks and blockers:**
   - External dependencies?
   - Breaking changes?
   - Performance considerations?

6. **Ask clarification questions if needed:**
   ```markdown
   ## Clarification Questions for Human

   Based on code review, need clarification on:
   1. [Question about requirement X]
   2. [Question about technical approach Y]
   3. [Question about constraint Z]
   ```

**If clarifications needed:**
- STOP - Return questions to human
- Wait for answers before proceeding
- Do NOT create scope structure yet

**If feasible and clear:**
- Document findings in Technical Assessment section
- Provide implementation guidance for implementation session
- Proceed to Step 4

---

### Step 4: Define Files in Scope

**List specific files this scope will touch:**
```markdown
## Files in Scope
- path/to/file1.tsx
- path/to/file2.ts
- path/to/test1.test.tsx
- path/to/test2.test.ts

Total: 4-8 files (if >10, split scope)
```

**Why this matters:**
- Enables scoped validation (only test these files)
- Prevents false blockers from unrelated code
- Makes scope boundaries explicit

### Tag Shared-API Work (if applicable)

If the scope changes an API or payload consumed by other clients:
- Add `## Contract Consumers` to `iteration_plan.md` listing each client (web, mobile, CLI, partner service) and the file that defines its contract.
- Add `## API Contract` summarizing the expected request/response structure, required fields, wrappers, and error shapes.
- List the validation commands each consumer needs (type check, build, targeted tests, manual workflow) so implementation must run them.

---

### Step 5: Create Frozen Acceptance Criteria

**Template:**
```markdown
## Acceptance Criteria (LOCKED - DO NOT MODIFY)
- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] [Specific, testable criterion 3]

**CRITICAL:** These criteria are FROZEN at iteration start.
New issues discovered → backlog for future scopes.
No mid-iteration scope creep allowed.
```

**Good criteria (specific, testable):**
- [ ] StressedTextNode.autoDetectStress method removed
- [ ] analyzeWordStress moved to stressCoordinatorService.ts
- [ ] 12/12 StressCommands unit tests pass
- [ ] Playwright prosody test passes OR limitation documented

**Bad criteria (vague, subjective):**
- [ ] ~~Code quality improved~~ (how measured?)
- [ ] ~~Editor works better~~ (what does "better" mean?)
- [ ] ~~All bugs fixed~~ (which bugs? all possible bugs?)
- [ ] ~~Refactoring complete~~ (when is refactoring "complete"?)

**Criteria count:** Aim for 3-7 criteria (if >10, split scope)

---

### Step 5.5: Identify Documentation Impact

**Analyze which documentation needs updating based on scope:**

Per CLAUDE.md "Zero Documentation Drift" rule, documentation must be updated in the **same commit** as code changes.

#### Documentation Audiences

Consider both user types:
- **End Users**: People using the application (UI workflows, features, user guides)
- **Developer Users**: People using your code/API or contributing (API docs, architecture, integration guides)

**For open source projects**: Developer documentation IS user-facing documentation.

#### Fast-Track Assessment

**End User Impact:**
1. Does this scope change **visible behavior** (UI, features, workflows)? → User docs needed
2. Does this scope change **how users accomplish tasks**? → User docs needed

**Developer User Impact:**
1. Does this scope change **public API** (endpoints, functions, interfaces)? → API docs required
2. Does this scope change **integration points** (config, dependencies)? → Integration docs required
3. Does this scope introduce **architectural decisions**? → Explanation docs required

**All "no"?** → Add to iteration plan: *"Internal implementation change, no external impact"*

**Any "yes"?** → Proceed with full documentation identification below.

#### Scan for Affected Documentation

Use these search patterns to find docs that might reference changed code:

```bash
# Search for references to changed components (both user and dev docs)
grep -r "ComponentName" docs/
grep -r "FunctionName" docs/

# Search for API endpoint references (developer docs)
grep -r "/api/endpoint" docs/

# Search for feature mentions (user docs)
grep -r "Feature Name" docs/tutorials/ docs/how-to/

# Search README files (critical for developers)
grep -r "featureName" */README.md

# Search for configuration references (both audiences)
grep -r "config.optionName" docs/
```

#### Add to Iteration Plan

In the "Documentation in Scope" section (see `templates/iteration-plan.md`):

**End User Documentation:**
- List docs for application users that need updates
- Example: `docs/how-to/using-feature-x.md` (workflow changes)
- Or: *None - no user-facing behavior changes*

**Developer Documentation:**
- List docs for code users/contributors that need updates
- Example: `docs/reference/api/endpoints.md` (API changes)
- Example: `docs/explanation/architecture/data-flow.md` (architectural decision)
- Example: `README.md` (if affects installation/setup)
- Or: *None - internal implementation only*

#### Add Documentation Criteria

Include in Acceptance Criteria:
```markdown
- [ ] End user documentation updated (or N/A - explain why)
- [ ] Developer documentation updated (or N/A - explain why)
```

#### Common Documentation Types by Change

| Change Type | End User Docs | Developer Docs | Location |
|-------------|---------------|----------------|----------|
| New UI feature | ✅ Yes | ⚠️ Maybe | `docs/how-to/`, `docs/tutorials/` |
| New API endpoint | ❌ No* | ✅ Yes | `docs/reference/api/` |
| Architecture decision | ❌ No | ✅ Yes | `docs/explanation/architecture/` |
| System replacement | ⚠️ Maybe | ✅ Yes | Migration guide in `docs/how-to/` |
| Config option change | ⚠️ Maybe | ✅ Yes | `docs/reference/configuration.md` |
| Bug fix (no API change) | ❌ No | ❌ No | Changelog only |
| Internal refactor | ❌ No | ❌ No | None |
| New dependency | ❌ No | ✅ Yes | `README.md`, `docs/reference/` |
| Breaking change | ⚠️ Maybe | ✅ Yes | Migration guide + CHANGELOG |

*Unless API is directly exposed to end users (e.g., embedded SDK, user-facing scripting)

#### Reference

See `process/documentation-checklist.md` for:
- Detailed guidance on dual-audience documentation
- Search patterns for finding affected docs
- Diátaxis framework organization
- Quality metrics

See `process/doc-update-templates.md` for:
- Copy-paste templates for common doc types
- Audience-specific examples
- README and CONTRIBUTING templates

**Why this matters:**
- CLAUDE.md mandates "Zero Documentation Drift"
- Documentation that diverges from reality is worse than no documentation
- Including docs in scope ensures they're validated with the code
- Both end users AND developer users depend on accurate documentation

---

### Step 6: Document Pre-existing Issues

**Identify validation commands that will fail for unrelated reasons:**

```markdown
## Pre-existing Issues (Out of Scope)

The following validation failures existed before this scope and are explicitly out of scope:

- **89 TypeScript errors in non-lexical files**
  - Documented: 2025-10-07
  - Owner: frontend_redesign scope
  - Impact on this scope: None (lexical files clean)

- **10 test failures in Section components**
  - Documented: 2025-10-07
  - Owner: section_ui scope
  - Impact on this scope: None (lexical tests passing)

These issues will NOT block iterations in this scope.
Validation commands that fail due to these will be marked SKIP (pre-existing) without approval.
```

**Why this matters:**
- Documents debt once, removes approval friction
- Focuses validation on in-scope work
- Prevents endless "request skip approval" cycles

---

### Step 7: Create Scoped Validation Script

**Create:** `.agent_process/scripts/after_edit/validate-<scope-name>.sh`

**Template:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCOPE=${1:-unknown}
ITERATION=${2:-unknown}

printf "[%s-validation] scope=%s iteration=%s\n" "$SCOPE" "$SCOPE" "$ITERATION"

# Files in scope (only these will be validated)
FILES_TO_LINT=(
  "path/to/file1.tsx"
  "path/to/file2.ts"
)

# Test patterns for this scope only
TEST_PATTERNS=(
  "TestSuite1"
  "TestSuite2"
)

pushd frontend >/dev/null

printf "[%s-validation] Linting scope-specific sources...\n" "$SCOPE"
npx eslint "${FILES_TO_LINT[@]}" --max-warnings 0

printf "[%s-validation] Running scope-specific tests...\n" "$SCOPE"
npm test -- --testPathPattern="$(IFS=\|; echo "${TEST_PATTERNS[*]}")" \
  --watchAll=false --passWithNoTests

popd >/dev/null

printf "[%s-validation] Complete.\n" "$SCOPE"
```

**Make executable:**
```bash
chmod +x .agent_process/scripts/after_edit/validate-<scope-name>.sh
```

**Important: Maintaining the validation script:**

This script may need updates during the scope lifecycle:
- **During ITERATE decisions:** If review requires fixes in NEW files not originally scoped, orchestrator updates this script (see `02_review_iteration_instructions.md` Step 7)
- **Document changes:** Note scope expansions in iteration_plan.md "Scope Changes" section
- **Keep focused:** Only add files directly related to fixes, avoid scope creep
- **Manual/E2E commands:** If part of validation cannot be automated inside the script (e.g., Playwright suites that need a running dev server), document the exact manual commands in the iteration plan so implementation knows precisely what to run

---

### Step 8: Create iteration_plan.md

**Use template:** `.agent_process/templates/iteration-plan.md`

**Required sections (including Technical Assessment):**

```markdown
# Iteration Plan – <scope_name>

## Scope Overview
- **Scope Name:** <scope_name>
- **Date:** YYYY-MM-DD
- **Summary:** [One sentence describing scope]

## Current Status
- Latest iteration: iteration_01 (not started)

## Acceptance Criteria (LOCKED - DO NOT MODIFY)
[Criteria from Step 5]

## Technical Assessment (by Orchestrator)

**Code Review Findings:**
[Summary of current code state from Step 3]

**Relevant CLAUDE.md Patterns:**
[Key patterns and conventions from CLAUDE.md files in affected directories]

**Implementation Approach:**
[Recommended technical approach for implementation session]

**Known Risks:**
[Identified risks and mitigation strategies]

**Implementation Guidance:**
[Specific guidance on patterns to follow, pitfalls to avoid, best practices to apply - incorporate CLAUDE.md conventions]

## Iteration Model

- **Major iterations (01, 02, 03):** For criteria changes after PIVOT
- **Sub-iterations (_a, _b, _c):** For minor fixes within same criteria
- Max 3 sub-iterations per major iteration
- PIVOT can happen at any point when criteria need change
- Human approves PIVOT before new iteration created

## Criteria History

### v1 (iteration_01)
[Criteria from "Acceptance Criteria" section above - LOCKED for 01 and sub-iterations]

*(Orchestrator adds v2, v3 sections here if PIVOT creates new iterations)*

## Files in Scope
[List from Step 4]

## Validation Requirements (SCOPED)

**Hook validation (after_edit):**
- Script: `.agent_process/scripts/after_edit/validate-<scope-name>.sh`
- Lints only files in scope
- Tests only scope-specific patterns
- If the script only prints instructions for manual validation (Playwright/E2E), explicitly list the required commands in this section so implementation can run them verbatim (include dev-server startup note if needed)

**Pre-existing issues (documented, out of scope):**
[List from Step 6]

**Validation commands to SKIP (pre-existing debt):**
- `npm --prefix frontend run typecheck` → SKIP (pre-existing)
- `npm --prefix frontend run lint` → SKIP (blocked by typecheck)
- `npm --prefix frontend test` (full suite) → SKIP (use scoped test via hook)

**Validation commands to RUN:**
- Hook after_edit validation (scoped) → MUST PASS

## Out of Scope
[Explicit list of what's NOT included]

## Time Budget
- Target: 2-4 hours implementation per iteration
- Maximum: 1-3 weeks total (allows for multiple iterations if needed)
- After time exceeded: Escalate to human

## Success Metrics
- All acceptance criteria checked
- Scoped validation passes
- No regressions in scope files
```

---

### Step 8.5: Design Review Gate (Complex Scopes Only)

**Check these conditions — ALL must be true to trigger the gate:**
1. `quality-config.json` has `design_review.enabled: true`
2. The requirement's frontmatter has `complexity: complex`

**If either condition is false:** Skip to Step 9.

**If both conditions are true, run the design review:**

The design review catches design-level issues before implementation begins. 2-4 specialist reviewers independently assess the iteration plan.

#### Select Reviewers

Choose reviewers based on scope characteristics (min: `design_review.min_reviewers`, max: `design_review.max_reviewers` from quality-config.json):

| Scope Characteristic | Reviewer to Include |
|---------------------|---------------------|
| All complex scopes | Architect Reviewer (always included) |
| Touches auth, tokens, encryption, user data | Security Reviewer |
| Touches UI, UX, user-facing workflows | Product/UX Reviewer |
| Crosses 3+ system layers | Additional Architect or domain specialist |

#### Run the Review (Platform-Adaptive)

**If you have Task capability (Claude Code):**

Spawn reviewers in parallel using `templates/design-review-prompt.md`:

```
For each selected reviewer, spawn a Task agent:
Task({
  description: "[Domain] design review for {scope}",
  prompt: "You are a [Architect/Security/Product-UX] reviewer..."
  // Use the prompt template from templates/design-review-prompt.md
})
```

**If you do NOT have Task capability (Codex):**

Walk through each reviewer's lens sequentially using the rubric in `templates/design-review-prompt.md`. For each specialist domain:
1. State the domain (Architect, Security, Product/UX)
2. Assess the plan through that lens
3. Produce APPROVE or REQUEST_CHANGES with evidence

#### Process the Verdicts

- **All reviewers APPROVE** → Record in iteration_plan.md, proceed to Step 9
- **Any REQUEST_CHANGES** → Revise the plan to address feedback, re-submit to reviewers. Max `design_review.max_revision_cycles` cycles (default: 2)
- **After max revision cycles with unresolved REQUEST_CHANGES** → Escalate to human with all reviewer feedback compiled. Do NOT proceed to execution.

#### Record the Outcome

Add a `## Design Review` section to iteration_plan.md:

```markdown
## Design Review

**Gate triggered:** Yes (complexity: complex)
**Reviewers:** Architect, Security
**Revision cycles:** 0 (all approved on first pass)
**Outcome:** APPROVED

### Reviewer Verdicts
- **Architect:** APPROVE — plan is feasible, file scope covers all integration points
- **Security:** APPROVE — token handling uses httpOnly cookies, no OWASP concerns
```

Or if the gate was not triggered:

```markdown
## Design Review

N/A — scope complexity is not `complex` (or design review gate disabled in quality-config.json)
```

---

### Step 9: Create iteration_01 Placeholder

```bash
mkdir -p .agent_process/work/<scope_name>/iteration_01

# Create placeholder results.md
cat > .agent_process/work/<scope_name>/iteration_01/results.md <<EOF
# Iteration Results – <scope_name>/iteration_01

**Status:** TODO - Awaiting execution

Run: /ap_exec <scope_name> iteration_01
EOF
```

---

### Step 10: Update Current Iteration Config

```bash
cat > .agent_process/work/current_iteration.conf <<EOF
SCOPE=<scope_name>
ITERATION=iteration_01
EOF
```

---

### Step 11: Update Roadmap (if exists)

**Check if roadmap exists:**
```bash
ls .agent_process/roadmap/master_roadmap.md 2>/dev/null
```

**If roadmap exists, update it to reflect the new work scope:**

#### 11.1: Update Work Scope Count

Find the requirement row in "Requirements by Category" section and increment work scope count:

```markdown
# Before:
| 📋 | HIGH | Requirements – Save State and Navigation Bugs | 0 |

# After:
| 🚧 | HIGH | Requirements – Save State and Navigation Bugs | 1 |
```

**Note:** Status changes from 📋 (Not Started) to 🚧 (In Progress) because work has been scoped.

#### 11.2: Add to Active Work Section

Add row to "Active Work (In Progress)" table:

```markdown
| <requirement_id> | <category> | 1 |
```

#### 11.3: Update Summary Statistics

In the header and Status Summary table:
- Decrement "Not Started" count (if was 📋)
- Increment "In Progress" count
- Recalculate category completion percentage

#### 11.4: Update Timestamp

Update the "Last Updated" timestamp in the header.

**Why this matters:**
- Roadmap reflects actual project state
- Work scope count enables progress tracking
- Status change shows requirement is actively being worked
- See `.agent_process/process/roadmap_update.md` for update procedures

---

### Step 12: Summarize for Hand-off

**Provide this summary to human:**

```markdown
## Scope Ready: <scope_name>

**Objective:** [One sentence]

**Acceptance Criteria (LOCKED):** [Summary]

**Iteration Model:** Major iterations (01, 02, 03) for criteria changes; sub-iterations (_a, _b, _c) for fixes

**Files in Scope:** [Count] files

**Validation:** Scoped (only tests files in scope)

**Pre-existing Issues:** [Count] documented, won't block progress

**Time Budget:** Target 1-3 weeks (allows for multiple iterations)

**Next Step:** Human approval, then implementation session runs `/ap_exec <scope_name> iteration_01`
```

---

## Validation Checklist (Before Hand-off)

**Before handing scope to implementation session, verify:**

- [ ] Scope name is specific (not "cleanup" or "improve")
- [ ] Objective fits in one sentence
- [ ] Acceptance criteria are 3-7 specific, testable items
- [ ] Criteria marked as LOCKED (frozen within each iteration)
- [ ] Files in scope explicitly listed (4-10 files)
- [ ] Scoped validation script created and executable
- [ ] Pre-existing issues documented (won't block iterations)
- [ ] iteration_plan.md created with all sections
- [ ] iteration_01/ placeholder created
- [ ] current_iteration.conf updated
- [ ] Roadmap updated (if exists): work scope count, status, Active Work section
- [ ] Human approved scope before execution

---

## Common Planning Mistakes (Avoid These)

### ❌ Vague scope names
- "cleanup", "improve", "refactor" without specifics
- Fix: Add what you're cleaning/improving/refactoring

### ❌ Criteria that can't be checked
- "Code quality improved" (how measured?)
- Fix: "Zero eslint errors in scope files"

### ❌ Forgetting to freeze criteria
- Adding "DO NOT MODIFY" warning
- Fix: Mark as LOCKED explicitly

### ❌ Validating entire codebase
- Running full typecheck/lint/test suite
- Fix: Create scoped validation script

### ❌ Not documenting pre-existing failures
- Requesting approval every iteration
- Fix: Document once in iteration_plan.md

---

## Documentation References

- **Scope sizing:** `.local_docs/process/scope-sizing-quick-reference.md`
- **Validation patterns:** `../process/validation-playbook.md`
- **Template:** `../templates/iteration-plan.md`

---

**Next:** Hand off to implementation session for execution with `/ap_exec <scope_name> iteration_01`
