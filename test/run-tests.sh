#!/usr/bin/env bash
# run-tests.sh — Master test runner for AI Agent Process framework
#
# Runs all test layers in order:
#   1. Unit tests (shell scripts)
#   2. Contract tests (validators against fixtures)
#   3. Regression tests (known-bad artifacts)
#
# Usage:
#   bash test/run-tests.sh              # Run all tests
#   bash test/run-tests.sh unit         # Run only unit tests
#   bash test/run-tests.sh contract     # Run only contract tests
#   bash test/run-tests.sh scan <path>  # Scan real artifacts at path
#
# Dependencies: bats-core (brew install bats-core)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

LAYER="${1:-all}"
SCAN_PATH="${2:-}"

# Colors (because life's too short for monochrome test output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

header() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo ""
}

# Check bats is available
if ! command -v bats &>/dev/null; then
  echo -e "${RED}Error: bats-core not installed. Run: brew install bats-core${NC}"
  exit 1
fi

# --- Layer 1: Unit Tests ---
run_unit_tests() {
  header "Layer 1: Unit Tests (Shell Scripts)"

  for test_file in test/unit/*.bats; do
    if [[ -f "$test_file" ]]; then
      echo -e "${YELLOW}Running: $(basename "$test_file")${NC}"
      if bats "$test_file"; then
        ((TOTAL_PASS++))
      else
        ((TOTAL_FAIL++))
      fi
      echo ""
    fi
  done
}

# --- Layer 2: Contract Tests ---
run_contract_tests() {
  header "Layer 2: Contract Tests (Artifact Validators)"

  for test_file in test/contract/test-*.bats; do
    if [[ -f "$test_file" ]]; then
      echo -e "${YELLOW}Running: $(basename "$test_file")${NC}"
      if bats "$test_file"; then
        ((TOTAL_PASS++))
      else
        ((TOTAL_FAIL++))
      fi
      echo ""
    fi
  done
}

# --- Layer 3: Scan Real Artifacts ---
scan_real_artifacts() {
  local target_path="$1"
  header "Layer 3: Real Artifact Scan"
  echo "Target: $target_path"
  echo ""

  if [[ ! -d "$target_path" ]]; then
    echo -e "${RED}Error: Path not found: $target_path${NC}"
    return 1
  fi

  local results_pass=0
  local results_fail=0
  local results_warn=0
  local review_pass=0
  local review_fail=0
  local review_warn=0

  # Scan results.md files
  echo -e "${YELLOW}--- Scanning results.md files ---${NC}"
  echo ""
  while IFS= read -r file; do
    # Get relative path for cleaner output
    rel_path="${file#$target_path/}"
    echo -e "${BLUE}  $rel_path${NC}"

    output=$(bash test/contract/validate-results.sh "$file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      if echo "$output" | grep -q "WARN"; then
        echo -e "    ${YELLOW}PASS (with warnings)${NC}"
        ((results_warn++))
      else
        echo -e "    ${GREEN}PASS${NC}"
      fi
      ((results_pass++))
    else
      echo -e "    ${RED}FAIL${NC}"
      # Show violation details
      echo "$output" | grep "FAIL:" | sed 's/^/      /'
      ((results_fail++))
    fi
  done < <(find "$target_path" -name "results.md" -not -path "*/templates/*" | sort)

  echo ""
  echo "  results.md: ${results_pass} pass, ${results_fail} fail, ${results_warn} warnings"

  # Scan adversarial-review.md files
  echo ""
  echo -e "${YELLOW}--- Scanning adversarial-review.md files ---${NC}"
  echo ""
  while IFS= read -r file; do
    rel_path="${file#$target_path/}"
    echo -e "${BLUE}  $rel_path${NC}"

    output=$(bash test/contract/validate-adversarial-review.sh "$file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      if echo "$output" | grep -q "WARN"; then
        echo -e "    ${YELLOW}PASS (with warnings)${NC}"
        ((review_warn++))
      else
        echo -e "    ${GREEN}PASS${NC}"
      fi
      ((review_pass++))
    else
      echo -e "    ${RED}FAIL${NC}"
      echo "$output" | grep "FAIL:" | sed 's/^/      /'
      ((review_fail++))
    fi
  done < <(find "$target_path" -name "adversarial-review.md" | sort)

  echo ""
  echo "  adversarial-review.md: ${review_pass} pass, ${review_fail} fail, ${review_warn} warnings"

  # Scan iteration_plan.md files
  echo ""
  echo -e "${YELLOW}--- Scanning iteration_plan.md files ---${NC}"
  echo ""
  local plan_pass=0
  local plan_fail=0
  local plan_warn=0
  while IFS= read -r file; do
    rel_path="${file#$target_path/}"
    echo -e "${BLUE}  $rel_path${NC}"

    output=$(bash test/contract/validate-iteration-plan.sh "$file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      if echo "$output" | grep -q "WARN"; then
        echo -e "    ${YELLOW}PASS (with warnings)${NC}"
        ((plan_warn++))
      else
        echo -e "    ${GREEN}PASS${NC}"
      fi
      ((plan_pass++))
    else
      echo -e "    ${RED}FAIL${NC}"
      echo "$output" | grep "FAIL:" | sed 's/^/      /'
      ((plan_fail++))
    fi
  done < <(find "$target_path" -name "iteration_plan.md" -not -path "*/templates/*" | sort)

  echo ""
  echo "  iteration_plan.md: ${plan_pass} pass, ${plan_fail} fail, ${plan_warn} warnings"

  # Scan scope event logs
  echo ""
  echo -e "${YELLOW}--- Scanning scope-events.log files ---${NC}"
  echo ""
  local events_pass=0
  local events_fail=0
  while IFS= read -r file; do
    rel_path="${file#$target_path/}"
    echo -e "${BLUE}  $rel_path${NC}"

    output=$(bash test/contract/validate-scope-events.sh "$file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      echo -e "    ${GREEN}PASS${NC}"
      ((events_pass++))
    else
      echo -e "    ${RED}FAIL${NC}"
      echo "$output" | grep "FAIL:" | sed 's/^/      /'
      ((events_fail++))
    fi
  done < <(find "$target_path" -name "scope-events.log" | sort)

  echo ""
  echo "  scope-events.log: ${events_pass} pass, ${events_fail} fail"

  # Scan knowledge files
  echo ""
  echo -e "${YELLOW}--- Scanning knowledge JSONL files ---${NC}"
  echo ""
  local knowledge_pass=0
  local knowledge_fail=0
  while IFS= read -r file; do
    rel_path="${file#$target_path/}"
    echo -e "${BLUE}  $rel_path${NC}"

    output=$(bash test/contract/validate-knowledge-entry.sh "$file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      echo -e "    ${GREEN}PASS${NC}"
      ((knowledge_pass++))
    else
      echo -e "    ${RED}FAIL${NC}"
      echo "$output" | grep "FAIL" | sed 's/^/      /'
      ((knowledge_fail++))
    fi
  done < <(find "$target_path" -name "*.jsonl" -path "*/knowledge/*" | sort)

  echo ""
  echo "  knowledge: ${knowledge_pass} pass, ${knowledge_fail} fail"

  # Summary
  echo ""
  header "Scan Summary"
  local total_pass=$((results_pass + review_pass + plan_pass + events_pass + knowledge_pass))
  local total_fail=$((results_fail + review_fail + plan_fail + events_fail + knowledge_fail))
  echo "  Total artifacts scanned: $((total_pass + total_fail))"
  echo -e "  ${GREEN}Pass: ${total_pass}${NC}"
  echo -e "  ${RED}Fail: ${total_fail}${NC}"

  if [[ $total_fail -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}Note: Older artifacts may fail due to format evolution.${NC}"
    echo -e "  ${YELLOW}Use --strict mode to enforce current format only.${NC}"
    return 1
  fi
  return 0
}

# --- Main ---
case "$LAYER" in
  all)
    run_unit_tests
    run_contract_tests
    ;;
  unit)
    run_unit_tests
    ;;
  contract)
    run_contract_tests
    ;;
  scan)
    if [[ -z "$SCAN_PATH" ]]; then
      echo "Usage: run-tests.sh scan <path-to-.agent_process>"
      echo "Example: run-tests.sh scan /path/to/project/.agent_process/work"
      exit 1
    fi
    scan_real_artifacts "$SCAN_PATH"
    ;;
  *)
    echo "Usage: run-tests.sh [all|unit|contract|scan <path>]"
    exit 1
    ;;
esac

# --- Final Report ---
header "Test Results"
echo "  Suite pass: ${TOTAL_PASS}"
echo "  Suite fail: ${TOTAL_FAIL}"

if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo ""
  echo -e "  ${RED}OVERALL: FAIL${NC}"
  exit 1
else
  echo ""
  echo -e "  ${GREEN}OVERALL: PASS${NC}"
  exit 0
fi
