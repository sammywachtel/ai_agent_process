# Step 07: Create Scoped Validation Script

**Model tier:** capable
**Tools needed:** Read, Write, Bash
**Input:** Requirement file, files-in-scope output (`.run/planning/04-files-in-scope.md`), scope name
**Output:** `.run/planning/07-validation-script.md` (contains the script content and path)

---

## Your Task

Create a validation script that tests ONLY the files in this scope. This prevents false failures from unrelated code and keeps iterations focused.

## Script Location

`.agent_process/scripts/after_edit/validate-{scope-name}.sh`

## Script Template

Adapt this template based on the project's tech stack (detected from files in scope):

```bash
#!/usr/bin/env bash
set -euo pipefail

SCOPE=${1:-unknown}
ITERATION=${2:-unknown}

printf "[%s-validation] scope=%s iteration=%s\n" "$SCOPE" "$SCOPE" "$ITERATION"

# Files in scope (only these will be validated)
FILES_TO_LINT=(
  "path/to/file1.ts"
  "path/to/file2.ts"
)

# Test patterns for this scope
TEST_PATTERNS=(
  "TestSuite1"
  "TestSuite2"
)

# Linting (adapt to project: eslint, ruff, etc.)
printf "[%s-validation] Linting scope-specific sources...\n" "$SCOPE"
# npx eslint "${FILES_TO_LINT[@]}" --max-warnings 0
# ruff check "${FILES_TO_LINT[@]}"

# Tests (adapt to project: jest, pytest, etc.)
printf "[%s-validation] Running scope-specific tests...\n" "$SCOPE"
# npm test -- --testPathPattern="$(IFS=\|; echo "${TEST_PATTERNS[*]}")" --watchAll=false
# pytest "${TEST_PATTERNS[@]}"

printf "[%s-validation] Complete.\n" "$SCOPE"
```

## Important Notes

- Populate `FILES_TO_LINT` from the files-in-scope output
- Populate `TEST_PATTERNS` from test files in scope
- If validation requires a running dev server (Playwright/E2E), document the manual commands instead of putting them in the script
- Make the script executable: `chmod +x`

## Output Format

Write to `.run/planning/07-validation-script.md`:

```markdown
# Validation Script

**Path:** `.agent_process/scripts/after_edit/validate-{scope}.sh`
**Created:** YES
**Executable:** YES

## Script Contents
{Include the full script content here for the aggregator to reference}

## Manual Validation (if any)
{Commands that must be run manually, e.g., E2E tests needing a dev server}
```

Also write the actual script file to disk and make it executable.
