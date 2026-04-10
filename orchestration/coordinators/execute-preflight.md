# Execute Preflight Coordinator

You are running pre-flight checks before implementation begins. These checks catch common problems that waste iteration time. After preflight completes, the main execution prompt takes over with full Agent/Task tool access.

## GitHub Issues: Verify and Ask

**GitHub Issues:** Follow `process/github-issues-handling.md` for all issue operations.

Steps 0.4–0.5 handle GH issue verification. If no issue exists, the preflight *asks the user* rather than auto-creating — the user may have a pre-existing issue the agent can't find.

## Inputs

- **Scope:** `$1` argument (e.g., `my_feature`)
- **Iteration:** `$2` argument (e.g., `iteration_01`, `iteration_01_a`)
- **Run directory:** `.agent_process/work/{scope}/.run/execution/`

## Model Tiers

| Tier | Use For | Claude Code | Codex |
|------|---------|-------------|-------|
| **cheap** | Simple checks, file reads | haiku | gpt-5.4-mini |
| **capable** | Context loading, code analysis | sonnet | gpt-5.4 |

---

## Local Environment Instructions

Read `.agent_process/process/local_environment_instructions.md` before starting steps. If any section is not `<none>`:
- **Pre-Execution Setup:** Run those commands before Step 0.5
- **Multi-Repository Configuration:** Affects steps 007a, 007c, and 007d:
  - **007a (branch check):** After checking the root repo, also check/create the scope branch in each sub-repo that has files in scope. Map files from the iteration plan to repos using the local env repo mapping.
  - **007c (working tree):** Run `git status` inside each sub-repo that has files in scope — the root repo's `git status` cannot see changes inside sub-repos with their own `.git/`.
  - **007d (git context):** Run `git log` inside each sub-repo for that repo's scope files — the root repo's `git log` won't show history for sub-repo files.
- **Validation Extensions:** Pass to the main execution prompt for Step 4

These instructions are ADDITIVE — they augment but never skip default steps.

---

## Step Sequence

### Step 0.4: GitHub Issues Health Check (conditional, direct bash)

If `github_issues.enabled` is true in `quality-config.json`, run:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh health-check
```

If this exits non-zero, STOP and tell the user: "GitHub Issues integration is enabled but the health check failed."

### Step 0.5: GitHub Issues Verification (conditional)

If `github_issues.enabled` is true in `quality-config.json`:

**Step 0.5a: Check for linked issue**

Run this command to check if the scope already has a linked GitHub issue:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh get-issue {scope}
```

This returns the issue number (e.g., `165`) if linked, or **empty output** if not linked.

**If output is NOT empty** (issue already linked):
1. Run: `bash .agent_process/scripts/github-issues-lifecycle.sh start {scope}` (adopts, verifies, and sets status:executing)
2. Continue to Step 0.7

**If output IS empty** (no linked issue), proceed to Step 0.5b.

**Step 0.5b: Search GitHub for matching issue**

Run this command to search GitHub for an existing issue matching the scope name:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh search-issue {scope}
```

This returns a JSON array of matching issues (e.g., `[{"number":123,"title":"my_scope"}]`) or **empty/`[]`** if none found.

**If JSON array has entries** (matches found):
- Extract the first match's `number` and `title` using jq or by reading the JSON
- **ASK the user:** "Found issue #`{number}` titled '`{title}`'. Use this issue? (yes/no/skip)"
  - **yes:** Run `lifecycle.sh associate {scope} {number}`, then `lifecycle.sh set-status {scope} status:executing`
  - **no:** Fall through to "no matches" handling below
  - **skip:** Continue without GH issue, log warning

**If JSON is empty or `[]`** (no matches found):
- **ASK the user:** "No GitHub Issue found for scope '{scope}'. Enter issue number/link, say 'create', or 'skip'."
  - **number/link:** Run `lifecycle.sh associate {scope} {number}`, then `lifecycle.sh set-status {scope} status:executing`
  - **create:** Run `lifecycle.sh start {scope}` (creates issue and sets status:executing)
  - **skip:** Continue without GH issue, log warning

**Output:** Updated `.run/gh-issue-context.md`

**Reference:** See `process/github-issues-handling.md` Section 4 for the full decision tree.

---

If GH is **disabled**, run scope tracking init for local state only:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh start {scope}
```

