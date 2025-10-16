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

- **Scope planning:** `../orchestration/01_plan_scope_instructions.md` (orchestration phase)
- **Iteration review:** `../orchestration/02_review_iteration_instructions.md` (orchestration phase)
- **Iteration execution:** `../claude/commands/ap_exec.md` (implementation phase)
- **Base context:** `../orchestration/00_base_context.md`

---

**Remember:** Scoped validation prevents false blockers from unrelated code.
