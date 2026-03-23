---
description: Execute one iteration - implement changes, validate, and document results
argument-hint: [scope] [iteration]
---

## Local Environment Instructions

**BEFORE proceeding with iteration execution, check for local environment instructions:**

```bash
cat .agent_process/process/local_environment_instructions.md 2>/dev/null
```

If this file exists and contains instructions beyond the default placeholder, **follow those instructions in addition to this workflow**. Local environment instructions may specify:

- Multi-repository branch verification (polyrepo projects)
- Additional validation or setup steps
- Project-specific file scoping rules
- Environment-specific configuration
- Custom pre-implementation checks

These instructions are additive - they augment but do not replace the standard workflow below.

---

## Quality Configuration

**Load quality gate settings:**

```bash
cat .agent_process/quality-config.json 2>/dev/null
```

If this file exists, it controls which quality gates are active. Features check their section before activating. If the file doesn't exist, all features use built-in defaults (see `process/quality-configuration.md` for schema).

Key settings that affect this workflow:
- `adversarial_review.enabled` — controls Step 4.5
- `work_unit_decomposition.enabled` and thresholds — controls Step 1.25
- `knowledge_base.enabled` — controls Step 2.5
- `beads.enabled` and `beads.auto_install` — controls BEADS epic lifecycle

---

## Arguments

**`$1` (scope)** - Required. Scope folder name under `.agent_process/work/`.

**`$2` (iteration)** - Required. Iteration folder name (e.g., `iteration_01`, `iteration_01_a`, `iteration_02`, `iteration_02_a`).

---

## Your Role

You are the implementation agent executing a planned iteration. Your job: read the plan, implement the changes, validate your work, and document the results.

## Workflow Overview

1. **Load Context** - Read the iteration plan
2. **Implement** - Make the code changes
3. **Validate** - Verify your work (hook fires automatically)
4. **Document** - Create results.md (via /ap_iteration_results)
5. **Report** - Summarize completion status

---

## Step 0.5: BEADS State Tracking

**Run this command immediately — it handles all BEADS setup, config, and credentials internally:**

```bash
bash .agent_process/scripts/beads-lifecycle.sh start {scope}
```

This single command:
- Checks `quality-config.json` — exits silently if BEADS is disabled
- Loads server config and credentials (including Docker auto-detection)
- Creates the BEADS epic for this scope (or resumes an existing one)
- Exits 0 on any failure — never blocks the workflow

**You MUST run this before Step 1.** It's one command. Don't skip it.

**During execution, use the lifecycle script for state updates:**

```bash
# Work unit decomposition (Step 1.3) — create tasks:
bash .agent_process/scripts/beads-lifecycle.sh task-create {scope} WU-001 "Schema migration"

# Work unit status changes:
bash .agent_process/scripts/beads-lifecycle.sh task-update {scope} WU-001 in-progress
bash .agent_process/scripts/beads-lifecycle.sh task-update {scope} WU-001 complete

# Session recovery — check current state:
bash .agent_process/scripts/beads-lifecycle.sh status {scope}
```

**The orchestrator closes the epic** after review (not the implementation agent):
```bash
bash .agent_process/scripts/beads-lifecycle.sh close {scope} approved
```

---

## Step 1: Load Context

**Read the iteration plan:**
```bash
.agent_process/work/{scope}/iteration_plan.md
```

