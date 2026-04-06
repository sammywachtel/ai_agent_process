# Plan Scope Coordinator

You are orchestrating the scope planning workflow. Execute each step by spawning a focused sub-agent with ONLY that step's prompt file. Never embed step logic inline — the whole point is each sub-agent sees only its ~40-80 lines.

## GitHub Issues: Create or Adopt at Planning Time

**GitHub Issues:** Follow `process/github-issues-handling.md` for all issue operations.

If GH issues are enabled, the issue should exist by the time planning starts. Step 0.5 below handles creation/adoption — this ensures the issue is available for the entire pipeline, not deferred to execution.

## Prohibitions

- **Do NOT commit** during planning — artifacts are created but not committed
- **Do NOT push** to remote
- **Do NOT modify application code** — only create process artifacts in `.agent_process/`
- The user decides when to commit planning artifacts

## Inputs (Flexible)

The user can provide ANY of these input formats:
- **GitHub issue number:** `#165`, `165`, or full URL
- **Scope name:** `transcript_pipeline_poc2-01`
- **Requirement path:** `architecture-refactor/transcript_pipeline_poc2-01.md`

**Step 0.0: Resolve Input**

Run this command FIRST to resolve the input to structured scope info:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{input}}"
```

This returns JSON:
```json
{
  "scope": "transcript_pipeline_poc2-01",
  "requirement_path": ".agent_process/requirements_docs/architecture-refactor/transcript_pipeline_poc2-01.md",
  "gh_issue": "165",
  "input_type": "issue"
}
```

Use these values:
- **Requirement file:** Use `requirement_path` from the JSON
- **Scope name:** Use `scope` from the JSON
- **Run directory:** `.agent_process/work/{scope}/.run/planning/` — created in Step 02

If `requirement_path` is null, the user provided a scope/issue without a requirement doc — ask them for the requirement path.

Read the requirement file now.

## Model Tiers

Map these tiers to your platform's best available models:

| Tier | Use For | Claude Code | Codex |
|------|---------|-------------|-------|
| **cheap** | Simple file reads, yes/no checks, formatting | haiku | gpt-5.4-mini |
| **capable** | Code analysis, criterion evaluation, script generation | sonnet | gpt-5.4 |
| **synthesis** | Aggregating multiple inputs, writing plans, high-stakes decisions | opus | gpt-5.4 |

## Data Flow

All step outputs go to: `.agent_process/work/{scope}/.run/planning/`

Each phase (planning, execution, review) writes to its own subfolder within `.run/` to prevent naming collisions across phases.

Each step reads its inputs from prior steps' output files. After each step completes, verify the output file exists before proceeding. If a step fails to produce output, stop and report the failure.

---

## Local Environment Instructions

Read `.agent_process/process/local_environment_instructions.md` before starting steps. If any section is not `<none>`, pass the relevant content to sub-agents that need it. These instructions are ADDITIVE — they augment but never skip default steps.

---

## Step Sequence

### Step 01: Scope Check (HARD GATE — runs FIRST)

**This step runs before any folder creation.** The scope check only reads the requirement file.

Read `orchestration/steps/planning/01-scope-check.md`.

Spawn a **cheap** sub-agent with that prompt. Pass the requirement file path as context.

- **Output:** Write result inline or to a temp file — do NOT create `.run/planning/` yet
- **Gate logic:** If output contains `VERDICT: FAIL` → **STOP NORMAL PLANNING**. Offer the user two options:
  1. **Run automated breakdown** → Proceed to Step 01b (which creates CHILD work folders)
  2. **Add scope_override to requirement** → User manually edits, then re-run Step 01

Do NOT proceed to Step 0.5 or Step 02 until scope check passes.

### Step 01b: Scope Breakdown (CONDITIONAL — only if Step 01 FAIL)

Read `orchestration/steps/planning/01b-scope-breakdown.md`.

This step runs the full breakdown process:
1. **Architectural review** — 2-3 capable reviewers analyze the entire requirement before splitting
2. **Dependency mapping** — Identify internal dependencies and execution order
3. **Create children** — Generate `{id}-01.md`, `{id}-02.md`, etc. (preserving original name)
4. **Create breakdown file** — Rename original to `{id}-breakdown.md`
5. **GitHub Issues** — Call `lifecycle.sh split` if enabled

**Naming rule (CRITICAL):** Children use sequential suffixes, NOT descriptive names:
- CORRECT: `phase_07_user_log-01.md`, `phase_07_user_log-02.md`
- WRONG: `phase_07_user_log_entity_linking.md`, `phase_07_user_log_review_ux.md`

- **Output:** Child requirement files in `requirements_docs/` (no work folder for parent)
- **After completion:** Each child can be planned in a separate orchestrator session (load `orchestration/plan-scope.md` with the child scope). Do NOT continue to Step 02 for the original scope — it no longer exists as a plannable unit. **There is no `/plan-scope` command** — do not suggest one.

---

**If Step 01 PASSED, continue below:**

### Step 02: Derive Folder Name + Create Work Directory

Read `orchestration/steps/planning/02-derive-folder.md`.

Spawn a **cheap** sub-agent. Pass the requirement file path.

- **Output:** `.run/planning/02-folder-name.txt` (single line: the folder name)
- **Action after:** Create the work directory and `.run/planning/` directory:
  ```bash
  mkdir -p .agent_process/work/{folder_name}/.run/planning
  ```
- **Then:** Copy the scope check result to `.run/planning/01-scope-check.md`

### Step 02.5: GitHub Issues Check (conditional)

**Only runs after folder exists.** Check `quality-config.json` for `github_issues.enabled`:

**If GH enabled:**

Spawn a **cheap** sub-agent with `process/github-issues-handling.md` as input:
- **Task:** "Check GH issue for scope {scope}. If `gh_issue` exists in tracker, run `lifecycle.sh start {scope}` to adopt. If not, run `lifecycle.sh start {scope}` to create. Then run `lifecycle.sh set-status {scope} status:planning`. Return the updated `.run/gh-issue-context.md`."
- **Input:** `process/github-issues-handling.md` + `.run/gh-issue-context.md` (if exists)
- **Output:** `.agent_process/work/{scope}/.run/gh-issue-context.md`

If the sub-agent reports failure (issue creation failed, HALT), log a warning but **do not block planning**. Planning can proceed without a GH issue — execution will pick it up later.

**If GH disabled:** Skip entirely.

### Parallel Group A: Knowledge Query + Code Review

Spawn TWO sub-agents **simultaneously** (no data dependency between them):

1. **cheap** agent with `orchestration/steps/planning/025-knowledge-query.md`
   - Pass: requirement file path, scope name
   - **Output:** `.run/planning/025-knowledge.md`

2. **capable** agent with `orchestration/steps/planning/03-code-review.md`
   - Pass: requirement file path
   - **Output:** `.run/planning/03-code-review.md`
   - **Note:** If the code review surfaces questions that need human clarification, the agent writes them to the output file with a `CLARIFICATION_NEEDED: true` header. Check for this — if present, STOP and relay the questions to the user.

Wait for both to complete before proceeding.

### Step 04: Define Files in Scope

Read `orchestration/steps/planning/04-define-files.md`.

Spawn a **capable** sub-agent. Pass: requirement file path, code review output (`.run/planning/03-code-review.md`).

- **Output:** `.run/planning/04-files-in-scope.md`

### Step 05: Create Frozen Acceptance Criteria

Read `orchestration/steps/planning/05-frozen-criteria.md`.

Spawn a **capable** sub-agent. Pass: requirement file path, code review output.

- **Output:** `.run/planning/05-frozen-criteria.md`

### Parallel Group B: Doc Impact + Pre-existing Issues + Validation Script

Spawn THREE sub-agents **simultaneously**:

1. **cheap** agent with `orchestration/steps/planning/055-doc-impact.md`
   - Pass: requirement file, files-in-scope output (`.run/planning/04-files-in-scope.md`)
   - **Output:** `.run/planning/055-doc-impact.md`

2. **cheap** agent with `orchestration/steps/planning/06-preexisting-issues.md`
   - Pass: files-in-scope output
   - **Output:** `.run/planning/06-preexisting-issues.md`

3. **capable** agent with `orchestration/steps/planning/07-validation-script.md`
   - Pass: requirement file, files-in-scope output, scope name
   - **Output:** `.run/planning/07-validation-script.md` (contains the script content)

Wait for all three to complete.

### Step 08: Create Iteration Plan (AGGREGATOR)

Read `orchestration/steps/planning/08-create-plan.md`.

Spawn a **synthesis** sub-agent. This is the most important step — it reads ALL prior outputs and produces the iteration plan.

- Pass: ALL `.run/planning/*` files, requirement file path, scope name
- **Output:** `.agent_process/work/{scope}/iteration_plan.md`

### Step 08.5: Design Review (CONDITIONAL)

Read `orchestration/steps/planning/085-design-review.md`.

**Check conditions — both must be true:**
1. `.agent_process/quality-config.json` has `design_review.enabled: true`
2. The requirement's frontmatter has `complexity: complex`

**If either is false:** Skip, write "N/A — not triggered" to `.run/planning/085-design-review.md`.

**If both true:** Spawn 2-4 **capable** reviewer sub-agents in parallel (see step file for reviewer selection and rubric). Process verdicts per the step file.

### Steps 09-12: Finalize

Read `orchestration/steps/planning/09-12-finalize.md`.

Spawn a **cheap** sub-agent. Pass: scope name, iteration plan path.

- Creates: `iteration_01/results.md` placeholder, `current_iteration.conf`, roadmap updates
- **Output:** `.run/planning/09-12-finalize.md` (summary of what was created)

---

## Completion

After all steps complete, provide the handoff summary to the user:

```markdown
## Scope Ready: {scope_name}

**Objective:** [from iteration plan]
**Acceptance Criteria:** [count] locked criteria
**Files in Scope:** [count] files
**Technical Assessment:** [brief summary from code review]
**Validation:** Scoped script created
**Design Review:** [outcome or N/A]

**Artifacts Created:**
- `.agent_process/work/{scope}/iteration_plan.md`
- `.agent_process/work/{scope}/iteration_01/results.md` (placeholder)
- `.agent_process/scripts/after_edit/validate-{scope}.sh`
- `.agent_process/work/current_iteration.conf`

**Next Step:** Human approval, then `/ap_exec {scope} iteration_01`
```

⏸️ **STOP — Wait for human approval before execution.**

---

## Verification Checklist

**If scope check PASSED** — verify all `.run/planning/` output files exist:

- [ ] `.run/planning/01-scope-check.md`
- [ ] `.run/planning/02-folder-name.txt`
- [ ] `.run/planning/025-knowledge.md`
- [ ] `.run/planning/03-code-review.md`
- [ ] `.run/planning/04-files-in-scope.md`
- [ ] `.run/planning/05-frozen-criteria.md`
- [ ] `.run/planning/055-doc-impact.md`
- [ ] `.run/planning/06-preexisting-issues.md`
- [ ] `.run/planning/07-validation-script.md`
- [ ] `.run/planning/085-design-review.md`
- [ ] `.run/planning/09-12-finalize.md`

If any are missing, a step was silently skipped. Investigate before proceeding.

**If scope check FAILED and breakdown ran** — no work folder exists for the parent scope. Instead verify:

- [ ] Child requirement files created in `requirements_docs/` with `-01`, `-02` suffixes
- [ ] Parent requirement renamed to `{id}-breakdown.md`
- [ ] GitHub issues: parent closed with `status:split`, child issues created (if GH enabled)
