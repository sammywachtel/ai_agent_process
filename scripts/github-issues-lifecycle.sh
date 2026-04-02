#!/usr/bin/env bash
# github-issues-lifecycle.sh — GitHub Issues state management for AP scopes
#
# Handles all GitHub Issues operations when
# enabled, and ALWAYS writes local state (scope-tracker.jsonl + scope-events.log)
# regardless of whether GH is enabled.
#
# Usage:
#   bash scripts/github-issues-lifecycle.sh health-check
#   bash scripts/github-issues-lifecycle.sh start <scope>
#   bash scripts/github-issues-lifecycle.sh associate <scope> <issue_number_or_url>
#   bash scripts/github-issues-lifecycle.sh set-status <scope> <label>
#   bash scripts/github-issues-lifecycle.sh set-iteration <scope> <iteration>
#   bash scripts/github-issues-lifecycle.sh get-iteration <scope>
#   bash scripts/github-issues-lifecycle.sh task-create <scope> <wu-id> <description>
#   bash scripts/github-issues-lifecycle.sh task-update <scope> <wu-id> <status>
#   bash scripts/github-issues-lifecycle.sh close <scope> <decision>
#   bash scripts/github-issues-lifecycle.sh verify <scope>
#   bash scripts/github-issues-lifecycle.sh comment <scope> <message>
#
# Config: reads .agent_process/quality-config.json
#   github_issues.enabled = true/false
#   github_issues.repo = "owner/repo"

set -uo pipefail

# --- Source tracker-utils for local state operations ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/tracker-utils.sh"

# --- Parse action ---
ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: github-issues-lifecycle.sh <health-check|start|associate|set-status|set-iteration|get-iteration|task-create|task-update|close|verify|comment> [args...]" >&2
  exit 1
fi

# --- Config reading ---
CONFIG_FILE=".agent_process/quality-config.json"
GH_ENABLED="false"
REPO=""

if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
  GH_ENABLED=$(jq -r '.github_issues.enabled // false' "$CONFIG_FILE" 2>/dev/null)
  REPO=$(jq -r '.github_issues.repo // empty' "$CONFIG_FILE" 2>/dev/null)
fi

# Normalize enabled to true/false
[[ "$GH_ENABLED" == "true" ]] || GH_ENABLED="false"

# Split REPO into owner/reponame for API calls
OWNER=""
REPONAME=""
if [[ -n "$REPO" && "$REPO" == *"/"* ]]; then
  OWNER="${REPO%%/*}"
  REPONAME="${REPO##*/}"
fi

# --- Input validation ---

validate_scope_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "ERROR: Invalid scope '$1' — only alphanumeric, underscore, hyphen allowed" >&2; return 1; }
}

validate_wu_id() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "ERROR: Invalid WU ID '$1'" >&2; return 1; }
}

# --- run_gh wrapper with 1-retry for transient errors ---
# Pass the full gh command as arguments: run_gh gh issue create --repo "$REPO" ...
# Returns output on success, prints HALT on permanent failure.

run_gh() {
  local output rc
  output=$("$@" 2>&1); rc=$?

  if [[ $rc -ne 0 ]]; then
    # Check for transient errors worth retrying
    if echo "$output" | grep -qiE '502|503|504|timeout|rate limit|API rate|connection refused|ETIMEDOUT'; then
      sleep 3
      output=$("$@" 2>&1); rc=$?
    fi
    if [[ $rc -ne 0 ]]; then
      echo "HALT: gh command failed: $output" >&2
      return 1
    fi
  fi
  echo "$output"
}

# --- Label management (idempotent) ---

REQUIRED_LABELS="ap:scope status:active status:approved status:blocked status:complete status:planning status:executing status:reviewing status:iterate"

ensure_labels() {
  [[ "$GH_ENABLED" != "true" ]] && return 0

  local existing
  existing=$(run_gh gh label list --repo "$REPO" --limit 100) || existing=""

  for label in $REQUIRED_LABELS; do
    if ! echo "$existing" | grep -q "^${label}"; then
      run_gh gh label create "$label" --repo "$REPO" --force >/dev/null || true
    fi
  done
}

# --- Parse issue number from #43, 43, or full URL ---

