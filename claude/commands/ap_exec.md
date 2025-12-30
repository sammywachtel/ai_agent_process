---
name: /ap_exec
description: Execute one iteration - implement changes, validate, and document results
argument-hint: [scope] [iteration]
arguments:
  - name: scope
    type: string
    description: Scope folder under `.agent_process/work/`.
    required: true
  - name: iteration
    type: string
    description: Iteration folder name (e.g., `iteration_01`, `iteration_01_a`).
    required: true
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

**For sub-iterations (iteration_01_a/b/c):**

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

**Iteration budget:**
- This is attempt {iteration} (e.g., iteration_01, iteration_01_a)
- Maximum 3 sub-iterations (a/b/c) before escalation
- If you're on iteration_01_c, this is the final attempt

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
- Document specifically what's blocking progress
- Note in results.md "Known Issues" section
- Mark iteration as NOT ready for review
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
