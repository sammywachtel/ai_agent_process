# Validation Playbook

**Philosophy:** Validate your work, not the entire codebase.

---

## Scoped Validation Strategy

### Problem with Full Validation
```bash
# Running these blocks progress:
npm --prefix frontend run typecheck  # 89 pre-existing errors
npm --prefix frontend run lint        # Blocked by typecheck
npm --prefix frontend test            # 10 failures in other components
```

### Solution: Scoped Validation
```bash
# Only validate files in scope:
npx eslint "path/to/scope-file.tsx" --max-warnings 0
npm test -- --testPathPattern="ScopeTests" --watchAll=false
```

**Key principle:** Test what you touched + direct dependencies

---

## Hook-Driven Validation

### After Edit Hook Pattern

**Location:** `.agent_process/scripts/after_edit/validate-<scope-name>.sh`

**Template:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCOPE=${1:-unknown}
ITERATION=${2:-unknown}

printf "[%s-validation] scope=%s iteration=%s\n" "$SCOPE" "$SCOPE" "$ITERATION"

# Only lint files in scope
FILES_TO_LINT=(
  "path/to/file1.tsx"
  "path/to/file2.ts"
)

# Only run tests for this scope
TEST_PATTERNS=(
  "TestSuite1"
  "TestSuite2"
)

pushd frontend >/dev/null

printf "[%s-validation] Linting scope sources...\n" "$SCOPE"
npx eslint "${FILES_TO_LINT[@]}" --max-warnings 0

printf "[%s-validation] Running scope tests...\n" "$SCOPE"
npm test -- --testPathPattern="$(IFS=\|; echo "${TEST_PATTERNS[*]}")" \
  --watchAll=false --passWithNoTests

popd >/dev/null

printf "[%s-validation] Complete.\n" "$SCOPE"
```

### When to Create Custom Validators vs Ad-Hoc Validation

**Custom validators (`validate-<scope>.sh`) are optional.** The hook gracefully
handles missing validators with a "No validator found" message.

**Use custom validators when:**
- Complex artifact validation required (PPTX slide content, CSV column checks)
- Multi-step pipeline validation (run pipeline → check outputs → verify state)
- Scope involves multiple repositories or deployment targets
- Validation logic is non-trivial and benefits from codification

**Use ad-hoc validation when:**
- Standard linting/testing covers the scope (ruff, pytest, eslint)
- Acceptance criteria are simple file existence or basic content checks
- Scope is exploratory or one-time

**Ad-hoc validation pattern in results.md:**
```markdown
## Validation

**Scoped validation:** PASS
- Ruff lint: All checks passed
- Pytest: 42 tests passed in 2.1s
- Manual verification: [describe what was checked]
```

### Validator Maintenance

Over time, validation scripts accumulate as scopes are created and completed.
When work directories are archived or deleted, orphan validators remain.

**Health check:**
```bash
.agent_process/scripts/analyze-validation-scripts.sh
```

Reports:
- Scripts with matching work directories (healthy)
- Orphan scripts (no matching work directory) 
- Work directories without validators (normal for simple scopes)

**Cleanup orphans:**
```bash
# Preview what would be removed
.agent_process/scripts/cleanup-validation-scripts.sh --dry-run

# Actually remove orphan scripts
.agent_process/scripts/cleanup-validation-scripts.sh
```

Run these periodically (e.g., after archiving completed scopes) to keep the
scripts directory tidy.

### Removal Scopes — Workspace-Wide Stale-Surface Scrub

The scoped-validator pattern above intentionally bounds what gets linted
and tested to files in scope. For scopes that **remove or rename a public
surface** (HTTP route, MCP tool, CLI command, env var, exported symbol),
the validator gains a second responsibility: prove that no live caller of
the removed surface remains anywhere in the workspace.

This is a different validator shape — a workspace-wide grep filtered
against an explicit per-surface whitelist — and it lives next to the
scoped commands inside the same `validate-{scope}.sh` script. The full
contract (planner / executor / reviewer responsibilities, whitelist
rules, anti-patterns) is in `process/removal-scope-checklist.md`. Read
that file before planning any scope that removes a public surface.

---

## Pre-existing Debt Handling

### Document Once in iteration_plan.md

```markdown
## Pre-existing Issues (Out of Scope)

- **89 TypeScript errors in non-lexical files** (documented 2025-10-07)
  - Owner: frontend_redesign scope
  - Impact: None (lexical files clean)

- **10 test failures in Section components** (documented 2025-10-07)
  - Owner: section_ui scope
  - Impact: None (lexical tests passing)