parse_issue_number() {
  local input="$1"
  local num=""

  # Strip leading # if present
  input="${input#\#}"

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    num="$input"
  elif [[ "$input" =~ /issues/([0-9]+) ]]; then
    num="${BASH_REMATCH[1]}"
  else
    echo "ERROR: Cannot parse issue number from '$1' — expected #N, N, or full URL" >&2
    return 1
  fi

  echo "$num"
}

# --- Generate .run/gh-issue-context.md for sub-agents ---

generate_context_file() {
  local scope="$1"
  local issue_num="$2"
  local status_label="${3:-}"

  local scope_dir=".agent_process/work/${scope}/.run"
  mkdir -p "$scope_dir"

  local iteration
  iteration=$(tracker_get_field "$scope" "iteration")
  iteration="${iteration:-iteration_01}"

  cat > "${scope_dir}/gh-issue-context.md" << CTXEOF
## GitHub Issue Context
- Issue: #${issue_num}
- Repo: ${REPO}
- Current Status: ${status_label:-unknown}
- Scope: ${scope}
- Iteration: ${iteration}

## Available Actions
- Update status: \`bash .agent_process/scripts/github-issues-lifecycle.sh set-status ${scope} <label>\`
- Set iteration: \`bash .agent_process/scripts/github-issues-lifecycle.sh set-iteration ${scope} ${iteration}\`
- Add note: \`bash .agent_process/scripts/github-issues-lifecycle.sh comment ${scope} "your message"\`
- Create work unit: \`bash .agent_process/scripts/github-issues-lifecycle.sh task-create ${scope} WU-001 "description"\`

## Rules
See process/github-issues-handling.md
CTXEOF
}

# --- Action implementations ---

do_health_check() {
  local errors=0

  # 1. Check gh exists
  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/" >&2
    return 1
  fi

  # 2. Check version >= 2.20.0
  local version_str
  version_str=$(gh --version 2>/dev/null | head -1)
  local version
  version=$(echo "$version_str" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [[ -z "$version" ]]; then
    echo "ERROR: Could not parse gh version" >&2
    return 1
  fi

  local major minor
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  if [[ "$major" -lt 2 ]] || [[ "$major" -eq 2 && "$minor" -lt 20 ]]; then
    echo "ERROR: gh version $version is too old. Minimum required: 2.20.0" >&2
    return 1
  fi

  # 3. Check auth + repo access in parallel via background jobs
  local auth_tmp repo_tmp
  auth_tmp=$(mktemp)
  repo_tmp=$(mktemp)

  gh auth status >"$auth_tmp" 2>&1 &
  local auth_pid=$!
  gh repo view "$REPO" --json name >"$repo_tmp" 2>&1 &
  local repo_pid=$!

  local auth_ok=true repo_ok=true
  wait "$auth_pid" || auth_ok=false
  wait "$repo_pid" || repo_ok=false

  rm -f "$auth_tmp" "$repo_tmp"

  if [[ "$auth_ok" == false ]]; then
    echo "ERROR: gh not authenticated. Run: gh auth login" >&2
    return 1
  fi

  if [[ "$repo_ok" == false ]]; then
    echo "ERROR: Cannot access repo $REPO — check permissions and repo name" >&2
    return 1
  fi

  echo "OK: gh $version, authenticated, repo $REPO accessible"
  return 0
}

do_start() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  local ts
  ts=$(_timestamp)

  # Always write local state first
  local existing
  existing=$(tracker_read_scope "$scope")

  if [[ -z "$existing" ]]; then
    # New scope — create tracker entry
    if command -v jq &>/dev/null; then
      tracker_write_scope "$scope" "$(jq -n -c \
        --arg s "$scope" \
        --arg t "$ts" \
        --arg st "active" \
        '{scope: $s, status: $st, created: $t, iteration: "iteration_01"}')"
    else
      tracker_write_scope "$scope" "{\"scope\":\"$scope\",\"status\":\"active\",\"created\":\"$ts\",\"iteration\":\"iteration_01\"}"
    fi
  fi

  events_log "$scope" "SCOPE_START" "action=start"

  # GH operations
  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — local state written for $scope"
    return 0
  fi

  ensure_labels

  # --- Adopt path: if tracker already has gh_issue, verify and adopt ---
  local tracked_issue
  tracked_issue=$(tracker_get_field "$scope" "gh_issue")

  if [[ -n "$tracked_issue" ]]; then
    # Verify the issue still exists and is open
    local view_output
    if view_output=$(run_gh gh issue view "$tracked_issue" --repo "$REPO" --json state,title 2>/dev/null); then
      local issue_state=""
      if command -v jq &>/dev/null; then
        issue_state=$(echo "$view_output" | jq -r '.state // empty' 2>/dev/null)
      fi

      if [[ "$issue_state" == "CLOSED" ]]; then
        echo "ERROR: Issue #$tracked_issue is closed. Reopen it or remove gh_issue from tracker to create a new one." >&2
        return 1
      fi

      # Adopt: ensure ap:scope label is present
      run_gh gh issue edit "$tracked_issue" --repo "$REPO" --add-label "ap:scope" >/dev/null 2>&1 || true

      events_log "$scope" "SCOPE_ADOPT" "issue=$tracked_issue"
      generate_context_file "$scope" "$tracked_issue" "status:active"
      echo "[gh-issues] Adopted existing issue #$tracked_issue for $scope"
      return 0
    else
      echo "[gh-issues] WARNING: Could not verify issue #$tracked_issue — proceeding to search/create" >&2
    fi
  fi

  # --- Search path: look for existing issue by title/label ---
  local issue_list issue_num=""
  issue_list=$(gh issue list --repo "$REPO" --label "ap:scope" --search "$scope in:title" --state open --json number,title --limit 10 2>/dev/null) || issue_list=""

  if [[ -n "$issue_list" && "$issue_list" != "[]" ]] && command -v jq &>/dev/null; then
    issue_num=$(echo "$issue_list" | jq -r --arg s "$scope" '[.[] | select(.title == $s or (.title | startswith($s)))] | .[0].number // empty' 2>/dev/null)
  fi

  if [[ -n "$issue_num" ]]; then
    echo "[gh-issues] Existing issue found: #$issue_num for $scope"
  else
    # --- Create path: no existing issue found ---
    local create_output
    if ! create_output=$(run_gh gh issue create --repo "$REPO" \
      --title "$scope" \
      --body "AP scope: $scope" \
      --label "ap:scope,status:active"); then
      return 1
    fi

    issue_num=$(echo "$create_output" | grep -o '[0-9]*$')
    echo "[gh-issues] Created issue #$issue_num for $scope"
  fi

  # Update tracker with gh_issue number
  if [[ -n "$issue_num" ]]; then
    local current
    current=$(tracker_read_scope "$scope")
    if command -v jq &>/dev/null && [[ -n "$current" ]]; then
      tracker_write_scope "$scope" "$(echo "$current" | jq -c --arg n "$issue_num" '. + {gh_issue: $n}')"
    else
      tracker_write_scope "$scope" "{\"scope\":\"$scope\",\"status\":\"active\",\"created\":\"$ts\",\"iteration\":\"iteration_01\",\"gh_issue\":\"$issue_num\"}"
    fi
    generate_context_file "$scope" "$issue_num" "status:active"
  fi
}

do_associate() {
  local scope="$1"
  local issue_input="$2"
  validate_scope_name "$scope" || return 1

  local issue_num
  issue_num=$(parse_issue_number "$issue_input") || return 1

  # Check if already associated with the same issue — idempotent
  local current_issue
  current_issue=$(tracker_get_field "$scope" "gh_issue")
  if [[ "$current_issue" == "$issue_num" ]]; then
    echo "[gh-issues] Scope $scope already associated with issue #$issue_num"
    return 0
  fi

  # Ensure scope exists in tracker
  local existing
  existing=$(tracker_read_scope "$scope")
  if [[ -z "$existing" ]]; then
    local ts
    ts=$(_timestamp)
    if command -v jq &>/dev/null; then
      tracker_write_scope "$scope" "$(jq -n -c \
        --arg s "$scope" --arg t "$ts" --arg st "active" --arg gh "$issue_num" \
        '{scope: $s, status: $st, created: $t, iteration: "iteration_01", gh_issue: $gh}')"
    else
      tracker_write_scope "$scope" "{\"scope\":\"$scope\",\"status\":\"active\",\"created\":\"$ts\",\"iteration\":\"iteration_01\",\"gh_issue\":\"$issue_num\"}"
    fi
  else
    # Update existing entry with gh_issue
    if command -v jq &>/dev/null; then
      tracker_write_scope "$scope" "$(echo "$existing" | jq -c --arg n "$issue_num" '. + {gh_issue: $n}')"
    fi
  fi

  events_log "$scope" "SCOPE_ASSOCIATE" "issue=$issue_num"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — association recorded locally for $scope → #$issue_num"
    return 0
  fi

  # Verify issue exists
  local view_output
  if ! view_output=$(run_gh gh issue view "$issue_num" --repo "$REPO" --json state,title 2>/dev/null); then
    echo "ERROR: Issue #$issue_num not found or inaccessible" >&2
    return 1
  fi

  # Add ap:scope label
  run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "ap:scope" >/dev/null 2>&1 || true

  # Comment on issue
  run_gh gh issue comment "$issue_num" --repo "$REPO" \
    --body "Associated with AP scope: $scope" >/dev/null 2>&1 || true

  generate_context_file "$scope" "$issue_num" ""
  echo "[gh-issues] Associated scope $scope with issue #$issue_num"
}

do_set_status() {
  local scope="$1"
  local label="$2"
  validate_scope_name "$scope" || return 1

  if [[ -z "$label" ]]; then
    echo "ERROR: Label required (e.g., status:planning, status:executing)" >&2
    return 1
  fi

  events_log "$scope" "COMMENT" "message=status-change:$label"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — status change logged locally for $scope"
    return 0
  fi

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "[gh-issues] WARNING: No gh_issue found for scope $scope" >&2
    return 0
  fi

  # Remove existing status:* labels, then add the new one
  # Get current labels
  local current_labels
  current_labels=$(run_gh gh issue view "$issue_num" --repo "$REPO" --json labels --jq '.[].name' 2>/dev/null) || current_labels=""

  # Remove old status labels (best-effort)
  for old_label in status:planning status:executing status:reviewing status:iterate status:active; do
    if echo "$current_labels" | grep -q "^${old_label}$"; then
      run_gh gh issue edit "$issue_num" --repo "$REPO" --remove-label "$old_label" >/dev/null 2>&1 || true
    fi
  done

  # Add new label
  run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "$label" >/dev/null 2>&1 || true

  # Regenerate context file with new status
  generate_context_file "$scope" "$issue_num" "$label"
  echo "[gh-issues] Updated #$issue_num → $label"
}

do_set_iteration() {
  local scope="$1"
  local iteration="$2"
  validate_scope_name "$scope" || return 1

  # Check scope exists in tracker
  local current
  current=$(tracker_read_scope "$scope")
  if [[ -z "$current" ]]; then
    echo "ERROR: Scope '$scope' not found in tracker" >&2
    return 1
  fi

  # Update tracker
  if command -v jq &>/dev/null; then
    tracker_write_scope "$scope" "$(echo "$current" | jq -c --arg i "$iteration" '. + {iteration: $i}')"
  else
    # sed fallback: replace the iteration value in the JSON line
    local updated
    updated=$(echo "$current" | sed "s/\"iteration\":\"[^\"]*\"/\"iteration\":\"$iteration\"/")
    tracker_write_scope "$scope" "$updated"
  fi

  events_log "$scope" "ITERATION_START" "iteration=$iteration"

  # GH: comment on the issue
  if [[ "$GH_ENABLED" == "true" ]]; then
    local issue_num
    issue_num=$(tracker_get_field "$scope" "gh_issue")
    if [[ -n "$issue_num" ]]; then
      run_gh gh issue comment "$issue_num" --repo "$REPO" \
        --body "Iteration updated: $iteration" >/dev/null 2>&1 || true
    fi
  fi

  echo "[gh-issues] Iteration set to $iteration for $scope"
}

do_get_iteration() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  local current
  current=$(tracker_read_scope "$scope")
  if [[ -z "$current" ]]; then
    echo "ERROR: Scope '$scope' not found in tracker" >&2
    return 1
  fi

  tracker_get_field "$scope" "iteration"
}

do_task_create() {
  local scope="$1"
  local wu_id="$2"
  local desc="${3:-}"
  validate_scope_name "$scope" || return 1
  validate_wu_id "$wu_id" || return 1

  events_log "$scope" "WU_CREATE" "wu_id=$wu_id" "description=$desc"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — WU $wu_id logged locally"
    return 0
  fi

  local parent_num
  parent_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$parent_num" ]]; then
    echo "HALT: No gh_issue found for scope $scope" >&2
    return 1
  fi

  # Create child issue
  local child_output child_num
  child_output=$(run_gh gh issue create --repo "$REPO" \
    --title "$wu_id: $desc" \
    --body "Work unit for scope: $scope" \
    --label "ap:scope") || return 1

  child_num=$(echo "$child_output" | grep -o '[0-9]*$')

  # Link as sub-issue via API
  if [[ -n "$child_num" ]]; then
    run_gh gh api "repos/$OWNER/$REPONAME/issues/$parent_num/sub_issues" \
      -f sub_issue_id="$child_num" >/dev/null 2>&1 || true
    echo "[gh-issues] Created sub-issue #$child_num ($wu_id) under #$parent_num"
  fi
}

do_task_update() {
  local scope="$1"
  local wu_id="$2"
  local status="$3"
  validate_scope_name "$scope" || return 1
  validate_wu_id "$wu_id" || return 1

  events_log "$scope" "WU_UPDATE" "wu_id=$wu_id" "status=$status"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — WU $wu_id update ($status) logged locally"
    return 0
  fi

  # Find the sub-issue for this WU
  local issue_list wu_issue_num=""
  issue_list=$(run_gh gh issue list --repo "$REPO" --search "$wu_id in:title" --state open --json number,title --limit 10) || issue_list=""

  if [[ -n "$issue_list" && "$issue_list" != "[]" ]] && command -v jq &>/dev/null; then
    wu_issue_num=$(echo "$issue_list" | jq -r --arg w "$wu_id" '[.[] | select(.title | startswith($w))] | .[0].number // empty' 2>/dev/null)
  fi

  if [[ -z "$wu_issue_num" ]]; then
    echo "[gh-issues] WARNING: No open issue found for WU $wu_id" >&2
    return 0
  fi

  case "$status" in
    complete)
      run_gh gh issue close "$wu_issue_num" --repo "$REPO" >/dev/null 2>&1 || true
      echo "[gh-issues] Closed sub-issue #$wu_issue_num ($wu_id)"
      ;;
    blocked)
      run_gh gh issue edit "$wu_issue_num" --repo "$REPO" --add-label "status:blocked" >/dev/null 2>&1 || true
      echo "[gh-issues] Labeled #$wu_issue_num ($wu_id) as status:blocked"
      ;;
    *)
      run_gh gh issue edit "$wu_issue_num" --repo "$REPO" --add-label "status:$status" >/dev/null 2>&1 || true
      echo "[gh-issues] Updated #$wu_issue_num ($wu_id) → $status"
      ;;
  esac
}

do_close() {
  local scope="$1"
  local decision="${2:-approved}"
  validate_scope_name "$scope" || return 1

  # Update tracker status
  local current
  current=$(tracker_read_scope "$scope")
  if [[ -n "$current" ]] && command -v jq &>/dev/null; then
    tracker_write_scope "$scope" "$(echo "$current" | jq -c --arg d "$decision" '. + {status: "closed", decision: $d}')"
  fi

  events_log "$scope" "SCOPE_CLOSE" "decision=$decision"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — scope $scope closed locally ($decision)"
    return 0
  fi

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "[gh-issues] WARNING: No gh_issue found for scope $scope" >&2
    return 0
  fi

  # Add decision label and close
  run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "status:$decision" >/dev/null 2>&1 || true
  run_gh gh issue close "$issue_num" --repo "$REPO" >/dev/null 2>&1 || true

  echo "[gh-issues] Closed issue #$issue_num ($scope) — $decision"
}

do_verify() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  echo "## GitHub Issues Verification: $scope"
  echo ""

  local current
  current=$(tracker_read_scope "$scope")
  if [[ -z "$current" ]]; then
    echo "WARNING: No tracker entry for scope $scope"
    return 0
  fi

  echo "Tracker state:"
  echo "$current" | jq . 2>/dev/null || echo "$current"
  echo ""

  local events_file="${EVENTS_DIR}/${scope}/scope-events.log"
  if [[ -f "$events_file" ]]; then
    local event_count
    event_count=$(wc -l < "$events_file" | tr -d ' ')
    echo "Events: $event_count recorded"
    echo "---"
    cat "$events_file"
  else
    echo "Events: none recorded"
  fi

  if [[ "$GH_ENABLED" == "true" ]]; then
    local issue_num
    issue_num=$(tracker_get_field "$scope" "gh_issue")
    if [[ -n "$issue_num" ]]; then
      echo ""
      echo "GitHub issue #$issue_num:"
      local view_output
      view_output=$(run_gh gh issue view "$issue_num" --repo "$REPO" --json state,labels,title) && echo "$view_output" || echo "  (could not fetch)"
    fi
  fi
}

do_comment() {
  local scope="$1"
  local message="$2"
  validate_scope_name "$scope" || return 1

  events_log "$scope" "COMMENT" "message=$message"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — comment logged locally for $scope"
    return 0
  fi

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "[gh-issues] WARNING: No gh_issue found for scope $scope" >&2
    return 0
  fi

  run_gh gh issue comment "$issue_num" --repo "$REPO" --body "$message" >/dev/null 2>&1 || true
  echo "[gh-issues] Comment added to #$issue_num"
}

# --- Route actions ---

case "$ACTION" in
  health-check)
    do_health_check
    ;;
  start)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh start <scope>" >&2; exit 1; }
    do_start "$SCOPE"
    ;;
  associate)
    SCOPE="${2:-}"
    ISSUE_INPUT="${3:-}"
    [[ -z "$SCOPE" || -z "$ISSUE_INPUT" ]] && { echo "Usage: github-issues-lifecycle.sh associate <scope> <issue_number_or_url>" >&2; exit 1; }
    do_associate "$SCOPE" "$ISSUE_INPUT"
    ;;
  set-status)
    SCOPE="${2:-}"
    LABEL="${3:-}"
    [[ -z "$SCOPE" || -z "$LABEL" ]] && { echo "Usage: github-issues-lifecycle.sh set-status <scope> <label>" >&2; exit 1; }
    do_set_status "$SCOPE" "$LABEL"
    ;;
  set-iteration)
    SCOPE="${2:-}"
    ITERATION="${3:-}"
    [[ -z "$SCOPE" || -z "$ITERATION" ]] && { echo "Usage: github-issues-lifecycle.sh set-iteration <scope> <iteration>" >&2; exit 1; }
    do_set_iteration "$SCOPE" "$ITERATION"
    ;;
  get-iteration)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh get-iteration <scope>" >&2; exit 1; }
    do_get_iteration "$SCOPE"
    ;;
  task-create)
    SCOPE="${2:-}"
    WU_ID="${3:-}"
    DESC="${4:-}"
    [[ -z "$SCOPE" || -z "$WU_ID" ]] && { echo "Usage: github-issues-lifecycle.sh task-create <scope> <wu-id> <description>" >&2; exit 1; }
    do_task_create "$SCOPE" "$WU_ID" "$DESC"
    ;;
  task-update)
    SCOPE="${2:-}"
    WU_ID="${3:-}"
    STATUS="${4:-}"
    [[ -z "$SCOPE" || -z "$WU_ID" || -z "$STATUS" ]] && { echo "Usage: github-issues-lifecycle.sh task-update <scope> <wu-id> <status>" >&2; exit 1; }
    do_task_update "$SCOPE" "$WU_ID" "$STATUS"
    ;;
  close)
    SCOPE="${2:-}"
    DECISION="${3:-approved}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh close <scope> [decision]" >&2; exit 1; }
    do_close "$SCOPE" "$DECISION"
    ;;
  verify)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh verify <scope>" >&2; exit 1; }
    do_verify "$SCOPE"
    ;;
  comment)
    SCOPE="${2:-}"
    MESSAGE="${3:-}"
    [[ -z "$SCOPE" || -z "$MESSAGE" ]] && { echo "Usage: github-issues-lifecycle.sh comment <scope> <message>" >&2; exit 1; }
    do_comment "$SCOPE" "$MESSAGE"
    ;;
  *)
    echo "ERROR: Unknown action '$ACTION'" >&2
    echo "Valid actions: health-check, start, associate, set-status, set-iteration, get-iteration, task-create, task-update, close, verify, comment" >&2
    exit 1
    ;;
esac

exit $?