**Extract from the plan:**
- Acceptance Criteria (LOCKED - these are your requirements)
- Technical Assessment (implementation guidance from orchestrator)
- Files in Scope (what you're allowed to change)
- Validation Requirements (how to verify your work)
- Out of Scope (what NOT to do)

**If this is a sub-iteration (iteration_01_a/b/c), ALSO read:**

Sub-iterations focus on specific fixes from orchestrator review. Load these additional files:

1. **Current iteration placeholder** (created by orchestrator):
   ```bash
   .agent_process/work/{scope}/{iteration}/results.md
   ```
   **Extract:**
   - Required fixes (1-3 specific issues to address)
   - What the orchestrator found incomplete

2. **Previous iteration results** (what was already tried):
   ```bash
   .agent_process/work/{scope}/{parent_iteration}/results.md
   ```
   Where `{parent_iteration}` is:
   - iteration_01_a → read iteration_01/results.md
   - iteration_01_b → read iteration_01_a/results.md
   - iteration_01_c → read iteration_01_b/results.md
   - iteration_02_a → read iteration_02/results.md
   - iteration_02_b → read iteration_02_a/results.md
   - (and so on for iteration_03, etc.)

   **Extract:**
   - What was already implemented (don't break these parts)
   - What didn't work (don't repeat mistakes)

**Focus for sub-iterations:**
- Address the 1-3 specific fixes from orchestrator review
- Build on what already works
- Don't re-attempt everything from scratch

**Check for vague instructions (CRITICAL):**

If the required fixes are too vague, STOP and ask the human for clarification.

**Vague indicators (ask for clarification):**
- ❌ Line ranges >50 lines (e.g., "lines 152-399")
- ❌ No before/after examples for CSS/markup changes
- ❌ Action verbs without specifics ("scope", "refactor", "improve")
- ❌ "Remaining" or "various" without enumeration
- ❌ Missing specific selector/method/variable names

**Good indicators (proceed):**
- ✅ Small line ranges (<20 lines)
- ✅ Concrete before/after examples
- ✅ Enumerated list of specific items
- ✅ Clear acceptance test provided

**If fixes are vague, respond:**
```markdown
⚠️ Cannot proceed - Required fixes are too vague:

Fix #N is unclear:
- What: [Quote the vague instruction]
- Missing: [What information is needed]

Please provide:
1. Exact line numbers or selector names
2. Before/after example showing the change
3. Clear acceptance test (e.g., "grep should show X")

Example of what I need:
[Provide a specific example based on the vague instruction]
```

**Only proceed if fixes are specific enough to execute confidently.**

**Update requirement status to in_progress:**

Read `iteration_plan.md` and extract the "Requirements Source" path to find the requirement file. Update its frontmatter `status:` to `in_progress` and add/update the status banner:

```python
python3 << 'PYEOF'
import re, yaml
from pathlib import Path

# Read iteration_plan.md to find the requirement file
plan = Path(".agent_process/work/{scope}/iteration_plan.md").read_text()
req_match = re.search(r'Requirements Source[:\s]*[`]?([^\n`]+)[`]?', plan)

if req_match:
    req_path = Path(req_match.group(1).strip())
    if req_path.exists():
        content = req_path.read_text()
        # Parse frontmatter
        if content.startswith("---"):
            end = content.index("---", 3)
            fm = yaml.safe_load(content[3:end])
            body = content[end+3:]
            fm["status"] = "in_progress"
            new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---" + body

            # Add/update status banner (after frontmatter, before first heading)
            banner = '''
> [!NOTE]
> **🚧 IN PROGRESS** — *Active development*
>
> This requirement is currently being implemented.
> See: `.agent_process/roadmap/master_roadmap.md` for current status.
'''
            # Remove existing banner if present
            new_content = re.sub(r'\n> \[!(NOTE|TIP|WARNING|CAUTION)\]\n> \*\*[^\n]+\n(> [^\n]*\n)*', '', new_content, count=1)
            # Insert banner after frontmatter
            parts = new_content.split("---\n", 2)
            if len(parts) >= 3:
                new_content = "---\n" + parts[1] + "---\n" + banner + parts[2]

            req_path.write_text(new_content)
            print(f"✅ Updated {req_path} status to in_progress")
PYEOF
```

**Create iteration folder if needed:**
```bash
mkdir -p .agent_process/work/{scope}/{iteration}
```

**Ensure you're on the correct branch:**

The scope work must happen on a branch named `scope/{scope}`. Check current branch and create/checkout if needed:

```bash
# Check if we're on the correct branch
EXPECTED_BRANCH="scope/{scope}"
CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "⚠️  Not on branch $EXPECTED_BRANCH (currently on: $CURRENT_BRANCH)"

  # Check if the branch exists
  if git show-ref --verify --quiet "refs/heads/$EXPECTED_BRANCH"; then
    echo "✅ Branch exists, checking out $EXPECTED_BRANCH"
    git checkout "$EXPECTED_BRANCH"
  else
    echo "✅ Creating and checking out new branch $EXPECTED_BRANCH"
    git checkout -b "$EXPECTED_BRANCH"
  fi
else
  echo "✅ Already on correct branch: $EXPECTED_BRANCH"
fi
```

**Why this matters:**
- Keeps scope work isolated
- Makes it easy to identify what branch corresponds to which scope
- Enables clean PR workflow (one scope per PR)
- Prevents accidental work on wrong branch

**Ensure current_iteration.conf is correct:**

The validation hook reads `.agent_process/work/current_iteration.conf` to determine which scope's validator to run. Verify it matches this execution and update if needed:

```bash
# Check if current_iteration.conf matches what we're executing
CONFIG_FILE=".agent_process/work/current_iteration.conf"
EXPECTED_SCOPE="{scope}"
EXPECTED_ITERATION="{iteration}"

if [[ -f "$CONFIG_FILE" ]]; then
  CURRENT_SCOPE=$(grep "^SCOPE=" "$CONFIG_FILE" | cut -d'=' -f2)
  CURRENT_ITERATION=$(grep "^ITERATION=" "$CONFIG_FILE" | cut -d'=' -f2)

  if [[ "$CURRENT_SCOPE" != "$EXPECTED_SCOPE" ]] || [[ "$CURRENT_ITERATION" != "$EXPECTED_ITERATION" ]]; then
    echo "⚠️  current_iteration.conf is stale: $CURRENT_SCOPE/$CURRENT_ITERATION"
    echo "✅ Updating to: $EXPECTED_SCOPE/$EXPECTED_ITERATION"
    cat > "$CONFIG_FILE" <<EOF
SCOPE=$EXPECTED_SCOPE
ITERATION=$EXPECTED_ITERATION
EOF
  else
    echo "✅ current_iteration.conf already correct: $EXPECTED_SCOPE/$EXPECTED_ITERATION"
  fi
else
  echo "⚠️  current_iteration.conf does not exist, creating it"
  cat > "$CONFIG_FILE" <<EOF
SCOPE=$EXPECTED_SCOPE
ITERATION=$EXPECTED_ITERATION
EOF
fi
```

**Why this matters:**
- The `hook_after_edit.sh` script reads this file to run the correct scope validator
- Without this check, running `/ap_exec` for a different scope would use the old scope's validator
- This ensures validation feedback always matches the scope being executed

---

## Step 1.25: Assess Work Unit Decomposition

**Check `quality-config.json`:** If `work_unit_decomposition.enabled` is `false`, skip this step entirely and proceed to Step 1.5.

**Determine if this scope benefits from structured decomposition:**

Work unit decomposition breaks a multi-domain scope into a DAG of independently-executable units. Each unit has its own files, agent, and validation. This adds coordination overhead, so it's only triggered when the overhead pays for itself.

**Trigger conditions (ALL must be true):**
1. Scope touches **N+ implementation files** where N = `work_unit_decomposition.trigger_threshold_files` from `quality-config.json` (default: 3). Count only source code, configs, and tests; exclude process artifacts like `results.md`, `test-output.txt`, `iteration_plan.md`, and anything under `.agent_process/work/`
2. Files span **M+ system layers** where M = `work_unit_decomposition.trigger_threshold_layers` from `quality-config.json` (default: 2)
3. This is a **first iteration** (not a sub-iteration — _a/_b/_c always execute directly against the specific fixes)

**If trigger conditions are NOT met:** Skip to Step 1.5 and execute normally (single-pass, as before).

**If trigger conditions ARE met:** Proceed to Step 1.3 for decomposition.

**Layer detection heuristic:**

| Pattern | Layer |
|---------|-------|
| `migrations/`, `.sql`, schema files | Database |
| Backend API files, routes, services | Backend |
| Frontend components, hooks, `.tsx` | Frontend |
| Test files (`__tests__/`, `.test.`, `.spec.`) | Tests |
| Config, Docker, CI/CD | Infrastructure |
| Documentation (`docs/`, `*.md`) | Docs |

Count distinct layers from the files in scope. If ≥2, decomposition is warranted.

---

## Step 1.3: Decompose into Work Units (optional)

**Only execute this step if Step 1.25 triggered decomposition.**

Analyze the acceptance criteria and files in scope to create a Directed Acyclic Graph (DAG) of work units.

**Work unit format:**

```markdown
## Work Unit Decomposition

### WU-001: [Description]
- **Files:** `path/to/file1.ts`, `path/to/file2.ts`
- **Layer:** Backend
- **Dependencies:** None
- **Criteria addressed:** AC1, AC2
- **Agent:** backend-security:backend-expert

### WU-002: [Description]
- **Files:** `path/to/component.tsx`, `path/to/hook.ts`
- **Layer:** Frontend
- **Dependencies:** None (parallel with WU-001)
- **Criteria addressed:** AC3
- **Agent:** frontend-excellence:react-specialist

### WU-003: [Description]
- **Files:** `path/to/test.test.ts`
- **Layer:** Tests
- **Dependencies:** WU-001, WU-002 (must complete first)
- **Criteria addressed:** AC4, AC5
- **Agent:** dev-accelerator:test-automator

### Execution Order
WU-001 ──┐
          ├──→ WU-003
WU-002 ──┘
```

**Decomposition rules:**
1. **Stay within frozen criteria** — work units are a tactical breakdown, not new scope. If you identify missing criteria, note them for the backlog, don't add them as work units
2. **Soft cap: 3-6 work units** — more than 6 suggests the scope should have been split at the requirements level
3. **Each unit must be independently validatable** — you should be able to run the scoped validation hook against the unit's files alone
4. **Validate the DAG** — no cycles, no missing dependencies, every criterion addressed by at least one unit
5. **Write the decomposition** into results.md's `## Work Unit Summary` section as you execute (not upfront in the plan)

**Update session recovery tracking:**

```bash
# Create or update work unit tracking
cat > .agent_process/work/{scope}/current_work_unit.conf <<EOF
SCOPE={scope}
ITERATION={iteration}
CURRENT_UNIT=WU-001
TOTAL_UNITS=3
COMPLETED_UNITS=
EOF
```

**Per-unit execution loop:**

For each work unit in DAG order (respecting dependencies):

1. **Check dependencies** — all prerequisite WUs must be in COMPLETED_UNITS
2. **Select agent** — use the agent specified in the work unit (from Step 1.5 logic)
3. **Execute** — launch Task agent scoped to this unit's files only
4. **Validate** — run scoped validation against this unit's files
5. **Update tracking:**
   ```bash
   # Mark unit complete in tracking file
   sed -i '' "s/CURRENT_UNIT=.*/CURRENT_UNIT=WU-002/" .agent_process/work/{scope}/current_work_unit.conf
   sed -i '' "s/COMPLETED_UNITS=.*/COMPLETED_UNITS=WU-001/" .agent_process/work/{scope}/current_work_unit.conf
   ```
6. **Proceed to next unit** or finish if all complete

**Independent units execute in parallel** — launch their Task agents in a single response (same pattern as the multi-domain parallel agents in Step 2).

**If session is interrupted mid-execution:**
- Read `current_work_unit.conf` to find the last completed unit
- Resume from the next unit in the DAG
- Already-completed units are not re-executed

**Reference:** See `process/work-unit-execution.md` for the full how-to guide and `templates/work-unit-decomposition.md` for the Architect Agent prompt.

---

## Step 1.5: Select Specialized Agent

**Determine the appropriate agent for this scope:**

The agent process has access to specialized agents optimized for different types of work. Before implementing, analyze the scope to select the most appropriate agent.

**Agent Selection Framework:**

1. **Check for explicit agent hint** in iteration_plan.md or requirements.md:
   - Look for `agent_hint: {agent_name}` field
   - If present and valid, use that agent (skip auto-detection)

2. **Auto-detect based on file patterns** (if no explicit hint):

   Examine the "Files in Scope" or "Files to Create/Modify" section and match patterns:

   **Database/Backend Infrastructure:**
   - `.sql`, `migrations/`, database schema → `backend-security:backend-architect`
   - Backend API files, FastAPI routes → `backend-security:backend-architect`

   **Frontend React/TypeScript:**
   - React components, hooks, `.tsx`/`.ts` → `frontend-excellence:react-specialist`
   - Lexical editor files, plugins → `frontend-excellence:react-specialist`
   - CSS, styling, design system → `frontend-excellence:css-expert`
   - State management, Redux → `frontend-excellence:state-manager`

   **Testing:**
   - Test files, Jest, Playwright → `dev-accelerator:test-automator`
   - E2E test specs → `dev-accelerator:test-automator`

   **DevOps/Infrastructure:**
   - Docker, CI/CD, deployment → `infra-pipeline:infra-architect`
   - GitHub Actions, pipelines → `infra-pipeline:cicd-engineer`

   **Security/Auth:**
   - Authentication, authorization → `backend-security:auth-specialist`
   - Security audits, OWASP → `backend-security:security-guardian`

   **Code Review/Quality:**
   - Refactoring, cleanup → `dev-accelerator:code-reviewer`
   - Bug fixes → `dev-accelerator:debugger`

3. **Fallback to general-purpose:**
   - If no clear pattern match → use `general-purpose` Task agent
   - For multi-domain scopes → consider spawning multiple specialized agents in parallel (see Step 2)

**Decision Tree (if uncertain):**

```
Is it frontend code (.tsx, .ts, React)? → frontend-excellence:react-specialist
Is it backend code (.py, FastAPI)? → backend-security:backend-expert
Is it tests? → dev-accelerator:test-automator
Is it infrastructure (Docker, CI/CD)? → infra-pipeline:infra-architect
Multiple domains? → SPAWN MULTIPLE AGENTS IN PARALLEL (see Step 2)
Still unsure? → general-purpose
```

**Selection Output:**

Once you've determined the agent(s), note it for Step 2:
```
Selected Agent(s):
- {agent_name} - for {file pattern or domain}
[- {agent_name_2} - for {file pattern or domain}]  # If multi-domain
Reasoning: {brief explanation of why this/these agent(s) were chosen}
```

**Example Selections:**

| Files in Scope | Selected Agent(s) | Reasoning |
|----------------|-------------------|-----------|
| `migrations/*.sql` | `dev-accelerator:backend-architect` | Database schema work |
| `frontend/src/hooks/*.ts` | `frontend-excellence:react-specialist` | React hooks |
| `frontend/src/components/lexical/*.tsx` | `frontend-excellence:react-specialist` | Lexical plugin |
| `tests/e2e/*.spec.ts` | `dev-accelerator:test-automator` | E2E tests |
| `frontend/*.tsx` + `backend/*.py` | `frontend-excellence:react-specialist` + `backend-security:backend-expert` | **Parallel: 2 agents** |
| `frontend/*.tsx` + `tests/e2e/*.ts` | `frontend-excellence:react-specialist` + `dev-accelerator:test-automator` | **Parallel: 2 agents** |
| `frontend/*.tsx` + `backend/*.py` + `tests/*.ts` | 3 specialized agents in parallel | **Parallel: 3 agents** |

---

## Step 2: Implement Changes

**Work within the defined scope:**
- Implement ONLY what the acceptance criteria require
- Follow the Technical Assessment guidance
- Modify ONLY files listed in "Files in Scope"
- Do NOT expand scope beyond locked criteria
- If you discover a change is impossible without touching an out-of-scope file, STOP and ask the orchestrator to update the scope before editing anything else

**Add/update tests:**
- Write tests for new functionality
- Update existing tests for modified behavior
- Ensure tests are comprehensive and meaningful

**Use Task tool with selected agent:**

Launch the specialized agent determined in Step 1.5. If using a specialized agent (not general-purpose), enhance the prompt with domain-specific context.

**Task Invocation Template:**

Use the agent selected in Step 1.5 with the Task tool. Replace `{selected_agent}` with your choice (e.g., `frontend-excellence:react-specialist` or `general-purpose`).

**For first iteration (iteration_01):**

```typescript
// Example Task call:
Task({
  subagent_type: "{selected_agent}",  // From Step 1.5
  description: "Implement {scope} iteration_01",
  prompt: `Execute iteration work for {scope}/{iteration}:

1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
2. Review acceptance criteria (LOCKED - these are your requirements)
3. Follow the Technical Assessment implementation guidance
4. Implement all required code changes
5. Add or update automated tests for changes
6. Update documentation per CLAUDE.md requirements:
   - Check "Documentation in Scope" section in iteration_plan.md
   - Update end user docs if user-facing behavior changed
   - Update developer docs if API/architecture/config changed
   - Search docs/ for references to changed code (grep patterns in process/documentation-checklist.md)
   - Use templates in process/doc-update-templates.md if helpful
   - If no docs needed, note why in completion report
7. Perform manual spot checks to confirm behavior

IMPORTANT CONTEXT:
- Scope: {scope}
- Iteration: {iteration}
- Files in scope: [list from iteration_plan.md]
- Validation will run automatically via hook after you complete

Work directly on the code - do NOT launch additional subagents.
Report completion status when done, including:
- What was implemented
- What tests were added/updated
- What documentation was updated (or why none needed)
- Any issues encountered
`
})
```

**For sub-iterations (iteration_NN_a/b/c):**

```typescript
// Example Task call:
Task({
  subagent_type: "{selected_agent}",  // From Step 1.5
  description: "Fix issues for {scope} {iteration}",
  prompt: `Execute iteration work for {scope}/{iteration}:

1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
2. Read {iteration}/results.md for the 1-3 specific fixes required
3. Read {parent_iteration}/results.md to see what was already tried
4. Focus ONLY on addressing the specific fixes from orchestrator review
5. Build on what already works - don't break working parts
6. Add or update tests for the fixes
7. Update documentation if fixes changed external behavior (API/UI/config)
   - Check "Documentation in Scope" section in iteration_plan.md
   - Update docs that reference changed code
   - If no docs needed, note why in completion report
8. Perform manual spot checks to confirm fixes work

IMPORTANT CONTEXT:
- Scope: {scope}
- Iteration: {iteration} (sub-iteration fixing specific issues)
- Previous iteration: {parent_iteration}
- This is attempt {X} of maximum 3 sub-iterations
- Validation will run automatically via hook after you complete

Work directly on the code - do NOT launch additional subagents.
Report completion status when done, including:
- Which specific fixes were addressed
- What was changed to fix them
- What documentation was updated (or why none needed)
- Any remaining issues
`
})
```

**Multiple Agents (multi-domain scope):**

When the scope spans multiple domains, spawn all agents in a SINGLE response with multiple Task calls. This runs them in parallel for efficiency.

```typescript
// Example: Frontend + Backend + Tests scope
// Send ALL THREE Task calls in ONE response:

Task({
  subagent_type: "frontend-excellence:react-specialist",
  description: "Implement frontend for {scope}",
  prompt: `Execute FRONTEND changes for {scope}/{iteration}:

1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
2. Focus ONLY on frontend files: [list frontend files from scope]
3. Implement React component changes per acceptance criteria
4. Add/update Jest tests for frontend changes

Files you are responsible for:
- frontend/src/components/...
- frontend/src/hooks/...

Do NOT touch backend or E2E test files - other agents handle those.
Report what you implemented when done.
`
})

Task({
  subagent_type: "backend-security:backend-expert",
  description: "Implement backend for {scope}",
  prompt: `Execute BACKEND changes for {scope}/{iteration}:

1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
2. Focus ONLY on backend files: [list backend files from scope]
3. Implement API/service changes per acceptance criteria
4. Add/update pytest tests for backend changes

Files you are responsible for:
- backend/app/api/...
- backend/app/services/...

Do NOT touch frontend or E2E test files - other agents handle those.
Report what you implemented when done.
`
})

Task({
  subagent_type: "dev-accelerator:test-automator",
  description: "Implement E2E tests for {scope}",
  prompt: `Execute E2E TEST changes for {scope}/{iteration}:

1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
2. Focus ONLY on E2E test files: [list test files from scope]
3. Write/update Playwright E2E tests per acceptance criteria
4. Ensure tests cover the integration between frontend and backend

Files you are responsible for:
- tests/e2e/...

Do NOT touch frontend or backend implementation files - other agents handle those.
Report what tests you added/updated when done.
`
})
```

⚠️ **Important for parallel agents:**
- Send ALL Task calls in ONE response (not sequential responses)
- Each agent gets a clearly scoped subset of files
- Agents should NOT overlap in file responsibility
- Wait for ALL agents to complete before proceeding to Step 3

**Agent-Specific Context Enhancements:**

When using specialized agents, add relevant context to the prompt:

- **backend-security:backend-architect**: Include database schema requirements, RLS policies, migration patterns
- **frontend-excellence:react-specialist**: Include React patterns, Lexical framework rules, performance requirements
- **dev-accelerator:test-automator**: Include test coverage requirements, testing patterns to follow
- **frontend-excellence:css-expert**: Include design tokens, CSS patterns, accessibility requirements

**Why use Task tool:**
- The SubagentStop hook fires automatically when Task completes
- Hook runs the scoped validation script (`.agent_process/scripts/after_edit/validate-{scope}.sh`)
- Provides immediate feedback on lint/test issues
- Specialized agents bring domain expertise to implementation

---

## Step 3: Validate Your Work

**After Task completes, the hook has already run.**

**Where to find hook output:**
The SubagentStop hook runs automatically and its output appears in your terminal/chat immediately after the Task agent completes. Look for lines starting with:
```
[hook_after_edit] Running scoped validation for {scope}/{iteration}
[hook_after_edit] Running validate-{scope}.sh
```

**Check hook results:**
- **PASS**: Hook exits with code 0, you'll see `[hook_after_edit] Complete`
- **FAIL**: Hook exits non-zero, you'll see error output from ESLint or Jest

**If hook FAILED (exit non-zero):**
1. Scroll up in terminal to see the validation errors
2. Look for ESLint errors or test failures in the hook output
3. Fix the issues (lint errors, test failures)
4. Re-run the Task (maximum 3 attempts)
5. Each retry will re-trigger the hook
6. If still failing after 3 attempts, STOP and report blockers

**If hook PASSED (exit 0):**
- Proceed to Step 4 to capture the output

**Do NOT proceed until hook validation passes.**

---

## Step 4: Run Full Validation Commands

**Create test-output.txt with header:**
```bash
cat > .agent_process/work/{scope}/{iteration}/test-output.txt <<EOF
# Validation Results - {scope}/{iteration}

## Summary
- Scoped validation (hook): PENDING
- Manual verification: PENDING

## Detailed Logs

EOF
```

**Capture scoped validation results (no copy/paste required):**

If you still have the hook output visible, you can re-run the scoped validator and tee the logs directly into `test-output.txt`:

```bash
bash .agent_process/scripts/after_edit/validate-{scope}.sh {scope} {iteration} | tee -a .agent_process/work/{scope}/{iteration}/test-output.txt
```

Then append a marker so reviewers know what the section contains:

```bash
cat >> .agent_process/work/{scope}/{iteration}/test-output.txt <<'EOF'

=== Scoped Validation ($(date -Iseconds)) ===
# Output above was captured via tee
EOF
```

Finally, update the summary line using a portable script:

```bash
python - <<'PY'
from pathlib import Path
path = Path(".agent_process/work/{scope}/{iteration}/test-output.txt")
text = path.read_text()
text = text.replace("Scoped validation (hook): PENDING", "Scoped validation (hook): PASS (hook)", 1)
path.write_text(text)
PY
```

> If you cannot re-run the validator (e.g., expensive Playwright suite), capture the original hook output manually and paste it into the detailed logs instead.

**Run manual verification (if needed):**

If the iteration_plan.md specifies manual QA:
- Perform the manual tests
- Document findings in test-output.txt
- Update summary line

**Optional: Run broader validation commands**

The iteration_plan.md may list additional validation:
- Full test suite (if different from scoped tests)
- E2E tests for specific scenarios
- Visual checks

Run these if specified, append output to test-output.txt.

**E2E Test Execution (IMPORTANT):**

E2E tests run automatically via the validation script using Playwright's `webServer` feature. The servers (frontend + backend) are auto-started by Playwright - you do NOT need to start them manually.

Standard E2E command in validation scripts:
```bash
npx playwright test tests/e2e/features/your-spec.ts --config=playwright.e2e.config.ts
```

This command:
1. Starts backend on port 8001 (if not already running)
2. Starts frontend on port 5175 (if not already running)
3. Runs the E2E tests
4. Reports results

If you see server startup timeout errors, troubleshoot per the "E2E tests and server startup" section in Troubleshooting below.

**Note:** Some older validators may skip Playwright or only print instructions. Always check the validation script content. Modern validators should include the full Playwright command with `--config=playwright.e2e.config.ts`.

---

## Step 4.5: Adversarial Review (Fresh Agent)

**Check `quality-config.json`:** If `adversarial_review.enabled` is `false`, skip this step entirely and proceed to Step 5.

**Spawn a fresh reviewer to independently verify each criterion before handing off to the orchestrator.**

This runs here — on the implementation side — because `ap_exec` always runs in Claude Code, which always has the Task tool. The orchestrator may run in Codex (which can't spawn agents), so putting the primary adversarial review here guarantees it always happens.

#### When to Run

- **Run**: Any scope with 2+ acceptance criteria and code changes
- **Skip if `adversarial_review.skip_for_trivial` is `true` (default)**: Scopes with `trivial_threshold_files` or fewer changed files AND `trivial_threshold_criteria` or fewer criteria (e.g., "rename X to Y"), documentation-only scopes

If skipping, note the reason and proceed to Step 5.

#### How to Run

1. **Get the list of changed files:**
   ```bash
   git diff --name-only HEAD~1..HEAD
   # Or if multiple commits:
   git diff --name-only <base_branch>..HEAD
   ```

2. **Read the frozen criteria** from `iteration_plan.md`

3. **Spawn a fresh Task agent** — this agent has zero context about the implementation:

   ```typescript
   Task({
     subagent_type: "general-purpose",
     description: "Adversarial review for {scope}",
     prompt: `You are a fresh adversarial reviewer. Review these code changes against the
   frozen acceptance criteria below. You have NO context about the implementation
   process.

   ACCEPTANCE CRITERIA (from iteration_plan.md):
   - [ ] [Criterion 1 — paste exact text]
   - [ ] [Criterion 2 — paste exact text]
   - [ ] [Criterion 3 — paste exact text]

   CHANGED FILES (from git diff --name-only):
   - [file1]
   - [file2]

   Read each changed file. For each criterion, produce a PASS or FAIL verdict
   with file:line evidence. Follow the verdict format in
   templates/adversarial-review-prompt.md.
   Do NOT assess code quality — only spec compliance.`
   })
   ```

4. **Important constraints:**
   - Do NOT include `results.md` in the prompt — the reviewer assesses code, not claims
   - Do NOT reuse a reviewer from a previous sub-iteration — always spawn fresh
   - The reviewer is a Task agent, not a team member — it runs and returns a verdict

5. **Save the verdict** to a file the orchestrator can reference:
   ```bash
   cat > .agent_process/work/{scope}/{iteration}/adversarial-review.md <<EOF
   [Paste the reviewer's full verdict output here]
   EOF
   ```

#### Why This Location

The adversarial review was originally in Step 3.7 of the orchestrator's review instructions. But the orchestrator often runs in Codex, which has no Task tool — meaning the review was silently skipped. Moving the primary review here ensures it always fires. The orchestrator still reads the verdict and factors it into the 4-choice decision; it just doesn't have to spawn the reviewer itself.

---

## Step 5: Document Results

**Call /ap_iteration_results to create results.md:**
```
/ap_iteration_results {scope} {iteration}
```

This command will:
- Read test-output.txt
- Generate results.md with structured summary
- List changed files
- Document validation status
- Note any known issues

**Do NOT create results.md manually** - let /ap_iteration_results do it.

---

## Step 5.5: Update Requirement Status Based on Results

**After results.md is created, promote requirement status if ready for review:**

Read the results.md that `/ap_iteration_results` just created. If it shows "Ready for Review: YES", update the requirement frontmatter to `completed` (implementation done, awaiting orchestrator review). If "Ready for Review: NO", leave as `in_progress`.

```python
python3 << 'PYEOF'
import re, yaml
from pathlib import Path

# Read results.md to check readiness
results_path = Path(".agent_process/work/{scope}/{iteration}/results.md")
if not results_path.exists():
    print("⚠️  No results.md found — skipping status update")
    exit(0)

results = results_path.read_text()
ready = bool(re.search(r'Ready for Review[:\s]*YES', results, re.IGNORECASE))

if not ready:
    print("ℹ️  Not ready for review — leaving status as in_progress")
    exit(0)

# Find requirement file from iteration_plan.md
plan = Path(".agent_process/work/{scope}/iteration_plan.md").read_text()
req_match = re.search(r'Requirements Source[:\s]*[`]?([^\n`]+)[`]?', plan)

if req_match:
    req_path = Path(req_match.group(1).strip())
    if req_path.exists():
        content = req_path.read_text()
        if content.startswith("---"):
            end = content.index("---", 3)
            fm = yaml.safe_load(content[3:end])
            body = content[end+3:]
            fm["status"] = "completed"
            new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---" + body

            # Add/update status banner
            banner = '''
> [!NOTE]
> **🔍 COMPLETED** — *Implementation done, awaiting review*
>
> All acceptance criteria addressed. Ready for orchestrator review.
> See: `.agent_process/work/{scope}/{iteration}/results.md` for details.
'''
            # Remove existing banner
            new_content = re.sub(r'\n> \[!(NOTE|TIP|WARNING|CAUTION)\]\n> \*\*[^\n]+\n(> [^\n]*\n)*', '', new_content, count=1)
            # Insert banner after frontmatter
            parts = new_content.split("---\n", 2)
            if len(parts) >= 3:
                new_content = "---\n" + parts[1] + "---\n" + banner + parts[2]

            req_path.write_text(new_content)
            print(f"✅ Updated {req_path} status to completed (ready for review)")
PYEOF
```

---

## Step 6: Report Completion

**Provide summary to user:**

```markdown
## Iteration Complete: {scope}/{iteration}

**Acceptance Criteria Status:**
- [ ] Criterion 1: [Met/Not Met - brief note]
- [ ] Criterion 2: [Met/Not Met - brief note]
- [ ] Criterion 3: [Met/Not Met - brief note]

**Documentation Updated:**
- End User Docs: [List updated docs, or "None - no user-facing changes"]
- Developer Docs: [List updated docs, or "None - internal implementation only"]
- Or: [Explanation of why no docs needed]

**Validation Status:**
- Scoped validation (hook): [PASS/FAIL]
- Manual verification: [PASS/FAIL/SKIPPED]

**Files Changed:** {count} files

**Known Issues:**
[List any issues discovered or criteria not met]

**Artifacts Created:**
- `.agent_process/work/{scope}/{iteration}/results.md`
- `.agent_process/work/{scope}/{iteration}/test-output.txt`

**Ready for Review:** [YES/NO - explain if NO]
```

**If validation failed or criteria not met:**
- Clearly state what's incomplete
- List specific blockers
- Do NOT claim iteration is ready for review

**If everything passed:**
- State that iteration is ready for orchestrator review
- Summarize what was accomplished

---

## Important Rules

**Scope boundaries:**
- Implement ONLY the locked acceptance criteria
- Do NOT expand scope based on "nice to have" findings
- New issues → backlog, not this iteration

**Validation enforcement:**
- Hook must PASS before proceeding to full validation
- Maximum 3 retry attempts on hook failures
- Stop and report if unable to pass validation

**No scope creep:**
- Acceptance criteria are FROZEN
- Cannot add new requirements mid-iteration
- Follow Technical Assessment guidance exactly

**Iteration model (two-level):**
- **Major iterations** (01, 02, 03): Created via PIVOT when criteria need to change
- **Sub-iterations** (_a, _b, _c): Created via ITERATE for minor fixes within same criteria
- Maximum 3 sub-iterations per major iteration before PIVOT or BLOCK
- Example progression: iteration_01 → _a → _b → PIVOT → iteration_02 → _a → ...

---

## Troubleshooting

**Hook keeps failing:**
- Review validation script at `.agent_process/scripts/after_edit/validate-{scope}.sh`
- Check that you're only modifying files in scope
- Verify tests are properly written and passing
- Ensure required tooling is installed (e.g., run `npx playwright install --with-deps firefox` if browser installs are missing)
- After 3 attempts, stop and report blocker

**E2E tests and server startup:**

⚠️ **IMPORTANT**: E2E tests DO NOT require manually starting servers!

The project's Playwright configuration includes a `webServer` section that automatically starts both frontend and backend servers before running tests. Specifically:

- `playwright.e2e.config.ts` starts:
  - Frontend: `npm run dev` on port 5175
  - Backend: `uvicorn app.main:app` on port 8001

- Key config options:
  - `reuseExistingServer: true` - Won't start new servers if they're already running
  - `timeout: 120000` - Allows 2 minutes for servers to start

**Correct behavior:**
```bash
# This command handles everything - server startup, test execution, teardown
npx playwright test tests/e2e/features/your-spec.ts --config=playwright.e2e.config.ts
```

**Do NOT:**
- Report that E2E tests couldn't run because "servers weren't running"
- Skip E2E tests claiming they "require a running dev server"
- Manually start servers before running validation scripts

**If E2E tests fail to start servers:**
1. Check if ports 5175/8001 are in use by stale processes: `lsof -i :5175 -i :8001`
2. Kill stale processes if needed: `pkill -f vite && pkill -f uvicorn`
3. Verify backend dependencies: `cd backend && pip install -r requirements.txt`
4. Verify Playwright browsers: `npx playwright install --with-deps`

**Can't meet acceptance criteria:**
- **Try to unblock yourself first.** You have bash access. If a tool is missing, install it. If authentication is needed, check for existing credentials (environment variables, mounted config dirs, docker secrets). If a service is down, verify it's actually down vs. a config issue. Only report BLOCKED after you've genuinely attempted to resolve the issue.
- Document specifically what's blocking progress AND what you tried
- Note in results.md "Known Issues" section
- Use status `🚫 BLOCKED` if an external factor prevents progress after you've tried to resolve it
- Use status `⚠️ NEEDS REVISION` if criteria aren't met but there's no external blocker
- Do NOT invent statuses like "INCOMPLETE" or "PARTIAL" — pick from the three valid options
- Orchestrator will decide: ITERATE/BLOCK/PIVOT

**Discovered new issues:**
- Document in results.md "Known Issues" section
- Do NOT add to acceptance criteria
- These become backlog items for future scopes

---

## Success Checklist

Before reporting completion, verify:

- [ ] All acceptance criteria addressed (met or documented why not)
- [ ] Tests written/updated for changes
- [ ] Scoped validation (hook) PASSED
- [ ] test-output.txt contains validation results
- [ ] results.md created via /ap_iteration_results
- [ ] Only files in scope were modified
- [ ] No scope creep beyond locked criteria
- [ ] Clear statement of ready/not-ready for review

---

**Remember:** This is implementation only. Orchestrator review comes next.
