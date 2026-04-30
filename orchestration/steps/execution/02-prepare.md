# Step 02: Prepare Execution

**Input:** Preflight results
**Output:** `<project_root>/.agent_process/work/{scope}/.run/execution/02-prepare.md`

---

## Guiding Principle

For sub-iterations: the executor must understand the SEMANTIC INTENT of each fix, not just make mechanical changes. Extract and surface the WHY.

---

## 1. Load Context

Read:
- `.agent_process/work/{scope}/iteration_plan.md` — criteria, guidance, files
- `.agent_process/work/{scope}/{iteration}/results.md` — for sub-iterations, the fixes required
- `.agent_process/work/{scope}/human-prereqs.md` — optional human checkpoint (if exists)

Extract:
- **Acceptance Criteria** (LOCKED)
- **Files in Scope**
- **Removed Surfaces** (if non-empty in the plan — see step §1.1 below)
- **Validation Commands** (RUN vs SKIP)
- **Technical Guidance**
- **Human checkpoint requirements** (if `human-prereqs.md` exists)

### 1.1 Removed Surfaces (if non-empty)

If `iteration_plan.md` declares any **Removed Surfaces**, surface them in
the prepare doc verbatim and add the following instruction for the
implementer:

> Before declaring this iteration complete, run the stale-surface scrub
> block from the validator. If the scrub flags a reference outside the
> whitelist, the implementer must either (a) update that reference to
> remove or replace the removed surface, or (b) extend the per-surface
> whitelist file at
> `.agent_process/work/{scope}/.removal-whitelist/{surface}.txt` with
> the new entry AND record a justification in `results.md`. Pasting an
> entry into the whitelist without a justification is not acceptable —
> the reviewer's Gate 1 will fail it.

The implementer's `results.md` must include a **Removed-Surface Scrub**
section per `process/removal-scope-checklist.md`. The reviewer reads it
during Gate 1; missing or incomplete sections fail the gate.

If the plan declares `Removed Surfaces: N/A`, skip this sub-step.

### 1.2 Quality-Gate Artifact Check

If any file in the iteration's **Files in Scope** is a **quality-gate
artifact** — a validator script, audit hook, scrub block, gate test,
lint or type-check config, adversarial-review prompt, or similar code
whose job is to *judge* whether other code is correct — the prepare
doc MUST include a **negative-case acceptance test** for every fix
that touches one.

A quality-gate artifact has a failure mode the scoped validator cannot
catch on its own: the artifact can be silently broken in a way that
always exits 0. "The validator runs and exits 0" proves the artifact
is callable; it does not prove the artifact catches what it's meant
to catch.

**For every fix in Sub-iteration Fixes that modifies a quality-gate
artifact, write two acceptance tests:**

- **Operational:** the artifact runs and exits 0 on the current repo
  state, **under the documented invocation shell/runtime**. For shell
  validators, "the documented invocation" is the shebang the script
  uses (`#!/usr/bin/env bash` on macOS resolves to `/bin/bash` =
  3.2.57 unless the operator has Homebrew bash earlier on PATH).
  Confirm with `bash --version` in the recorded transcript. Recording
  exit 0 from a Homebrew-bash-5 invocation when the documented
  invocation is `bash <script>` does not satisfy the operational
  check — the script must run under the same shell a fresh checkout
  produces. Necessary, never sufficient.
- **Negative case:** introduce a synthetic violation the artifact is
  meant to catch and prove it gets caught (the artifact reports the
  violation and exits non-zero). Examples:
  - Stale-surface scrub → seed a fake file with a tagged stale hit
    like `stale /api/foo (#999)` and prove the scrub flags it under
    `STALE REFERENCES` and exits non-zero.
  - Type-checker config change → add a deliberately mistyped fixture
    and prove the checker fails on it.
  - Lint rule update → add a fixture that violates the new rule and
    prove lint exits non-zero.
  - Adversarial-review prompt update → seed a known-faulty result and
    prove the prompt produces a FAIL verdict.

**If you, as the prepare-step author, cannot construct a credible
negative-case test for a fix, treat that as a signal the fix spec is
incomplete.** Surface the gap under `## Spec Concerns` in the prepare
doc (see §1.4) and flag it to the coordinator before handoff —
shipping a quality-gate change with only operational acceptance tests
is the failure mode this rule prevents.

### 1.3 Scope Boundary Flexibility (mirror of iteration-plan rule)

When the prepare doc's `Files in Scope` list is narrower than the
parent `iteration_plan.md` (typical for sub-iterations focused on a
named fix), include this verbatim clause in the prepare doc just
under the Files in Scope table:

