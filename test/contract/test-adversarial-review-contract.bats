#!/usr/bin/env bats
# test-adversarial-review-contract.bats — Tests for adversarial review validator
#
# Catches the specific anti-patterns we've seen in real reviews:
# - Qualified passes: "PASS (framework ready)"
# - BLOCKED used as verdict (not PASS/FAIL)
# - Missing file evidence
# - Missing summary

VALIDATOR="test/contract/validate-adversarial-review.sh"
GOOD_DIR="test/fixtures/sample-artifacts/good"
BAD_DIR="test/fixtures/sample-artifacts/bad"

setup() {
  mkdir -p "$GOOD_DIR" "$BAD_DIR"
}

# --- Good reviews ---

@test "clean adversarial review passes" {
  cat > "$GOOD_DIR/review-clean.md" << 'EOF'
# Adversarial Review — test-scope/iteration_01

**Reviewer:** Fresh instance (no implementation context)
**Date:** 2026-03-24

## Per-Criterion Assessment

#### Criterion 1: "Feature X implemented"
**Verdict:** PASS
**Evidence:**
- File: `src/app.ts`, lines 42-58: Function featureX() exported and implemented

#### Criterion 2: "Tests pass"
**Verdict:** PASS
**Evidence:**
- File: `src/__tests__/app.test.ts`, lines 10-25: 3 test cases for featureX

### Summary
**Overall:** 2/2 criteria PASS
**Blocking issues:** None
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/review-clean.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VERDICT: PASS"* ]]
}

@test "review with FAIL verdicts passes validation" {
  cat > "$GOOD_DIR/review-with-fails.md" << 'EOF'
# Adversarial Review — test-scope/iteration_01

**Reviewer:** Fresh instance (no implementation context)
**Date:** 2026-03-24

#### Criterion 1: "Feature X implemented"
**Verdict:** PASS
**Evidence:**
- File: `src/app.ts`, lines 42-58: featureX exists

#### Criterion 2: "Tests pass"
**Verdict:** FAIL
**Evidence:**
- File: `src/__tests__/app.test.ts`: No test file found for featureX

### Summary
**Overall:** 1/2 criteria PASS
**Blocking issues:** Criterion 2 — no tests
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/review-with-fails.md"
  [ "$status" -eq 0 ]
}

@test "table-format review passes" {
  cat > "$GOOD_DIR/review-table.md" << 'EOF'
# Adversarial Review — test-scope/iteration_01

**Reviewer:** Fresh Task agent, zero implementation context

| Criterion | Verdict | Evidence |
|-----------|---------|----------|
| AC1 — Feature X | **PASS** | `src/app.ts` line 42: featureX() exported |
| AC2 — Tests pass | **FAIL** | No test file found in `src/__tests__/` |

**Overall: 1/2 PASS**
EOF

  run bash "$VALIDATOR" "$GOOD_DIR/review-table.md"
  [ "$status" -eq 0 ]
}

# --- Bad reviews (regression tests for known failures) ---

@test "REGRESSION: qualified pass 'PASS (framework ready)' is rejected" {
  cat > "$BAD_DIR/review-qualified-pass.md" << 'EOF'
# Adversarial Review

**Reviewer:** Fresh instance

#### Criterion 1: "Framework completed"
**Verdict:** PASS (framework ready)
**Evidence:**
- File: `src/framework.ts`, lines 1-50: Template with TBD placeholders

### Summary
**Overall:** 1/1 criteria PASS
EOF

  run bash "$VALIDATOR" "$BAD_DIR/review-qualified-pass.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Qualified pass"* ]]
}

@test "REGRESSION: qualified pass 'PASS (documented platform constraint)' is rejected" {
  cat > "$BAD_DIR/review-qualified-constraint.md" << 'EOF'
# Adversarial Review

**Reviewer:** Fresh agent

#### Criterion 1: "T4 evaluation completed"
**Verdict:** PASS (documented platform constraint)
**Evidence:**
- T4 not available on Cloud Run

### Summary
**Overall:** 1/1 criteria PASS
EOF

  run bash "$VALIDATOR" "$BAD_DIR/review-qualified-constraint.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Qualified pass"* ]]
}

@test "REGRESSION: BLOCKED used as verdict is rejected" {
  cat > "$BAD_DIR/review-blocked-verdict.md" << 'EOF'
# Adversarial Review

**Reviewer:** Fresh agent

| Criterion | Verdict | Reason |
|-----------|---------|--------|
| AC1 | **BLOCKED** | No GCP access |
| AC2 | **BLOCKED** | No GCP access |
| AC5 | **PASS** | Code looks clean |

**Overall: 1/3 PASS, 2 BLOCKED**
EOF

  run bash "$VALIDATOR" "$BAD_DIR/review-blocked-verdict.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "review with no file evidence is rejected" {
  cat > "$BAD_DIR/review-no-evidence.md" << 'EOF'
# Adversarial Review

**Reviewer:** Fresh instance

#### Criterion 1: "Feature X implemented"
**Verdict:** PASS
**Evidence:**
- I believe this is done based on the implementation

#### Criterion 2: "Tests pass"
**Verdict:** PASS
**Evidence:**
- Tests seem to be working

### Summary
**Overall:** 2/2 criteria PASS
EOF

  run bash "$VALIDATOR" "$BAD_DIR/review-no-evidence.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No file evidence"* ]]
}

@test "review with no verdicts is rejected" {
  cat > "$BAD_DIR/review-no-verdicts.md" << 'EOF'
# Adversarial Review

The code looks good overall. All criteria appear to be met.
I recommend approval.
EOF

  run bash "$VALIDATOR" "$BAD_DIR/review-no-verdicts.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No verdicts found"* ]]
}