These will NOT block iterations. Commands that fail due to these
will be marked SKIP (pre-existing) without approval.
```

### Mark as SKIP in test-output.txt

```
Summary of Validation Commands
- hook validate-lexical: PASS
- frontend typecheck: SKIP (pre-existing, see iteration_plan.md)
- frontend lint: SKIP (pre-existing, see iteration_plan.md)
- frontend unit tests (full): SKIP (using scoped test via hook)
```

---

## Status Vocabulary

### PASS
- Command executed and returned exit code 0
- Example: `- hook validate-lexical: PASS`

### FAIL
- Command executed and returned non-zero exit code
- Example: `- hook validate-lexical: FAIL (2 ESLint errors)`
- **Action:** Fix issues or escalate

### SKIP (pre-existing)
- Command intentionally not executed due to documented pre-existing failures
- Example: `- frontend typecheck: SKIP (pre-existing, see iteration_plan.md)`
- **No approval needed per iteration** (documented once in plan)

### SKIP (approved)
- Command intentionally not executed with human approval
- Example: `- backend pytest: SKIP (Sam 2025-10-10, environment repair)`
- **One-time approval** (reference approver + date)

---

## Validation Commands by Scope

### Backend
```bash
cd backend && black --check .
cd backend && flake8
pytest
```

### Frontend (Scoped)
```bash
# NOT full typecheck/lint (unless scope is small)
npx eslint "src/components/specific/**/*.tsx" --max-warnings 0
npm test -- --testPathPattern="SpecificTests" --watchAll=false
```

### E2E (Targeted)
```bash
# NOT full playwright suite (unless scope requires)
npx playwright test tests/e2e/features/specific-feature.spec.ts
```

---

## Contract Validation for Shared APIs

Run this whenever a change alters an API or payload that another client (web, mobile, CLI, partner service) consumes.

1. **Map consumers:** List every downstream client in `iteration_plan.md` and point to their contracts (TypeScript types, Swift/Kotlin models, protobuf/OpenAPI files, etc.).
2. **Capture the contract before coding:** Record the expected request/response structure, required fields, wrappers, enums, and error shapes in the plan so changes are intentional.
3. **Guard the backend:** Add or update tests/schemas that assert the documented shape (JSON schema test, serializer snapshot, contract test hitting the endpoint).
4. **Exercise each consumer:** Run the client’s validation command (`npm run type-check`, `gradlew test`, `bundle exec rspec`, etc.). If automation is missing, execute the UI manually and collect logs/console output.
5. **Collect proof:** Paste a prettified sample response plus the command results into `results.md` and surface PASS/SKIP/FAIL in `test-output.txt`. Missing evidence means the iteration is not ready to approve.

---

## Documentation Validation

Run this whenever code changes affect external behavior (API, UI, configuration, workflows, architecture) for end users OR developer users.

Per CLAUDE.md "Zero Documentation Drift" rule, documentation must be updated in the **same commit** as code changes.

### When Documentation Updates Are Required

Documentation updates are required when:
- **End User Impact**: API endpoints, UI features, workflows, configuration options, user-facing behavior
- **Developer User Impact**: Public APIs, integration points, architecture decisions, dependencies, contribution workflows
- **System Changes**: Migrations, deprecations, breaking changes, new patterns

**For open source projects**: Developer documentation IS user-facing documentation (API docs, integration guides, architecture explanations).

### Documentation Validation Checklist

Before marking iteration complete, verify documentation was handled:

```markdown
## Documentation Check (from results.md)

Code changes made:
- [ ] List files modified and nature of changes

Documentation impact analysis (dual-audience):
- [ ] End user changes → `docs/how-to/`, `docs/tutorials/` updated?
- [ ] API changes → `docs/reference/api/` updated?
- [ ] Workflow changes → `docs/how-to/` updated?
- [ ] Architecture changes → `docs/explanation/architecture/` updated?
- [ ] Config changes → `docs/reference/configuration.md` updated?
- [ ] System replacement → Migration guide created in `docs/how-to/`?
- [ ] New dependency → `README.md` and `docs/reference/` updated?
- [ ] Breaking change → Migration guide + CHANGELOG updated?
- [ ] Cross-references → Searched docs for broken links/references?

Documentation updated:
- [ ] List docs modified (or explain why none needed)

Verification:
- [ ] Examples tested and work with current code
- [ ] Followed Diátaxis organization (tutorial/how-to/reference/explanation)
- [ ] Both end user AND developer audiences addressed (if applicable)
```

### Grep Patterns for Finding Affected Documentation

Search for documentation that might reference changed code:

```bash
# Find docs mentioning a changed file/function/class
grep -r "FunctionName" docs/
grep -r "ComponentName" docs/

# Find docs mentioning API endpoints
grep -r "api/endpoint" docs/
grep -r "/v1/resource" docs/