> **Boundary flexibility (mirrors the iteration-plan rule):** This
> list is the *expected* touch surface, not a *forbidden* boundary.
> If meeting the acceptance criteria correctly — including any
> negative-case tests for quality-gate artifacts (§1.2) or
> stale-surface whitelist updates for removed surfaces (§1.1) —
> requires touching files outside this list, the implementer may do
> so. Document the expansion in `results.md` under "Implementation
> Notes" with what was added and why. The narrower list keeps
> sub-iterations focused; it does not wall off soundness fixes.

**Why this is required:** in practice, sub-iteration prepare docs
that omit this clause have been read by implementers as a hard
prohibition, even when soundness required expansion. The
iteration-plan template already states the rule; the prepare doc must
not silently revoke it for sub-iterations.

### 1.4 Spec Concerns Channel

Include this verbatim clause in the prepare doc, near the implementer
summary:

> **Spec Concerns channel:** Pause and write a `## Spec Concerns`
> section at the top of `results.md` if any of these fire:
>
> - **Prepare-doc gap.** A missing acceptance test, an instruction
>   that conflicts with the iteration plan or framework rules, a
>   soundness question about a quality-gate artifact you're
>   modifying, or a fix spec that names a symptom rather than a root
>   cause.
> - **About to weaken a failing check.** You're about to remove an
>   assertion, relax a test, comment-out a guard, document a known
>   regression as "future work," or rephrase a doc/comment to dodge
>   a string match. This is the failure mode the channel exists to
>   catch. Treat the weakening as a Spec Concern, not a local fix.
> - **Test failure points at production code, not the test.** If the
>   assertion encodes the contract correctly and the production code
>   doesn't honor it, the production code is the bug — even if it
>   lives outside your file list. §1.3 (boundary flexibility) lets
>   you fix it.
>
> Then choose ONE:
>
> - **Local fix is safe and obviously correct:** apply it, document
>   it under Spec Concerns AND in Implementation Notes, including
>   what changed and why.
> - **Local fix is uncertain or expands scope significantly:** stop
>   without applying it, leave the concern in `results.md`, and
>   surface it to the coordinator so the prepare doc can be revised.
>
> **There is no third option that weakens the check to make the
> failure go away.** Modifying or removing a failing test assertion
> is a *contract change*, not a local fix — even when the edit is
> mechanically simple. A test assertion is a piece of contract
> surface area; removing it silently reduces the contract. Contract
> changes always require coordinator escalation. The path forward is
> fix-the-issue (in scope, even when §1.3 boundary flexibility is
> needed to extend to a file outside your list) or stop-and-surface
> (out of scope). Weakening the check is the anti-pattern.
>
> Concerns raised in good faith are never a failure mode; silently
> shipping work the implementer suspects is incomplete is.

The reviewer's Gate 1 reads this section explicitly and applies a
**Weakened-Assertion FAIL** rule when the implementer chooses the
weakening path. See `steps/review/02-gates.md`.

### 1.5 AC Enumeration Coverage

When the iteration's acceptance criteria use **universal quantifiers**
("every", "each", "all", "for every X") or enumerate multiple subjects
joined by "and" ("X and Y", "GET /api/foo and GET /api/foo/{id}"), the
prepare doc must expand each enumeration into a per-subject coverage
list. A single happy-path test that "covers the family" passes the
exit-0 check while leaving N−1 cells unproven; the AC's universal
quantifier requires per-cell proof.

**For every AC that quantifies universally or names multiple subjects:**

1. **List the subjects.** If the AC names "every retrofitted canonical
   metric," list the canonical metrics. If it names "GET /api/x and
   GET /api/x/{name}," list both endpoints.