If this exits non-zero, STOP and tell the user: "Scope tracking failed to initialize."

### Step 0.7: Pre-flight Checks

**Check `quality-config.json`:** If `pre_flight.enabled` is `false`, skip to Step 01.

**Step 0.7a: Branch Check (runs FIRST — sequential)**

Spawn a **cheap** sub-agent with `orchestration/steps/execution/007a-branch-check.md`.
- Pass: scope
- **Output:** `.run/execution/007a-branch-check.md`
- **Gate:** If output says `EXISTING_BRANCH: true`, STOP and ask user:
  "Branch `scope/{scope}` already exists. Resume work on it, or delete and start fresh?"
  Do NOT proceed until user answers.

**Steps 0.7b, 0.7c, 0.7d: Remaining Checks (3 parallel sub-agents)**

After branch check passes, spawn THREE **cheap** sub-agents **simultaneously**:

1. `orchestration/steps/execution/007b-session-recovery.md`
   - Pass: scope, iteration
   - **Output:** `.run/execution/007b-session-recovery.md`
   - **Gate:** If output says `EXISTING_RESULTS: complete`, STOP and ask user if they want to re-execute

2. `orchestration/steps/execution/007c-working-tree.md`
   - Pass: scope, iteration
   - **Output:** `.run/execution/007c-working-tree.md`
   - **Gate:** If output says `CONFLICT: true`, STOP and ask user to resolve
   - **Note:** Sub-iterations (`_a`, `_b`, `_c`) expect uncommitted changes from prior iterations — this is normal, not a conflict

3. `orchestration/steps/execution/007d-git-context.md`
   - Pass: scope
   - **Output:** `.run/execution/007d-git-context.md`

Wait for all three. Check gate conditions before proceeding.

### Step 01: Load Context (sequential)

Read `orchestration/steps/execution/01-load-context.md`.

Spawn a **capable** sub-agent. Pass: scope, iteration.

- **Output:** `.run/execution/01-context.md`
- **Gate:** If output contains `CLARIFICATION_NEEDED: true`, STOP and relay questions to user
- This step also ensures the branch and `current_iteration.conf` are correct

### Step 1.25: Assess Work Unit Decomposition (sequential)

Read `orchestration/steps/execution/0125-decomposition.md`.

Spawn a **capable** sub-agent. Pass: scope, iteration, context output (`.run/execution/01-context.md`).

- **Output:** `.run/execution/0125-decomposition.md` (contains DAG or "skip")
- Only triggers for first iterations (not sub-iterations) with 3+ files across 2+ layers

### Step 1.5: Select Agent (sequential)

Read `orchestration/steps/execution/015-select-agent.md`.

Spawn a **cheap** sub-agent. Pass: scope, context output, decomposition output.

- **Output:** `.run/execution/015-agent-selection.md`

---

## Handoff to Main Prompt

After all preflight steps complete, verify these `.run/execution/` files exist:

- [ ] `.run/execution/007a-branch-check.md` (if pre_flight enabled)
- [ ] `.run/execution/007b-session-recovery.md` (if pre_flight enabled)
- [ ] `.run/execution/007c-working-tree.md` (if pre_flight enabled)
- [ ] `.run/execution/007d-git-context.md` (if pre_flight enabled)
- [ ] `.run/execution/01-context.md`
- [ ] `.run/execution/0125-decomposition.md`
- [ ] `.run/execution/015-agent-selection.md`

Then load `orchestration/coordinators/execute-main.md` and follow it. The main prompt reads all `.run/execution/` outputs — do not repeat any preflight logic.
