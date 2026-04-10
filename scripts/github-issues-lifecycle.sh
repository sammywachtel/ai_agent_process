#!/usr/bin/env bash
# github-issues-lifecycle.sh — GitHub Issues state management for AP scopes
#
# Handles all GitHub Issues operations when
# enabled, and ALWAYS writes local state (scope-tracker.jsonl + scope-events.log)
# regardless of whether GH is enabled.
#
# Usage:
#   bash scripts/github-issues-lifecycle.sh health-check
#   bash scripts/github-issues-lifecycle.sh create-labels
#   bash scripts/github-issues-lifecycle.sh create <scope> [description]   # Create issue, no status label
#   bash scripts/github-issues-lifecycle.sh start <scope> [description]    # Create + set status:executing
#   bash scripts/github-issues-lifecycle.sh associate <scope> <issue_number_or_url>
#   bash scripts/github-issues-lifecycle.sh set-status <scope> <status>  # e.g., "planning" or "status:planning"
#   bash scripts/github-issues-lifecycle.sh retitle <scope> <new_title>
#   bash scripts/github-issues-lifecycle.sh sync-body <scope>
#   bash scripts/github-issues-lifecycle.sh set-priority <scope> <priority:P0-P4>
#   bash scripts/github-issues-lifecycle.sh set-iteration <scope> <iteration>
#   bash scripts/github-issues-lifecycle.sh get-iteration <scope>
#   bash scripts/github-issues-lifecycle.sh get-issue <scope>
#   bash scripts/github-issues-lifecycle.sh search-issue <scope>
#   bash scripts/github-issues-lifecycle.sh list-issues
#   bash scripts/github-issues-lifecycle.sh audit
#   bash scripts/github-issues-lifecycle.sh resolve-input <issue#|scope|requirement_path>
#   bash scripts/github-issues-lifecycle.sh task-create <scope> <wu-id> <description>
#   bash scripts/github-issues-lifecycle.sh task-update <scope> <wu-id> <status>
#   bash scripts/github-issues-lifecycle.sh close <scope> <decision>
#   bash scripts/github-issues-lifecycle.sh verify <scope>
#   bash scripts/github-issues-lifecycle.sh comment <scope> <message>
#   bash scripts/github-issues-lifecycle.sh split <parent_scope> "child1|description" "child2|description" [...]
#
# Config: reads .agent_process/quality-config.json
#   github_issues.enabled = true/false
#   github_issues.repo = "owner/repo"
#
# Authentication:
#   Option 1: gh auth login (interactive)
#   Option 2: Set GH_TOKEN or GITHUB_TOKEN environment variable
#
# The gh CLI automatically uses GH_TOKEN/GITHUB_TOKEN if set.

set -uo pipefail

# --- Parse action ---
ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: github-issues-lifecycle.sh <health-check|create-labels|create|start|associate|set-status|retitle|sync-body|set-priority|set-iteration|get-iteration|get-issue|search-issue|list-issues|audit|resolve-input|task-create|task-update|close|verify|comment|split> [args...]" >&2
  exit 1
fi

# --- AP Root Detection (polyrepo support) ---
# If .agent_process/ doesn't exist in cwd, traverse up to find it.
# This handles nested repos where the agent may be in a sub-repo.
# IMPORTANT: Must happen BEFORE sourcing tracker-utils.sh, which sets
# paths relative to the working directory.

find_ap_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.agent_process" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

AP_ROOT=""
if [[ ! -d ".agent_process" ]]; then
  AP_ROOT=$(find_ap_root)
  if [[ -n "$AP_ROOT" ]]; then
    echo "[gh-issues] Not at AP root. Changing to: $AP_ROOT" >&2
    cd "$AP_ROOT" || { echo "ERROR: Failed to cd to AP root" >&2; exit 1; }
  else
    echo "ERROR: No .agent_process/ found in current directory or any parent." >&2
    echo "HINT: Run this script from your project root, or ensure AP is installed." >&2
    exit 1
  fi
else
  AP_ROOT="$PWD"
fi

# --- Source tracker-utils for local state operations ---
# Sourced AFTER cd to AP root so TRACKER_FILE resolves correctly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/tracker-utils.sh"

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

# --- Git Remote Sanity Check (polyrepo support) ---
# Warn if current git repo doesn't match configured repo — may indicate misconfiguration.
if [[ "$GH_ENABLED" == "true" && -n "$REPO" ]]; then
  CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')
  if [[ -n "$CURRENT_REMOTE" && "$CURRENT_REMOTE" != "$REPO" ]]; then
    echo "[gh-issues] INFO: Git remote ($CURRENT_REMOTE) differs from configured repo ($REPO)" >&2
    echo "[gh-issues] This is expected in polyrepo setups where issues are tracked centrally." >&2
  fi
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

# --- Priority config helpers ---

get_priority_config() {
  local field="$1"
  if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    jq -r ".priority_labels.${field} // empty" "$CONFIG_FILE" 2>/dev/null
  fi
}

priority_labels_enabled() {
  local enabled
  enabled=$(get_priority_config "enabled")
  # Default to true if not specified (or if config section missing)
  [[ "$enabled" != "false" ]]
}

get_default_priority() {
  local default
  default=$(get_priority_config "default")
  echo "${default:-priority:P2}"
}

# --- Issue body template rendering ---
# Uses envsubst to substitute variables in the template.
# Checks templates/overrides/ first, falls back to templates/.

