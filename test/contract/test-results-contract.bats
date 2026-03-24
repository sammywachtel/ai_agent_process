#!/usr/bin/env bats
# test-results-contract.bats — Tests for results.md contract validator
#
# Tests both the validator itself (using fixture artifacts) and
# can be pointed at real artifacts from target projects.

VALIDATOR="test/contract/validate-results.sh"
GOOD_DIR="test/fixtures/sample-artifacts/good"
BAD_DIR="test/fixtures/sample-artifacts/bad"

setup() {
  # Create fixture artifacts if they don't exist yet
  mkdir -p "$GOOD_DIR" "$BAD_DIR"
}

# --- Good artifacts ---

@test "valid results.md with current format passes" {
  cat > "$GOOD_DIR/results-current.md" << 'EOF'
# Iteration Results – test-scope/iteration_01

**Date:** 2026-03-24
**Status:** ✅ COMPLETE

---

## Summary

Did the thing. It worked.

## Changed Files

- `src/app.ts` — Added feature X

## Validation

All scoped tests pass.

## Acceptance Criteria Status

- [x] Feature X implemented
- [x] Tests pass

## Adversarial Review

See adversarial-review.md.
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/results-current.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VERDICT: PASS"* ]]
}

@test "results.md with NEEDS REVISION status passes" {
  cat > "$GOOD_DIR/results-revision.md" << 'EOF'
# Iteration Results – test-scope/iteration_01

**Date:** 2026-03-24
**Status:** ⚠️ NEEDS REVISION

---

## Summary

Partial progress.

## Changed Files

- `src/app.ts` — Partial implementation

## Validation

2 of 3 tests pass.

## Acceptance Criteria Status

- [x] Feature X implemented
- [ ] Tests pass
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/results-revision.md"
  [ "$status" -eq 0 ]
}

@test "results.md with BLOCKED status passes" {
  cat > "$GOOD_DIR/results-blocked.md" << 'EOF'
# Iteration Results – test-scope/iteration_01

**Date:** 2026-03-24
**Status:** 🚫 BLOCKED

---

## Summary

Can't proceed — API key required.

## Changed Files

No files changed.

## Validation

N/A — blocked before implementation.

## Acceptance Criteria Status

- [ ] Feature X implemented
- [ ] Tests pass
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/results-blocked.md"
  [ "$status" -eq 0 ]
}

# --- Legacy format (acceptable in normal mode, fail in strict) ---

@test "legacy format passes in normal mode" {
  cat > "$GOOD_DIR/results-legacy.md" << 'EOF'
# Iteration Results – old-scope/iteration_01

**Date:** 2026-02-15
**Status:** COMPLETE - Ready for Review

---

## Summary

Old-style results.

## Changes Made

- `src/old.ts` — Did stuff

## Validation

Tests pass.

## Acceptance Criteria Status

- [x] Thing done
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/results-legacy.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}

@test "legacy format fails in strict mode" {
  run bash "$VALIDATOR" "$GOOD_DIR/results-legacy.md" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"legacy format"* ]]
}

# --- Bad artifacts ---

@test "INCOMPLETE status is rejected" {
  cat > "$BAD_DIR/results-incomplete.md" << 'EOF'
# Iteration Results – bad-scope/iteration_01

**Date:** 2026-03-24
**Status:** INCOMPLETE

---

## Summary

Half done.

## Changed Files

- `src/app.ts`

## Validation

Some tests pass.

## Acceptance Criteria Status

- [x] One thing
EOF

  run bash "$VALIDATOR" "$BAD_DIR/results-incomplete.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid status"* ]]
}

@test "IN PROGRESS status is rejected" {
  cat > "$BAD_DIR/results-inprogress.md" << 'EOF'
# Iteration Results – bad-scope/iteration_01

**Date:** 2026-03-24
**Status:** IN PROGRESS

---

## Summary
Still working.

## Changed Files
- `src/app.ts`

## Validation
N/A

## Acceptance Criteria Status
- [ ] Not done
EOF

  run bash "$VALIDATOR" "$BAD_DIR/results-inprogress.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid status"* ]]
}

@test "missing Status field is rejected" {
  cat > "$BAD_DIR/results-no-status.md" << 'EOF'
# Iteration Results – bad-scope/iteration_01

**Date:** 2026-03-24

---

## Summary
Did stuff.

## Changed Files
- `src/app.ts`

## Validation
Pass.

## Acceptance Criteria Status
- [x] Done
EOF

  run bash "$VALIDATOR" "$BAD_DIR/results-no-status.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No **Status:** field"* ]]
}

@test "missing Summary section is rejected" {
  cat > "$BAD_DIR/results-no-summary.md" << 'EOF'
# Iteration Results – bad-scope/iteration_01

**Date:** 2026-03-24
**Status:** ✅ COMPLETE

---

## Changed Files
- `src/app.ts`

## Validation
Pass.

## Acceptance Criteria Status
- [x] Done
EOF

  run bash "$VALIDATOR" "$BAD_DIR/results-no-summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required section: Summary"* ]]
}