# Find docs mentioning removed features
grep -r "oldFeatureName" docs/

# Find docs mentioning configuration options
grep -r "config.optionName" docs/
grep -r "ENVIRONMENT_VAR" docs/

# Find README files that might need updates
grep -r "featureName" */README.md

# Find integration guides
grep -r "import.*ModuleName" docs/
```

### Fast-Track Assessment

**Skip documentation validation if ALL true:**
- Internal refactor with no API/UI changes
- Bug fix with no behavior change visible to users or developers
- Test-only changes
- results.md explicitly notes "Internal implementation, no external impact"

**Otherwise, perform full documentation validation.**

### Documentation Validation Steps

1. **Review "Documentation Changes" section in results.md:**
   - Check both end user and developer documentation
   - Verify explanations for why docs weren't needed (if applicable)
   - Look for documentation debt notes

2. **Verify documentation accuracy:**
   ```bash
   # If API changed, verify API docs were updated
   grep -r "EndpointName" docs/reference/api/

   # If component renamed, verify no stale references
   grep -r "OldComponentName" docs/

   # If config changed, verify config docs updated
   grep -r "oldConfigKey" docs/
   ```

3. **Check documentation quality:**
   - [ ] Examples are current (not outdated code)
   - [ ] Cross-references are valid (no broken links)
   - [ ] Organized per Diátaxis (tutorial/how-to/reference/explanation)
   - [ ] Clear audience (end user vs developer user)
   - [ ] Migration path clear (if breaking change)

4. **Document findings in review:**
   ```markdown
   ## Documentation Validation

   **End User Documentation:**
   - ✅ Updated: [list docs]
   - Or: ❌ Gap: [what's missing]
   - Or: ✅ N/A - no user-facing changes

   **Developer Documentation:**
   - ✅ Updated: [list docs]
   - Or: ❌ Gap: [what's missing]
   - Or: ✅ N/A - internal implementation only

   **Cross-reference check:**
   - ✅ No stale references found
   - Or: ⚠️ Found stale references: [list and fix]

   **Quality check:**
   - ✅ Examples tested and work
   - ✅ Follows Diátaxis organization
   - ✅ Both audiences addressed appropriately
   ```

### Blocking Conditions

**BLOCK iteration approval if:**
- Code changes external behavior (UI, API, config) AND no docs updated AND no explanation
- System migration completed but no migration guide
- Breaking change with no migration path documented
- New dependency but README not updated
- Public API changed but no API docs updated
- results.md claims "no docs needed" but code review shows user-facing changes

**Allow iteration if:**
- Docs appropriately updated for both audiences
- Clear justification why no docs needed (with evidence)
- Internal-only changes with no external impact
- Documentation debt explicitly tracked with follow-up issue

### Reference Materials

- **Checklist**: `process/documentation-checklist.md` - Dual-audience framework, search patterns
- **Templates**: `process/doc-update-templates.md` - Copy-paste templates for common doc types
- **Planning Guide**: `orchestration/coordinators/plan-scope.md (coordinator) + orchestration/steps/planning/ (step files)` Step 5.5 - Documentation impact analysis
- **Review Guide**: `orchestration/coordinators/review-iteration.md + steps/review/` Step 3.5 - Documentation gate

### Integration with results.md

The "Documentation Changes" section in `results.md` should document:
- End user documentation updates (or why none needed)
- Developer documentation updates (or why none needed)
- Cross-reference verification results
- Documentation debt (if any, with tracking issue)

This provides the evidence needed for the review phase documentation gate.

---

## test-output.txt Format

### Summary Section (Top)
```
Summary of Validation Commands
- hook validate-<scope>: PASS/FAIL/SKIP
- backend black: PASS/FAIL/SKIP
- backend flake8: PASS/FAIL/SKIP
- backend pytest: PASS/FAIL/SKIP
- scope-specific tests: PASS/FAIL

Detailed Logs (timestamped sections below)
```

### Detailed Logs (After Summary)
```
==== hook validation (2025-10-13T12:00:00Z) ====
[validation output...]

==== backend black (2025-10-13T12:05:00Z) ====
[black output...]

==== scope-specific tests (2025-10-13T12:10:00Z) ====
[test output...]
```

### Evidence completeness (REQUIRED — what the review gate verifies)

`test-output.txt` is the **canonical evidence artifact**. The review gate
(`orchestration/steps/review/01-verify.md`) checks every claim against it, **not**
against prose in `results.md`. Therefore:

- **Every validation command claimed in `results.md` MUST appear in `test-output.txt`**
  with its command line, exit status, and the decisive output (`59 passed`,
  `All checks passed`, `exit=0`).
- **`results.md` may claim NOTHING the transcript does not show.** Didn't actually run
  a check → don't list it (or run it and capture it).
- A scoped-validator log **alone is not sufficient** when `results.md` also claims
  pytest / ruff / pre-commit / etc. — each is a separate command and needs its own
  `==== <name> ====` block. (This is the single most common cause of an evidence-only
  ITERATE: the code is correct but the transcript doesn't substantiate the claims.)

**Self-check before requesting review (this is exactly what the gate runs):** every
command named in the `results.md` "Validation" section has a matching `==== <name> ====`
block with an exit status in `test-output.txt`. Mismatch → fix it now, or the iteration
bounces on evidence alone with no code change to make.

### Capture by construction — don't hand-assemble test-output.txt

Tee every command into the transcript **as you run it**, so what you claim can't drift
from what you recorded:

```bash
OUT="$WORKDIR/iteration_XX/test-output.txt"; : > "$OUT"   # truncate at iteration start

run() {  # run a validation command AND record it (name, command, output, exit)
  printf '\n==== %s ====\n$ %s\n' "$1" "$2" | tee -a "$OUT"
  bash -c "$2" 2>&1 | tee -a "$OUT"
  printf 'exit=%s\n' "${PIPESTATUS[0]}" | tee -a "$OUT"
}

run "scoped-validator" ".agent_process/scripts/after_edit/validate-<scope>.sh <scope> <iter>"
run "pytest:bumper"    "cd nap-gcp-platform && python -m pytest tests/scripts/test_bump_prod_pins_from_release_outputs.py -q"
run "ruff"             "cd nap-gcp-platform && ruff check src/ailab_mcp"
run "pre-commit"       "pre-commit run --files <changed files>"
```

**Best — make it complete by construction:** put the full claimed check surface
(pytest + ruff + pre-commit + the scope checks) **inside** `validate-<scope>.sh`, so
`test-output.txt` is generated complete in one run and `results.md` can only claim what
the script emitted. This removes the executor-discipline dependency entirely — the
recurring multi-check bounce — and is the preferred shape for any scope with more than
the scoped validator to run.

#### Three rules that close the *second* evidence-bounce class (capture-then-mutate)

Folding the surface into the validator kills the *missing-transcript* bounce. It does
NOT kill the *stale-transcript* bounce, which is what gets you once the validator is the
source of truth. These three rules close it. (-01-01 iteration_01 bounced on exactly
this: a complete, correct `76 passed` validator run sat in the file next to a stale
`75 passed` standalone section and a "re-confirmed by the coordinator" sentence backed
by no command.)

1. **One source, no duplicate sections.** Once the validator runs the full surface,
   *that run is the transcript.* Do **not** also hand-paste standalone `SCOPED PYTEST` /
   `SCOPED RUFF` sections. A second copy of the same evidence is just a copy that rots
   the instant you touch the code again — and the reviewer can't tell your "old" copy
   from a real disagreement.
2. **The final validator run is the LAST thing you do.** Change *any* code after a
   capture — even adding one test — and every earlier capture is now a lie by omission.
   Re-run `validate-<scope>.sh` as the final action *before* writing `results.md`, and
   cite that single run. If you re-ran it, delete the now-stale earlier run; don't leave
   both in the file "for history."
3. **No reconfirmation prose.** `results.md` quotes its number from exactly **one**
   transcript block. Never write "independently re-confirmed", "also verified by", or any
   phrasing that asserts a run with no matching `==== <name> ====` block. To the gate, a
   claimed run with no captured command didn't happen — and it's a blocker even when the
   code is perfect.

---

## Common Patterns

### Pattern 1: Scope-Specific Lint
```bash
# Only lint changed files
npx eslint \
  "src/components/lexical/nodes/StressedTextNode.tsx" \
  "src/components/lexical/commands/StressCommands.ts" \
  --max-warnings 0
```

### Pattern 2: Scope-Specific Tests
```bash
# Only test related test suites
npm test -- \
  --testPathPattern="(StressCommands|StressCoordinator)" \
  --watchAll=false --passWithNoTests
```

### Pattern 3: Targeted E2E
```bash
# Only run tests for this feature
npx playwright test \
  tests/e2e/features/prosody-regression.spec.ts \
  --grep "cursor interaction"
```

---

## Documentation References

- **Scope planning:** `../orchestration/coordinators/plan-scope.md (coordinator) + orchestration/steps/planning/ (step files)` (orchestration phase)
- **Iteration review:** `../orchestration/coordinators/review-iteration.md + steps/review/` (orchestration phase)
- **Iteration execution:** `../claude/commands/ap_exec.md` (implementation phase)
- **Base context:** `../orchestration/context/base-context.md`

---

**Remember:** Scoped validation prevents false blockers from unrelated code.
