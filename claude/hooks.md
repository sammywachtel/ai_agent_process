# Installing Claude Code Hooks

## Overview

The `.agent_process` uses a simplified hook system:
- **after_edit hook**: Provides scoped validation feedback after implementation
- **No enforcement hooks**: Codex review is the quality gate

---

## Installation

### Step 1: Ensure Hooks Directory Exists

```bash
mkdir -p .claude
```

### Step 2: Create/Update hooks.json

Create or edit `.claude/hooks.json`:

```json
{
  "SubagentStop": {
    "command": "bash .agent_process/scripts/hook_after_edit.sh \"${SCOPE:-}\" \"${ITERATION:-}\""
  }
}
```

**Note:** The SubagentStop hook runs automatically when Task agents complete.

### Step 3: Make Hook Executable

```bash
chmod +x .agent_process/scripts/hook_after_edit.sh
```

---

## How It Works

### after_edit Hook (Scoped Validation)

**Trigger:** Automatically runs after Task agent completes (SubagentStop)

**Purpose:** Provides immediate feedback on scoped validation

**Behavior:**
1. Looks for validation scripts in `.agent_process/scripts/after_edit/`
2. Runs each `validate-*.sh` script found
3. Reports results (PASS/FAIL)
4. **No blocking** - just feedback, Claude can proceed

**Example:**
```bash
# Hook finds and runs:
.agent_process/scripts/after_edit/validate-lexical-node-lifecycle.sh

# Provides output:
[hook_after_edit] Running validate-lexical-node-lifecycle.sh
[lexical-node-lifecycle-validation] Linting scope sources...
✓ All files pass lint
[lexical-node-lifecycle-validation] Running scope tests...
✓ 12/12 tests passing
[hook_after_edit] Complete
```

---

## Creating Scope-Specific Validation Scripts

### Template

Copy from template:
```bash
cp .agent_process/scripts/after_edit/validate-scope.sh.template \
   .agent_process/scripts/after_edit/validate-<scope-name>.sh
```

### Customize

Edit `validate-<scope-name>.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCOPE=${1:-unknown}
ITERATION=${2:-unknown}

printf "[%s-validation] scope=%s iteration=%s\n" "$SCOPE" "$SCOPE" "$ITERATION"

# List files in this scope
FILES_TO_LINT=(
  "path/to/file1.tsx"
  "path/to/file2.ts"
)

# List test patterns for this scope
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

### Make Executable

```bash
chmod +x .agent_process/scripts/after_edit/validate-<scope-name>.sh
```

---

## Philosophy

### Fast Feedback, Not Enforcement

**Old approach (removed):**
- ❌ Stop hook blocked completion if artifacts missing
- ❌ Required `expected_artifacts.json` rigid enforcement
- ❌ Checked artifact alignment, file existence
- ❌ Created compliance work instead of quality work

**New approach (simplified):**
- ✅ after_edit provides immediate scoped validation feedback
- ✅ No blocking - just helpful feedback
- ✅ Codex review is the real quality gate
- ✅ Focus on implementation, not process compliance

### Why This Works

**Convergence mechanisms prevent the real problems:**
- Iteration budget (max 3 sub-iterations) → Prevents infinite loops
- Frozen criteria → Prevents scope creep
- Scoped validation → Prevents false blockers
- 4-choice decisions → Forces explicit choices

**Hooks provide value without overhead:**
- Fast feedback on files you changed
- Runs automatically (no manual steps)
- Exit code reflects validation (but doesn't block)
- Helps Claude fix issues quickly

**Codex review catches quality issues:**
- Reviews against original acceptance criteria
- Catches incomplete work
- Makes go/no-go decisions
- Better than automated checking

---

## Troubleshooting

### Hook Doesn't Run

**Check:**
1. Is `.claude/hooks.json` configured correctly?
2. Is `hook_after_edit.sh` executable? (`chmod +x`)
3. Are SCOPE and ITERATION environment variables set?

**Debug:**
```bash
# Test manually
SCOPE=test ITERATION=iteration_01 \
  bash .agent_process/scripts/hook_after_edit.sh test iteration_01
```

### Validation Script Not Found

**Check:**
1. Does script exist in `.agent_process/scripts/after_edit/`?
2. Does script name match pattern `validate-*.sh`?
3. Is script executable?

**Debug:**
```bash
ls -la .agent_process/scripts/after_edit/
```

### Validation Fails

**This is expected behavior!** Hook provides feedback, not enforcement.

**What Claude should do:**
1. Read failure output
2. Fix issues
3. Re-run (hook runs automatically on next attempt)
4. Document in results.md if persistent failures

**What Claude should NOT do:**
- ❌ Try to work around validation failures
- ❌ Skip validation requirements
- ✅ Fix the actual issues

---

## Summary

**Single hook:** `after_edit` (scoped validation feedback)
**Purpose:** Fast feedback, not enforcement
**Installation:** Simple hooks.json + executable script
**Philosophy:** Help Claude fix issues quickly, Codex review for quality

---

**See also:**
- `../process/validation-playbook.md` - Scoped validation patterns
- `../codex/02_review_iteration_instructions.md` - Codex review as quality gate