2. **List the surfaces.** Often an AC quantifies over both subjects
   AND surfaces (e.g., "every metric across REST list, REST detail,
   MCP describe, MCP query"). Build the (subject × surface) matrix.
3. **Bind each cell to a test.** In the Sub-iteration Fixes / per-fix
   Acceptance Test section, the test must reference the parametrize
   fixture or test list that exercises every cell. A single test
   covering "the happy path" is not sufficient. The transcript should
   show N×M parametrized cases passing.
4. **Combine with §1.2.** If a cell exercises a quality-gate artifact,
   the cell needs both operational and negative-case tests per §1.2 —
   yielding a coverage matrix of (subject × surface × {operational,
   negative}).

**Bad acceptance test (AC quantifies, test doesn't):**
"`pytest test_metrics.py` exits 0" — passes whether or not every
canonical metric × every endpoint is covered.

**Good acceptance test (AC enumeration honored):**
"`pytest test_metrics.py::TestPhase1cCanonicalNamesAndRetirements -v`
emits N×M parametrized cases (N canonical metrics × M surfaces:
{registry presence, detail meta, query contract, MCP describe, MCP
query}) and all pass. The transcript shows the parametrize matrix."

**Why this rule exists:** AC prose with universal quantifiers is the
contract. A test that proves the property "in general" by asserting
on one example proves nothing about the other N−1 cells. The executor
and reviewer both lose visibility into which cells were proven and
which were merely assumed when a single happy-path test stands in for
a parametrized proof. Framework experience: ACs that say "and" or
"every" get compressed during AC-to-test translation into a single
operational check, leaving a coverage gap that no validator catches.

When no AC quantifies universally and no AC names multiple subjects,
this rule is silent. Additive scopes with single-subject ACs are
unaffected.

### Sub-iteration Context

For `_a`/`_b`/`_c` iterations, also extract from the placeholder results.md:
- Each fix's **mechanical change** (file:line, before/after)
- Each fix's **semantic intent** (WHY this solves the problem)
- Each fix's **acceptance test** (outcome-based verification)

Read previous iteration's results to understand what worked/didn't.

### Human Checkpoint Context

If `.agent_process/work/{scope}/human-prereqs.md` exists:
- Treat it as a required execution checkpoint, not optional context
- Extract the concrete actions the human must complete
- Surface exactly when execution must pause (e.g., before live validation, before deploy)
- Carry forward the allowed human responses (e.g., proceed, blocked, local-only)

**Format is not fixed.** Real files may use the strict template (Pause Point / Human Actions / Allowed Responses) OR a looser structure (e.g. "Required Decisions and Actions" with numbered items, "Blocking Assumptions", "Operator Actions"). Do not require the strict template — extract what's there and classify it yourself:

- **pre_execution** — decisions, confirmations, credentials, environment setup needed before any code runs. Default bucket when the file doesn't say otherwise.
- **mid_execution** — things that must be done before live validation / before touching external systems / before deploy.
- **post_execution** — cutover, user notifications, follow-up work, prod parity confirmation.

If a file only lists items without classifying them, put them in `pre_execution` — the coordinator will surface them to the human before spawning the implementer. Better to ask up front than silently skip.

The coordinator (main conversation) is what holds the actual gate — this step just extracts and classifies. Do not try to pause inside this sub-agent.

This file is created during plan-scope and may be modified during review if checkpoint needs change between iterations.

---

## 2. Decomposition Assessment

**Skip if:**
- `quality-config.json` has `work_unit_decomposition.enabled: false`
- This is a sub-iteration (execute directly against fixes)
- Files < 3 or layers < 2

**If triggered:**
- Group files by layer (backend, frontend, tests, etc.)
- Create work units with dependencies
- Each unit independently validatable

---

## 3. Agent Selection

Match file patterns to specialized agents:

| Files | Agent |
|-------|-------|
| Backend API, routes | `backend-security:backend-expert` |
| React, `.tsx` | `frontend-excellence:react-specialist` |
| Tests | `dev-accelerator:test-automator` |
| CI/CD, Docker | `infra-pipeline:cicd-engineer` |
| General/mixed | `general-purpose` |

For work units: one agent per unit.

---

## Output

```markdown
# Execution Preparation

**Scope:** {scope}
**Iteration:** {iteration}
**Type:** first_iteration / sub_iteration

## Criteria (LOCKED)
- [ ] {criterion 1}
- [ ] {criterion 2}

## Files in Scope
{list}

## Validation
- **RUN:** {commands}
- **SKIP:** {commands with reasons}

## Human Checkpoint
- **Required:** YES / NO
- **Source file:** `.agent_process/work/{scope}/human-prereqs.md` (present YES/NO)
- **Pre-execution items:** {list, or "none"}
- **Mid-execution items:** {list with trigger, or "none"}
- **Post-execution items:** {list, or "none"}
- **Allowed Responses:** {proceed / blocked / local-only / etc. — default set if file didn't specify}

**Note for coordinator:** the actual gate runs in the main conversation (Steps 0.5 and 6 of `execute.md`). This section is input for that gate, not a place to claim the gate already ran.

## Sub-iteration Fixes (if applicable)

### Fix 1: {Title}
- **Change:** {file:line, before/after}
- **Semantic Intent:** {WHY — executor must understand this}
- **Acceptance Test:** {outcome-based verification}

## Decomposition
DECOMPOSE: skip / yes
{If yes: work unit DAG}

## Agent Selection
- **Mode:** single / multi-agent
- **Agent(s):** {agent_type}
- **Reasoning:** {why this agent}
```
