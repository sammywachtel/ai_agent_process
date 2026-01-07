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

---

## Planning Steps

### Step 1: Clarify the Brief

**Ask human these questions:**

1. **Objective:** What specific outcome should this scope achieve? (one sentence)
2. **Success criteria:** How will we know when it's done? (measurable test/demo)
3. **Boundaries:** What's explicitly out of scope?
4. **Priority:** What's the relative importance (high/medium/low)?
5. **Risk:** Any known blockers or dependencies?

**Red flags that scope is too large:**
- Objective needs multiple paragraphs
- Success criteria includes "and" 3+ times
- Touches 10+ files
- Has dependencies on other in-progress work
- Uses vague verbs: "cleanup", "improve", "refactor" without specifics

---

### Step 2: Derive Work Folder Name

**Derive the work folder name from the requirements path using this convention:**

#### Pattern
```
<area>_<path_numbers>_<task>
```

#### Derivation Rules

1. **Area**: First segment of requirements path
   - Normalize: replace `-` with `_`, lowercase
   - Example: `ai_radar-based_feedback_system` → `ai_radar`
   - Example: `word_tools` → `word_tools`

2. **Path Numbers**: Extract all `##_` prefixed numbers from path segments, join with `_`
   - `00_foundation/01_database_prefs` → `00_01`
   - `epic_07/01_rewrites` → `07_01`
   - `scopes/01_collection` → `01`

3. **Task**: Final segment with leading `##_` stripped
   - `01_database_preferences` → `database_preferences`
   - `stress_toggle` → `stress_toggle`

#### Examples

| Requirements Path | Work Folder Name |
|-------------------|------------------|
| `word_tools/scopes/01_collection_model` | `word_tools_01_collection_model` |
| `ai_radar.../00_foundation/01_db_prefs` | `ai_radar_00_01_db_prefs` |
| `ai_radar.../01_ambient/07_stress_toggle` | `ai_radar_01_07_stress_toggle` |
| `code_quality/epic_07/01_rewrites` | `code_quality_07_01_rewrites` |
| `song_settings/03_boxes_system` | `song_settings_03_boxes_system` |

#### Ad-hoc Work (No Requirements Doc)

For bug fixes or quick work without a requirements doc:
```
hotfix_<area>_<brief_description>
```
Example: `hotfix_lexical_cursor_jump`

#### Good vs Bad Names

**Good (specific, traceable):**
- `word_tools_01_collection_model` (traces to requirements)
- `ai_radar_01_07_stress_toggle` (includes hierarchy)
- `hotfix_lexical_cursor_jump` (clear ad-hoc pattern)

**Bad (vague, untraceable):**
- `lexical_cleanup` (what does "cleanup" mean?)
- `improve_editor` (no boundary)
- `fix_bugs` (which bugs?)
- `ai_radar_based_feedback_system_scope_01_...` (redundant `scope_`)

#### Naming Validation

Before creating work folder, verify:
- [ ] Name traces back to requirements path unambiguously
- [ ] Numbers preserve order from requirements hierarchy
- [ ] No redundant words (`scope_` prefix not needed)

**Create directory:**
```bash
mkdir -p .agent_process/work/<scope_name>
```

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

## Iteration Budget (ENFORCED)
- iteration_01: First attempt
- iteration_01_a: First revision (if needed)
- iteration_01_b: Second revision (if needed)
- iteration_01_c: Final attempt (if needed)

After iteration_01_c → Escalate to human (ship/pivot/abort)

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
- Maximum: 1-2 weeks total
- After time exceeded: Escalate to human

## Success Metrics
- All acceptance criteria checked
- Scoped validation passes
- No regressions in scope files
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

### Step 11: Summarize for Hand-off

**Provide this summary to human:**

```markdown
## Scope Ready: <scope_name>

**Objective:** [One sentence]

**Acceptance Criteria (LOCKED):** [Summary]

**Iteration Budget:** Max 3 sub-iterations before escalation

**Files in Scope:** [Count] files

**Validation:** Scoped (only tests files in scope)

**Pre-existing Issues:** [Count] documented, won't block progress

**Time Budget:** Target 1-2 weeks

**Next Step:** Human approval, then implementation session runs `/ap_exec <scope_name> iteration_01`
```

---

## Validation Checklist (Before Hand-off)

**Before handing scope to implementation session, verify:**

- [ ] Scope name is specific (not "cleanup" or "improve")
- [ ] Objective fits in one sentence
- [ ] Acceptance criteria are 3-7 specific, testable items
- [ ] Criteria marked as LOCKED (cannot change)
- [ ] Files in scope explicitly listed (4-10 files)
- [ ] Scoped validation script created and executable
- [ ] Pre-existing issues documented (won't block iterations)
- [ ] iteration_plan.md created with all sections
- [ ] iteration_01/ placeholder created
- [ ] current_iteration.conf updated
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