render_issue_body() {
  local description="$1"
  local parent_issue="${2:-}"       # optional
  local parent_scope="${3:-}"       # optional
  local relationship_type="${4:-}"  # "split from" | "work unit of" | ""
  local requirement_doc="${5:-}"    # optional

  # Build optional sections (complete markdown blocks or empty)
  local PARENT_SECTION=""
  if [[ -n "$parent_issue" && -n "$parent_scope" ]]; then
    PARENT_SECTION="
---
**Parent:** #${parent_issue} (${parent_scope})
**Relationship:** ${relationship_type}"
  fi

  local REQUIREMENT_SECTION=""
  if [[ -n "$requirement_doc" ]]; then
    REQUIREMENT_SECTION="
---
**Requirement:** [\`${requirement_doc}\`](${requirement_doc})"
  fi

  # Find template (overrides first, then default)
  local template=""
  if [[ -f "$AP_ROOT/templates/overrides/github-issue-body.md" ]]; then
    template="$AP_ROOT/templates/overrides/github-issue-body.md"
  elif [[ -f "$AP_ROOT/templates/github-issue-body.md" ]]; then
    template="$AP_ROOT/templates/github-issue-body.md"
  else
    # Fallback: no template found, just return the description
    echo "## Description"
    echo ""
    echo "$description"
    echo "$PARENT_SECTION"
    echo "$REQUIREMENT_SECTION"
    return 0
  fi

  # Export variables and substitute
  export DESCRIPTION="$description"
  export PARENT_SECTION
  export REQUIREMENT_SECTION
  envsubst < "$template"
}

# --- Label management (idempotent) ---

REQUIRED_LABELS="ap:scope status:approved status:blocked status:complete status:planning status:executing status:awaiting_review status:reviewing status:iterate status:split"

# Priority labels (P0=critical, P4=low) — only created if priority_labels.enabled
PRIORITY_LABELS=(
  "priority:P0|#B60205|Critical - drop everything"
  "priority:P1|#D93F0B|High - this sprint"
  "priority:P2|#FBCA04|Medium - default priority"
  "priority:P3|#0E8A16|Low - when time permits"
  "priority:P4|#C5DEF5|Minimal - nice to have"
)

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

do_create_labels() {
  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — no labels to create"
    return 0
  fi

  echo "[gh-issues] Ensuring labels exist in $REPO..."
  local existing created=0
  existing=$(run_gh gh label list --repo "$REPO" --limit 100) || existing=""

  for label in $REQUIRED_LABELS; do
    if ! echo "$existing" | grep -q "^${label}"; then
      if run_gh gh label create "$label" --repo "$REPO" --force >/dev/null 2>&1; then
        echo "  Created: $label"
        created=$((created + 1))
      fi
    fi
  done

  # Create priority labels if enabled
  if priority_labels_enabled; then
    for entry in "${PRIORITY_LABELS[@]}"; do
      local label color desc
      label="${entry%%|*}"
      local rest="${entry#*|}"
      color="${rest%%|*}"
      desc="${rest#*|}"

      if ! echo "$existing" | grep -q "^${label}"; then
        if run_gh gh label create "$label" --repo "$REPO" --color "${color#\#}" --description "$desc" --force >/dev/null 2>&1; then
          echo "  Created: $label"
          created=$((created + 1))
        fi
      fi
    done
  fi

  if [[ $created -eq 0 ]]; then
    echo "[gh-issues] All labels already exist"
  else
    echo "[gh-issues] Created $created new label(s)"
  fi
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

  local branch_name
  branch_name="issue/${issue_num}-${scope}"

  cat > "${scope_dir}/gh-issue-context.md" << CTXEOF
## GitHub Issue Context
- Issue: #${issue_num}
- Repo: ${REPO}
- Current Status: ${status_label:-unknown}
- Scope: ${scope}
- Iteration: ${iteration}
- Suggested Branch: ${branch_name}

## Available Actions
- Update status: \`bash .agent_process/scripts/github-issues-lifecycle.sh set-status ${scope} <label>\`
- Retitle issue: \`bash .agent_process/scripts/github-issues-lifecycle.sh retitle ${scope} "new title"\`
- Sync issue body: \`bash .agent_process/scripts/github-issues-lifecycle.sh sync-body ${scope}\`
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

  # 3. Check auth + repo access
  # If GH_TOKEN or GITHUB_TOKEN is set, skip `gh auth status` (it doesn't recognize env var auth)
  # and rely on the repo access check to verify the token works.
  local auth_method="interactive"
  if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    auth_method="token"
  fi

  local repo_tmp
  repo_tmp=$(mktemp)

  if [[ "$auth_method" == "interactive" ]]; then
    # Check interactive auth
    if ! gh auth status >/dev/null 2>&1; then
      echo "ERROR: gh not authenticated. Run: gh auth login, or set GH_TOKEN/GITHUB_TOKEN" >&2
      rm -f "$repo_tmp"
      return 1
    fi
  fi

  # Check repo access (this validates token auth too)
  if ! gh repo view "$REPO" --json name >"$repo_tmp" 2>&1; then
    rm -f "$repo_tmp"
    if [[ "$auth_method" == "token" ]]; then
      echo "ERROR: Cannot access repo $REPO with GH_TOKEN — check token permissions and repo name" >&2
    else
      echo "ERROR: Cannot access repo $REPO — check permissions and repo name" >&2
    fi
    return 1
  fi

  rm -f "$repo_tmp"
  echo "OK: gh $version, authenticated ($auth_method), repo $REPO accessible"
  return 0
}

# do_create — Create/adopt a GH issue for a scope WITHOUT setting a status label.
# Use this when you want to track a scope but haven't started work yet.
# The issue gets only the ap:scope label; status labels come later via set-status.
do_create() {
  local scope="$1"
  local description="${2:-}"  # Optional description for the issue body
  validate_scope_name "$scope" || return 1

  # Handle local state (tracker, events, current_iteration.conf)
  scope_start "$scope" >/dev/null

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
      local adopt_error
      if ! adopt_error=$(run_gh gh issue edit "$tracked_issue" --repo "$REPO" --add-label "ap:scope" 2>&1); then
        echo "[gh-issues] WARNING: Could not add ap:scope label to #$tracked_issue: $adopt_error" >&2
      fi

      events_log "$scope" "SCOPE_ADOPT" "issue=$tracked_issue"
      generate_context_file "$scope" "$tracked_issue" ""
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
    # Look up requirement doc for the body
    local req_path=""
    req_path=$(find_requirement_doc "$scope" 2>/dev/null) || req_path=""

    # Use provided description or default
    local body_desc="${description:-Scope: ${scope}}"
    local body
    body=$(render_issue_body "$body_desc" "" "" "" "$req_path")

    local create_output
    if ! create_output=$(run_gh gh issue create --repo "$REPO" \
      --title "$scope" \
      --body "$body" \
      --label "ap:scope"); then
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
      # No jq fallback — scope_start already created the entry, just need to add gh_issue
      local ts
      ts=$(_timestamp)
      tracker_write_scope "$scope" "{\"scope\":\"$scope\",\"status\":\"active\",\"created\":\"$ts\",\"iteration\":\"iteration_01\",\"gh_issue\":\"$issue_num\"}"
    fi

    # Apply default priority label if priority labels are enabled
    if priority_labels_enabled; then
      local default_priority priority_error
      default_priority=$(get_default_priority)
      if ! priority_error=$(run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "$default_priority" 2>&1); then
        echo "[gh-issues] WARNING: Could not set default priority '$default_priority' on #$issue_num: $priority_error" >&2
      fi
    fi

    generate_context_file "$scope" "$issue_num" ""

    # Auto-sync issue body with requirement doc content (if requirement doc exists)
    local req_path
    if req_path=$(find_requirement_doc "$scope" 2>/dev/null); then
      echo "[gh-issues] Syncing issue body with requirement doc..."
      local sync_error
      if ! sync_error=$(do_sync_body "$scope" 2>&1); then
        echo "[gh-issues] WARNING: Could not sync issue body: $sync_error" >&2
      fi
    fi
  fi
}

# do_start — Create/adopt a GH issue AND set status:executing (work is beginning).
# This is a convenience wrapper: create + set-status executing.
do_start() {
  local scope="$1"
  local description="${2:-}"

  # Create the issue (or adopt existing)
  do_create "$scope" "$description" || return $?

  # If GH is enabled, set status to executing
  if [[ "$GH_ENABLED" == "true" ]]; then
    do_set_status "$scope" "executing"
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
  local label_error
  if ! label_error=$(run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "ap:scope" 2>&1); then
    echo "[gh-issues] WARNING: Could not add ap:scope label to #$issue_num: $label_error" >&2
  fi

  # Comment on issue
  local comment_error
  if ! comment_error=$(run_gh gh issue comment "$issue_num" --repo "$REPO" --body "Associated with AP scope: $scope" 2>&1); then
    echo "[gh-issues] WARNING: Could not add association comment to #$issue_num: $comment_error" >&2
  fi

  generate_context_file "$scope" "$issue_num" ""
  echo "[gh-issues] Associated scope $scope with issue #$issue_num"
}

do_set_status() {
  local scope="$1"
  local label="$2"
  validate_scope_name "$scope" || return 1

  if [[ -z "$label" ]]; then
    echo "ERROR: Label required (e.g., planning, executing, or status:planning)" >&2
    return 1
  fi

  # Normalize: accept both "planning" and "status:planning"
  if [[ "$label" != status:* ]]; then
    label="status:$label"
  fi

  # Update local state (tracker + events)
  scope_set_status "$scope" "$label"

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
  current_labels=$(run_gh gh issue view "$issue_num" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null) || current_labels=""

  # Check if already has the target label — skip if no change needed
  if echo "$current_labels" | grep -q "^${label}$"; then
    echo "[gh-issues] #$issue_num already has $label — no change"
    return 0
  fi

  # Remove old status labels (best-effort — failure is OK, label might not exist)
  for old_label in status:planning status:executing status:awaiting_review status:reviewing status:iterate; do
    if echo "$current_labels" | grep -q "^${old_label}$"; then
      run_gh gh issue edit "$issue_num" --repo "$REPO" --remove-label "$old_label" >/dev/null 2>&1 || true
    fi
  done

  # Add new label — capture result to report honestly
  local add_error
  if add_error=$(run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "$label" 2>&1); then
    generate_context_file "$scope" "$issue_num" "$label"
    echo "[gh-issues] Updated #$issue_num → $label"
  else
    echo "[gh-issues] WARNING: Failed to add label '$label' to #$issue_num" >&2
    echo "[gh-issues]   Error: $add_error" >&2
    echo "[gh-issues]   Local state updated, but GitHub label not set" >&2
    # Still regenerate context with intended status (local state is source of truth)
    generate_context_file "$scope" "$issue_num" "$label"
    return 0  # Don't fail — local state is updated, GH sync is best-effort
  fi
}

do_retitle() {
  local scope="$1"
  local new_title="$2"
  validate_scope_name "$scope" || return 1

  if [[ -z "$new_title" ]]; then
    echo "ERROR: New title required" >&2
    return 1
  fi

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "ERROR: No gh_issue recorded for scope '$scope'" >&2
    return 1
  fi

  events_log "$scope" "SCOPE_RETITLE" "issue=$issue_num title=$new_title"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — retitle logged locally for $scope"
    return 0
  fi

  if ! run_gh gh issue edit "$issue_num" --repo "$REPO" --title "$new_title" >/dev/null; then
    return 1
  fi

  local status_label
  status_label=$(tracker_get_field "$scope" "status")
  generate_context_file "$scope" "$issue_num" "$status_label"
  echo "[gh-issues] Retitled #$issue_num → $new_title"
}

find_requirement_doc() {
  local scope="$1"
  python3 - "$scope" <<'PYEOF'
from pathlib import Path
import sys

scope = sys.argv[1]
root = Path(".agent_process/requirements_docs")
for path in sorted(root.rglob("*.md")):
    try:
        text = path.read_text()
    except Exception:
        continue
    if not text.startswith("---"):
        continue
    parts = text.split("---", 2)
    if len(parts) < 3:
        continue
    frontmatter = parts[1]
    for line in frontmatter.splitlines():
        if line.strip() == f"id: {scope}":
            print(path)
            sys.exit(0)
sys.exit(1)
PYEOF
}

do_resolve_input() {
  # Resolve flexible input to structured scope info.
  # Input can be: GitHub issue number (#123, 123, URL), scope name, or requirement path
  # Output: JSON with scope, requirement_path, gh_issue (any may be empty if not found)
  #
  # This enables plan-scope and review-iteration to accept any of these inputs.

  local input="$1"
  if [[ -z "$input" ]]; then
    echo '{"error":"No input provided"}' >&2
    return 1
  fi

  local scope="" req_path="" gh_issue="" input_type=""

  # --- Try to parse as issue number ---
  local parsed_issue=""
  if [[ "$input" =~ ^#?[0-9]+$ ]] || [[ "$input" =~ /issues/([0-9]+) ]]; then
    parsed_issue=$(parse_issue_number "$input" 2>/dev/null) || parsed_issue=""
  fi

  if [[ -n "$parsed_issue" ]]; then
    input_type="issue"
    gh_issue="$parsed_issue"

    # Look up issue title from GitHub (should be the scope name)
    if [[ "$GH_ENABLED" == "true" ]]; then
      local issue_data
      issue_data=$(gh issue view "$gh_issue" --repo "$REPO" --json title,state 2>/dev/null)
      if [[ -n "$issue_data" ]]; then
        scope=$(echo "$issue_data" | jq -r '.title // empty' 2>/dev/null)
      fi
    fi

    # If we got a scope, try to find the requirement doc
    if [[ -n "$scope" ]]; then
      req_path=$(find_requirement_doc "$scope" 2>/dev/null) || req_path=""
    fi

  # --- Try to parse as requirement path ---
  elif [[ "$input" == *.md ]] && [[ -f "$input" || -f ".agent_process/requirements_docs/$input" ]]; then
    input_type="requirement_path"

    # Normalize path
    if [[ -f "$input" ]]; then
      req_path="$input"
    else
      req_path=".agent_process/requirements_docs/$input"
    fi

    # Extract scope from frontmatter id:
    scope=$(python3 - "$req_path" <<'PYEOF'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
if text.startswith("---"):
    parts = text.split("---", 2)
    if len(parts) >= 3:
        for line in parts[1].splitlines():
            if line.strip().startswith("id:"):
                print(line.split(":", 1)[1].strip())
                sys.exit(0)
sys.exit(1)
PYEOF
) || scope=""

    # Check if scope has linked issue
    if [[ -n "$scope" ]]; then
      gh_issue=$(tracker_get_field "$scope" "gh_issue" 2>/dev/null) || gh_issue=""
    fi

  # --- Try to parse as scope name ---
  else
    input_type="scope"
    scope="$input"

    # Check tracker for linked issue
    gh_issue=$(tracker_get_field "$scope" "gh_issue" 2>/dev/null) || gh_issue=""

    # Try to find requirement doc
    req_path=$(find_requirement_doc "$scope" 2>/dev/null) || req_path=""
  fi

  # Get current iteration from tracker (if scope exists)
  local iteration=""
  if [[ -n "$scope" ]]; then
    iteration=$(tracker_get_field "$scope" "iteration" 2>/dev/null) || iteration=""
  fi

  # Output JSON
  python3 - "$scope" "$req_path" "$gh_issue" "$input_type" "$iteration" <<'PYEOF'
import json
import sys
print(json.dumps({
    "scope": sys.argv[1] or None,
    "requirement_path": sys.argv[2] or None,
    "gh_issue": sys.argv[3] or None,
    "input_type": sys.argv[4],
    "iteration": sys.argv[5] or None
}, indent=2))
PYEOF
}

render_issue_body() {
  local scope="$1"
  local req_path="$2"

  python3 - "$scope" "$req_path" <<'PYEOF'
from pathlib import Path
import sys

scope = sys.argv[1]
req_path = Path(sys.argv[2])
text = req_path.read_text()

frontmatter = {}
body = text
if text.startswith("---"):
    parts = text.split("---", 2)
    if len(parts) >= 3:
        fm = parts[1]
        body = parts[2]
        current_key = None
        current_list = None
        for raw_line in fm.splitlines():
            line = raw_line.rstrip()
            if not line.strip():
                continue
            if line.startswith("  - ") and current_key:
                frontmatter.setdefault(current_key, [])
                frontmatter[current_key].append(line[4:].strip())
                continue
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            if value == "":
                frontmatter[key] = []
                current_key = key
                continue
            current_key = key
            frontmatter[key] = value

lines = [line.rstrip() for line in body.splitlines()]
title = ""
sections = {}
current = None
for line in lines:
    if line.startswith("# "):
        title = line[2:].strip()
        continue
    if line.startswith("## "):
        current = line[3:].strip()
        sections[current] = []
        continue
    if current is not None:
        sections[current].append(line)

def clean_section(name):
    content = sections.get(name, [])
    while content and not content[0].strip():
        content.pop(0)
    while content and not content[-1].strip():
        content.pop()
    return "\n".join(content).strip()

objective = clean_section("Objective") or "_Not specified._"
background = clean_section("Background") or "_Not specified._"
technical = clean_section("Technical Requirements") or "_Not specified._"
success = clean_section("Success Criteria") or "_Not specified._"
out_of_scope = clean_section("Out of Scope") or "_Not specified._"

depends_on = frontmatter.get("depends_on", [])
if isinstance(depends_on, str):
    depends_on = [depends_on] if depends_on else []

status = frontmatter.get("status", "unknown")
priority = frontmatter.get("priority", "unknown")
complexity = frontmatter.get("complexity", "unknown")
category = frontmatter.get("category", "unknown")
split_from = frontmatter.get("split_from", "")
source = frontmatter.get("source", "")
work_plan = Path(f".agent_process/work/{scope}/iteration_plan.md")

parts = []
parts.append(f"## Scope Summary\n- Scope: `{scope}`\n- Category: `{category}`\n- Status: `{status}`\n- Priority: `{priority}`\n- Complexity: `{complexity}`")
if split_from:
    parts[-1] += f"\n- Split from: `{split_from}`"
if source:
    parts[-1] += f"\n- Source: `{source}`"

parts.append(f"## Objective\n{objective}")
parts.append(f"## Background\n{background}")
parts.append(f"## Acceptance Criteria\n{success}")
parts.append(f"## Technical Requirements\n{technical}")
if depends_on:
    parts.append("## Dependencies\n" + "\n".join(f"- `{item}`" for item in depends_on))
parts.append(f"## Out of Scope\n{out_of_scope}")
parts.append(f"## Requirement Source\n- `{req_path}`")
if work_plan.exists():
    parts[-1] += f"\n- `.agent_process/work/{scope}/iteration_plan.md`"

print("\n\n".join(parts).strip() + "\n")
PYEOF
}

do_sync_body() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "ERROR: No gh_issue recorded for scope '$scope'" >&2
    return 1
  fi

  local req_path
  if ! req_path=$(find_requirement_doc "$scope"); then
    echo "ERROR: Could not find requirement doc for scope '$scope'" >&2
    return 1
  fi

  local body_file
  body_file=$(mktemp)
  render_issue_body "$scope" "$req_path" > "$body_file"

  if [[ "$GH_ENABLED" != "true" ]]; then
    events_log "$scope" "COMMENT" "message=sync-body:local-only"
    rm -f "$body_file"
    echo "[gh-issues] GH disabled — body sync rendered locally for $scope"
    return 0
  fi

  if ! run_gh gh issue edit "$issue_num" --repo "$REPO" --body-file "$body_file" >/dev/null; then
    rm -f "$body_file"
    return 1
  fi

  rm -f "$body_file"
  events_log "$scope" "COMMENT" "message=sync-body:issue=$issue_num"
  local status_label
  status_label=$(tracker_get_field "$scope" "status")
  generate_context_file "$scope" "$issue_num" "$status_label"
  echo "[gh-issues] Synced body for #$issue_num ($scope)"
}

do_set_priority() {
  local scope="$1"
  local new_priority="$2"
  validate_scope_name "$scope" || return 1

  # Validate priority format
  if [[ ! "$new_priority" =~ ^priority:P[0-4]$ ]]; then
    echo "ERROR: Invalid priority '$new_priority'" >&2
    echo "  Valid values: priority:P0, priority:P1, priority:P2, priority:P3, priority:P4" >&2
    return 1
  fi

  if ! priority_labels_enabled; then
    echo "[gh-issues] Priority labels are disabled in config" >&2
    return 1
  fi

  events_log "$scope" "COMMENT" "message=priority-change:$new_priority"

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — priority change logged locally for $scope"
    return 0
  fi

  local issue_num
  issue_num=$(tracker_get_field "$scope" "gh_issue")
  if [[ -z "$issue_num" ]]; then
    echo "[gh-issues] WARNING: No gh_issue found for scope $scope" >&2
    return 0
  fi

  # Remove existing priority:P* labels, then add the new one
  local current_labels
  current_labels=$(run_gh gh issue view "$issue_num" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null) || current_labels=""

  # Check if already has the target priority — skip if no change needed
  if echo "$current_labels" | grep -q "^${new_priority}$"; then
    echo "[gh-issues] #$issue_num already has $new_priority — no change"
    return 0
  fi

  for old_priority in priority:P0 priority:P1 priority:P2 priority:P3 priority:P4; do
    if echo "$current_labels" | grep -q "^${old_priority}$"; then
      run_gh gh issue edit "$issue_num" --repo "$REPO" --remove-label "$old_priority" >/dev/null 2>&1 || true
    fi
  done

  # Add new priority label — report honestly
  local add_error
  if add_error=$(run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "$new_priority" 2>&1); then
    echo "[gh-issues] Updated #$issue_num → $new_priority"
  else
    echo "[gh-issues] WARNING: Failed to set priority '$new_priority' on #$issue_num" >&2
    echo "[gh-issues]   Error: $add_error" >&2
  fi
}

do_set_iteration() {
  local scope="$1"
  local iteration="$2"
  validate_scope_name "$scope" || return 1

  # Update local state (tracker, current_iteration.conf, events)
  scope_set_iteration "$scope" "$iteration" || return 1

  # GH: comment on the issue
  if [[ "$GH_ENABLED" == "true" ]]; then
    local issue_num
    issue_num=$(tracker_get_field "$scope" "gh_issue")
    if [[ -n "$issue_num" ]]; then
      local iter_error
      if ! iter_error=$(run_gh gh issue comment "$issue_num" --repo "$REPO" --body "Iteration updated: $iteration" 2>&1); then
        echo "[gh-issues] WARNING: Could not add iteration comment to #$issue_num: $iter_error" >&2
      fi
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

do_get_issue() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  # Returns the gh_issue number if linked, empty string if not.
  # Exit 0 in both cases — absence is not an error.
  tracker_get_field "$scope" "gh_issue"
}

do_search_issue() {
  local scope="$1"
  validate_scope_name "$scope" || return 1

  # Search GitHub for an existing issue matching this scope name.
  # Returns JSON with number and title if found, empty if not.
  # Does NOT create an issue or update tracker — that's for associate/start.

  if [[ "$GH_ENABLED" != "true" ]]; then
    # GH disabled — nothing to search
    return 0
  fi

  local issue_list
  issue_list=$(gh issue list --repo "$REPO" --label "ap:scope" --search "$scope in:title" --state open --json number,title --limit 5 2>/dev/null) || issue_list=""

  if [[ -z "$issue_list" || "$issue_list" == "[]" ]]; then
    return 0
  fi

  # Return matching issues as JSON (caller can parse with jq)
  echo "$issue_list"
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

  # Create child issue with rendered body
  local req_path=""
  req_path=$(find_requirement_doc "$scope" 2>/dev/null) || req_path=""

  local body
  body=$(render_issue_body "$desc" "$parent_num" "$scope" "work unit of" "$req_path")

  local child_output child_num
  child_output=$(run_gh gh issue create --repo "$REPO" \
    --title "$wu_id: $desc" \
    --body "$body" \
    --label "ap:scope") || return 1

  child_num=$(echo "$child_output" | grep -o '[0-9]*$')

  # Link as sub-issue via API
  # Note: The API requires the issue ID (large integer), not the issue number
  if [[ -n "$child_num" ]]; then
    local child_id link_error
    child_id=$(run_gh gh api "repos/$OWNER/$REPONAME/issues/$child_num" --jq '.id' 2>/dev/null)
    if [[ -n "$child_id" ]]; then
      if ! link_error=$(run_gh gh api "repos/$OWNER/$REPONAME/issues/$parent_num/sub_issues" -F sub_issue_id="$child_id" 2>&1); then
        echo "[gh-issues] WARNING: Could not link #$child_num as sub-issue of #$parent_num: $link_error" >&2
      fi
    fi
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

  local task_error
  case "$status" in
    complete)
      if task_error=$(run_gh gh issue close "$wu_issue_num" --repo "$REPO" 2>&1); then
        echo "[gh-issues] Closed sub-issue #$wu_issue_num ($wu_id)"
      else
        echo "[gh-issues] WARNING: Could not close #$wu_issue_num ($wu_id): $task_error" >&2
      fi
      ;;
    blocked)
      if task_error=$(run_gh gh issue edit "$wu_issue_num" --repo "$REPO" --add-label "status:blocked" 2>&1); then
        echo "[gh-issues] Labeled #$wu_issue_num ($wu_id) as status:blocked"
      else
        echo "[gh-issues] WARNING: Could not add blocked label to #$wu_issue_num ($wu_id): $task_error" >&2
      fi
      ;;
    *)
      if task_error=$(run_gh gh issue edit "$wu_issue_num" --repo "$REPO" --add-label "status:$status" 2>&1); then
        echo "[gh-issues] Updated #$wu_issue_num ($wu_id) → $status"
      else
        echo "[gh-issues] WARNING: Could not update #$wu_issue_num ($wu_id) → $status: $task_error" >&2
      fi
      ;;
  esac
}

do_close() {
  local scope="$1"
  local decision="${2:-approved}"
  validate_scope_name "$scope" || return 1

  # Update local state (tracker + events)
  scope_close "$scope" "$decision"

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

  # Add decision label and close — report honestly
  local label_error close_error
  local label_ok=true close_ok=true

  if ! label_error=$(run_gh gh issue edit "$issue_num" --repo "$REPO" --add-label "status:$decision" 2>&1); then
    label_ok=false
  fi

  if ! close_error=$(run_gh gh issue close "$issue_num" --repo "$REPO" 2>&1); then
    close_ok=false
  fi

  if [[ "$label_ok" == "true" && "$close_ok" == "true" ]]; then
    echo "[gh-issues] Closed issue #$issue_num ($scope) — $decision"
  else
    [[ "$label_ok" == "false" ]] && echo "[gh-issues] WARNING: Failed to add label 'status:$decision' to #$issue_num: $label_error" >&2
    [[ "$close_ok" == "false" ]] && echo "[gh-issues] WARNING: Failed to close #$issue_num: $close_error" >&2
    echo "[gh-issues] Local state updated for $scope, but GitHub sync incomplete" >&2
  fi
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

  local comment_error
  if comment_error=$(run_gh gh issue comment "$issue_num" --repo "$REPO" --body "$message" 2>&1); then
    echo "[gh-issues] Comment added to #$issue_num"
  else
    echo "[gh-issues] WARNING: Failed to add comment to #$issue_num" >&2
    echo "[gh-issues]   Error: $comment_error" >&2
  fi
}

do_list_issues() {
  # List all open ap:scope issues from GitHub as JSON.
  # Output: JSON array of {number, title, state, labels}
  # Used by audit to compare against local tracker.

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[]"
    return 0
  fi

  local issues
  issues=$(gh issue list --repo "$REPO" --label "ap:scope" --state all --json number,title,state,labels --limit 200 2>/dev/null) || issues="[]"
  echo "$issues"
}

do_audit() {
  # Compare local tracker against GitHub issues.
  # Reports mismatches in a structured format for Claude to parse and act on.
  #
  # Output format (one JSON object per line):
  #   {"type":"ORPHAN_TRACKER","scope":"foo","gh_issue":"123","reason":"Issue not found on GitHub"}
  #   {"type":"TITLE_MISMATCH","scope":"bar","gh_issue":"456","gh_title":"old_name","reason":"GitHub title differs from scope name"}
  #   {"type":"ORPHAN_GH","gh_issue":"789","gh_title":"baz","reason":"No tracker entry for this issue"}
  #   {"type":"UNLINKED","scope":"qux","gh_issue":"101","gh_title":"qux","reason":"Matching issue exists but not linked in tracker"}

  echo "## GitHub Issues Audit"
  echo ""

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "GitHub integration disabled — nothing to audit."
    return 0
  fi

  # Fetch all ap:scope issues from GitHub
  local gh_issues
  gh_issues=$(do_list_issues)
  if [[ -z "$gh_issues" || "$gh_issues" == "[]" ]]; then
    echo "No ap:scope issues found on GitHub."
    echo ""
  fi

  local mismatch_count=0

  echo "### Mismatches Found"
  echo ""

  # Check each tracker entry with gh_issue against GitHub
  if [[ -f "$TRACKER_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue

      local scope gh_issue status
      scope=$(echo "$line" | jq -r '.scope // empty' 2>/dev/null)
      gh_issue=$(echo "$line" | jq -r '.gh_issue // empty' 2>/dev/null)
      status=$(echo "$line" | jq -r '.status // empty' 2>/dev/null)

      [[ -z "$scope" ]] && continue
      [[ -z "$gh_issue" ]] && continue
      # Skip closed/split scopes
      [[ "$status" == "closed" || "$status" == "split" ]] && continue

      # Check if this issue exists on GitHub
      local gh_entry gh_title gh_state
      gh_entry=$(echo "$gh_issues" | jq -r --arg n "$gh_issue" '.[] | select(.number == ($n | tonumber))' 2>/dev/null)

      if [[ -z "$gh_entry" ]]; then
        echo "{\"type\":\"ORPHAN_TRACKER\",\"scope\":\"$scope\",\"gh_issue\":\"$gh_issue\",\"reason\":\"Issue #$gh_issue not found on GitHub\"}"
        mismatch_count=$((mismatch_count + 1))
        continue
      fi

      gh_title=$(echo "$gh_entry" | jq -r '.title // empty' 2>/dev/null)
      gh_state=$(echo "$gh_entry" | jq -r '.state // empty' 2>/dev/null)

      # Check title mismatch (allow prefix match for split children like "scope-01")
      if [[ "$gh_title" != "$scope" && ! "$gh_title" =~ ^"$scope" ]]; then
        echo "{\"type\":\"TITLE_MISMATCH\",\"scope\":\"$scope\",\"gh_issue\":\"$gh_issue\",\"gh_title\":\"$gh_title\",\"gh_state\":\"$gh_state\",\"reason\":\"GitHub title '$gh_title' differs from scope name '$scope'\"}"
        mismatch_count=$((mismatch_count + 1))
      fi

    done < "$TRACKER_FILE"
  fi

  # Check for GitHub issues not in tracker (orphan GH issues)
  if [[ -n "$gh_issues" && "$gh_issues" != "[]" ]]; then
    local issue_numbers
    issue_numbers=$(echo "$gh_issues" | jq -r '.[].number' 2>/dev/null)

    for issue_num in $issue_numbers; do
      local gh_entry gh_title gh_state
      gh_entry=$(echo "$gh_issues" | jq -r --arg n "$issue_num" '.[] | select(.number == ($n | tonumber))' 2>/dev/null)
      gh_title=$(echo "$gh_entry" | jq -r '.title // empty' 2>/dev/null)
      gh_state=$(echo "$gh_entry" | jq -r '.state // empty' 2>/dev/null)

      # Skip closed issues for orphan check
      [[ "$gh_state" == "CLOSED" ]] && continue

      # Check if any tracker entry references this issue
      local tracker_has_issue=false
      if [[ -f "$TRACKER_FILE" ]]; then
        if grep -q "\"gh_issue\":\"$issue_num\"" "$TRACKER_FILE" 2>/dev/null; then
          tracker_has_issue=true
        fi
      fi

      if [[ "$tracker_has_issue" == "false" ]]; then
        # Check if there's an unlinked tracker entry with matching scope name
        local matching_scope
        matching_scope=$(tracker_read_scope "$gh_title")

        if [[ -n "$matching_scope" ]]; then
          local existing_gh_issue
          existing_gh_issue=$(echo "$matching_scope" | jq -r '.gh_issue // empty' 2>/dev/null)
          if [[ -z "$existing_gh_issue" ]]; then
            echo "{\"type\":\"UNLINKED\",\"scope\":\"$gh_title\",\"gh_issue\":\"$issue_num\",\"gh_title\":\"$gh_title\",\"reason\":\"Tracker entry exists but not linked to issue #$issue_num\"}"
            mismatch_count=$((mismatch_count + 1))
          fi
        else
          echo "{\"type\":\"ORPHAN_GH\",\"gh_issue\":\"$issue_num\",\"gh_title\":\"$gh_title\",\"gh_state\":\"$gh_state\",\"reason\":\"No tracker entry for issue #$issue_num\"}"
          mismatch_count=$((mismatch_count + 1))
        fi
      fi
    done
  fi

  echo ""
  if [[ $mismatch_count -eq 0 ]]; then
    echo "✓ No mismatches found — tracker and GitHub are in sync."
  else
    echo "Found $mismatch_count mismatch(es)."
    echo ""
    echo "### Suggested Fixes"
    echo ""
    echo "For ORPHAN_TRACKER: Remove gh_issue from tracker or recreate the GitHub issue"
    echo "For TITLE_MISMATCH: Run 'lifecycle.sh retitle <scope> <correct_title>' or update tracker"
    echo "For ORPHAN_GH: Run 'lifecycle.sh associate <scope> <issue_number>' to link"
    echo "For UNLINKED: Run 'lifecycle.sh associate <scope> <issue_number>' to link"
  fi
}

do_split() {
  local parent_scope="$1"
  shift
  local child_args=("$@")

  validate_scope_name "$parent_scope" || return 1

  if [[ ${#child_args[@]} -lt 2 ]]; then
    echo "ERROR: split requires at least 2 child scopes" >&2
    return 1
  fi

  # Parse child arguments: "scope|description" or just "scope"
  # If no pipe, description defaults to a reference to parent
  local child_scopes=()
  local child_descriptions=()

  for arg in "${child_args[@]}"; do
    local scope_part desc_part
    if [[ "$arg" == *"|"* ]]; then
      scope_part="${arg%%|*}"
      desc_part="${arg#*|}"
    else
      scope_part="$arg"
      desc_part=""  # Will be filled with default later
    fi
    child_scopes+=("$scope_part")
    child_descriptions+=("$desc_part")
  done

  for child in "${child_scopes[@]}"; do
    validate_scope_name "$child" || return 1
  done

  local ts
  ts=$(_timestamp)

  # Update parent tracker: mark as split with child references
  local parent_current
  parent_current=$(tracker_read_scope "$parent_scope")
  if [[ -z "$parent_current" ]]; then
    echo "ERROR: Parent scope '$parent_scope' not found in tracker" >&2
    return 1
  fi

  local children_json
  children_json=$(printf '%s\n' "${child_scopes[@]}" | jq -R . | jq -sc .)

  if command -v jq &>/dev/null; then
    tracker_write_scope "$parent_scope" "$(echo "$parent_current" | jq -c \
      --arg st "split" \
      --argjson children "$children_json" \
      '. + {status: $st, split_into: $children}')"
  fi

  events_log "$parent_scope" "SCOPE_SPLIT" "children=${child_scopes[*]}"

  # Create tracker entries for each child (minimal — they get fully initialized at plan time)
  for child in "${child_scopes[@]}"; do
    local existing
    existing=$(tracker_read_scope "$child")
    if [[ -z "$existing" ]]; then
      if command -v jq &>/dev/null; then
        tracker_write_scope "$child" "$(jq -n -c \
          --arg s "$child" \
          --arg t "$ts" \
          --arg p "$parent_scope" \
          '{scope: $s, status: "pending", created: $t, iteration: "iteration_01", split_from: $p}')"
      else
        tracker_write_scope "$child" "{\"scope\":\"$child\",\"status\":\"pending\",\"created\":\"$ts\",\"iteration\":\"iteration_01\",\"split_from\":\"$parent_scope\"}"
      fi
    fi
  done

  if [[ "$GH_ENABLED" != "true" ]]; then
    echo "[gh-issues] GH disabled — split recorded locally: $parent_scope → ${child_scopes[*]}"
    return 0
  fi

  ensure_labels

  local parent_issue
  parent_issue=$(tracker_get_field "$parent_scope" "gh_issue")

  # Get parent's priority label to inherit to children
  local parent_priority=""
  if priority_labels_enabled && [[ -n "$parent_issue" ]]; then
    local parent_labels
    parent_labels=$(run_gh gh issue view "$parent_issue" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null) || parent_labels=""
    parent_priority=$(echo "$parent_labels" | grep "^priority:P[0-4]$" | head -1)
  fi

  # Look up parent's requirement doc for reference in child issues
  local parent_req_path=""
  parent_req_path=$(find_requirement_doc "$parent_scope" 2>/dev/null) || parent_req_path=""

  # Create child issues with reference to parent
  local created_children=()
  local i
  for i in "${!child_scopes[@]}"; do
    local child="${child_scopes[$i]}"
    local desc="${child_descriptions[$i]}"

    # Default description if not provided
    if [[ -z "$desc" ]]; then
      desc="Split from parent scope: ${parent_scope}"
    fi

    local body
    body=$(render_issue_body "$desc" "${parent_issue:-}" "$parent_scope" "split from" "$parent_req_path")

    local child_output child_num

    if child_output=$(run_gh gh issue create --repo "$REPO" \
      --title "$child" \
      --body "$body" \
      --label "ap:scope"); then
      child_num=$(echo "$child_output" | grep -o '[0-9]*$')
      created_children+=("#$child_num")

      # Update child tracker with gh_issue
      local child_current
      child_current=$(tracker_read_scope "$child")
      if [[ -n "$child_current" ]] && command -v jq &>/dev/null; then
        tracker_write_scope "$child" "$(echo "$child_current" | jq -c --arg n "$child_num" '. + {gh_issue: $n}')"
      fi

      # Inherit parent's priority label
      if [[ -n "$parent_priority" ]]; then
        local inherit_error
        if ! inherit_error=$(run_gh gh issue edit "$child_num" --repo "$REPO" --add-label "$parent_priority" 2>&1); then
          echo "[gh-issues] WARNING: Could not inherit priority '$parent_priority' to #$child_num: $inherit_error" >&2
        fi
      fi

      # Link as sub-issue via API (creates parent-child relationship in GitHub UI)
      # Note: The API requires the issue ID (large integer), not the issue number
      if [[ -n "$parent_issue" ]]; then
        local child_id
        child_id=$(run_gh gh api "repos/$OWNER/$REPONAME/issues/$child_num" --jq '.id' 2>/dev/null)
        if [[ -n "$child_id" ]]; then
          run_gh gh api "repos/$OWNER/$REPONAME/issues/$parent_issue/sub_issues" \
            -F sub_issue_id="$child_id" >/dev/null 2>&1 || \
            echo "[gh-issues] WARNING: Could not link #$child_num as sub-issue of #$parent_issue" >&2
        fi
      fi

      echo "[gh-issues] Created child issue #$child_num for $child"
    else
      echo "[gh-issues] WARNING: Failed to create issue for child $child" >&2
    fi
  done

  # Close parent issue with status:split and summary comment
  if [[ -n "$parent_issue" ]]; then
    local split_comment="Scope split into smaller pieces:

${created_children[*]}

This issue is now closed. Track progress on the child issues above."

    local split_error
    if ! split_error=$(run_gh gh issue comment "$parent_issue" --repo "$REPO" --body "$split_comment" 2>&1); then
      echo "[gh-issues] WARNING: Could not add split comment to #$parent_issue: $split_error" >&2
    fi

    # Remove all other status:* labels — split parent has no progression status (best effort)
    local parent_labels
    parent_labels=$(run_gh gh issue view "$parent_issue" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null) || parent_labels=""
    for old_label in status:planning status:executing status:reviewing status:iterate status:blocked; do
      if echo "$parent_labels" | grep -q "^${old_label}$"; then
        run_gh gh issue edit "$parent_issue" --repo "$REPO" --remove-label "$old_label" >/dev/null 2>&1 || true
      fi
    done

    # Only add status:split if not already present
    local label_ok=true close_ok=true
    if ! echo "$parent_labels" | grep -q "^status:split$"; then
      if ! split_error=$(run_gh gh issue edit "$parent_issue" --repo "$REPO" --add-label "status:split" 2>&1); then
        echo "[gh-issues] WARNING: Could not add status:split label to #$parent_issue: $split_error" >&2
        label_ok=false
      fi
    fi

    if ! split_error=$(run_gh gh issue close "$parent_issue" --repo "$REPO" 2>&1); then
      echo "[gh-issues] WARNING: Could not close parent issue #$parent_issue: $split_error" >&2
      close_ok=false
    fi

    if [[ "$label_ok" == "true" && "$close_ok" == "true" ]]; then
      echo "[gh-issues] Closed parent issue #$parent_issue with status:split"
    else
      echo "[gh-issues] Parent issue #$parent_issue: some operations failed (see warnings above)" >&2
    fi
  fi

  echo "[gh-issues] Split complete: $parent_scope → ${child_scopes[*]}"
}

# --- Route actions ---

case "$ACTION" in
  health-check)
    do_health_check
    ;;
  create-labels)
    do_create_labels
    ;;
  create)
    SCOPE="${2:-}"
    DESC="${3:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh create <scope> [description]" >&2; exit 1; }
    do_create "$SCOPE" "$DESC"
    ;;
  start)
    SCOPE="${2:-}"
    DESC="${3:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh start <scope> [description]" >&2; exit 1; }
    do_start "$SCOPE" "$DESC"
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
    [[ -z "$SCOPE" || -z "$LABEL" ]] && { echo "Usage: github-issues-lifecycle.sh set-status <scope> <status>" >&2; exit 1; }
    do_set_status "$SCOPE" "$LABEL"
    ;;
  retitle)
    SCOPE="${2:-}"
    NEW_TITLE="${3:-}"
    [[ -z "$SCOPE" || -z "$NEW_TITLE" ]] && { echo "Usage: github-issues-lifecycle.sh retitle <scope> <new_title>" >&2; exit 1; }
    do_retitle "$SCOPE" "$NEW_TITLE"
    ;;
  sync-body)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh sync-body <scope>" >&2; exit 1; }
    do_sync_body "$SCOPE"
    ;;
  set-priority)
    SCOPE="${2:-}"
    PRIORITY="${3:-}"
    [[ -z "$SCOPE" || -z "$PRIORITY" ]] && { echo "Usage: github-issues-lifecycle.sh set-priority <scope> <priority:P0-P4>" >&2; exit 1; }
    do_set_priority "$SCOPE" "$PRIORITY"
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
  get-issue)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh get-issue <scope>" >&2; exit 1; }
    do_get_issue "$SCOPE"
    ;;
  search-issue)
    SCOPE="${2:-}"
    [[ -z "$SCOPE" ]] && { echo "Usage: github-issues-lifecycle.sh search-issue <scope>" >&2; exit 1; }
    do_search_issue "$SCOPE"
    ;;
  list-issues)
    do_list_issues
    ;;
  audit)
    do_audit
    ;;
  resolve-input)
    INPUT="${2:-}"
    [[ -z "$INPUT" ]] && { echo "Usage: github-issues-lifecycle.sh resolve-input <issue#|scope|requirement_path>" >&2; exit 1; }
    do_resolve_input "$INPUT"
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
  split)
    PARENT_SCOPE="${2:-}"
    shift 2 2>/dev/null || shift $#
    CHILD_ARGS=("$@")
    [[ -z "$PARENT_SCOPE" || ${#CHILD_ARGS[@]} -lt 2 ]] && { echo "Usage: github-issues-lifecycle.sh split <parent_scope> \"child1|description\" \"child2|description\" [...]" >&2; exit 1; }
    do_split "$PARENT_SCOPE" "${CHILD_ARGS[@]}"
    ;;
  *)
    echo "ERROR: Unknown action '$ACTION'" >&2
    echo "Valid actions: health-check, create-labels, start, associate, set-status, retitle, sync-body, set-priority, set-iteration, get-iteration, get-issue, search-issue, list-issues, audit, resolve-input, task-create, task-update, close, verify, comment, split" >&2
    exit 1
    ;;
esac

exit $?
