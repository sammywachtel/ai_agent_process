# GitHub Issues Handling

> **Purpose:** Single-concern instruction file for sub-agents performing GitHub Issues operations.
> Every orchestration coordinator references this file instead of embedding GH logic inline.

---

## 1. Check If GH Is Enabled

Read `.agent_process/quality-config.json`:

```json
{ "github_issues": { "enabled": true, "repo": "owner/repo" } }
```

- If `github_issues.enabled` is `false`, missing, or the file doesn't exist: **do nothing and return**. No warnings, no errors — GH is simply not part of this project.
- If `enabled` is `true` but `repo` is empty: log a warning and return.

## 2. The Lifecycle Script

**All GH operations go through `github-issues-lifecycle.sh`.** Never run `gh` directly.

```bash
# Core actions
bash .agent_process/scripts/github-issues-lifecycle.sh start <scope>
bash .agent_process/scripts/github-issues-lifecycle.sh associate <scope> <issue_number_or_url>
bash .agent_process/scripts/github-issues-lifecycle.sh set-status <scope> <label>
bash .agent_process/scripts/github-issues-lifecycle.sh set-priority <scope> <priority:P0-P4>
bash .agent_process/scripts/github-issues-lifecycle.sh set-iteration <scope> <iteration>
bash .agent_process/scripts/github-issues-lifecycle.sh comment <scope> "message"
bash .agent_process/scripts/github-issues-lifecycle.sh close <scope> <decision>
bash .agent_process/scripts/github-issues-lifecycle.sh verify <scope>

# Scope splitting (when scope fails size gate)
bash .agent_process/scripts/github-issues-lifecycle.sh split <parent_scope> <child1> <child2> [child3...]

# Work unit management
bash .agent_process/scripts/github-issues-lifecycle.sh task-create <scope> <wu-id> <description>
bash .agent_process/scripts/github-issues-lifecycle.sh task-update <scope> <wu-id> <status>
```

The script handles `--repo`, retries, label management, and tracker updates internally. You don't need to worry about any of that.

## 3. Status Label Taxonomy

| Pipeline Step | Label | Notes |
|--------------|-------|-------|
| Brainstorm/Requirements | *(no status label)* | Issue created, not yet planned |
| Plan scope | `status:planning` | Planning coordinator active |
| Execute preflight | `status:executing` | Implementation underway |
| Review | `status:reviewing` | Orchestrator review active |
| APPROVE decision | `status:approved` | Issue closed |
| ITERATE decision | `status:iterate` | Needs another pass |
| BLOCK decision | `status:blocked` | Issue closed |
| Scope split | `status:split` | Parent issue closed, child issues created |

Use `set-status` to transition between labels. The script removes old `status:*` labels before applying the new one.

## 3.1. Priority Labels

Priority labels help triage scope urgency. When enabled, `start` applies a default priority and `split` inherits the parent's priority to children.

| Priority | Color | Meaning |
|----------|-------|---------|
| `priority:P0` | Red (#B60205) | Critical — drop everything |
| `priority:P1` | Orange (#D93F0B) | High — this sprint |
| `priority:P2` | Yellow (#FBCA04) | Medium — default priority |
| `priority:P3` | Green (#0E8A16) | Low — when time permits |
| `priority:P4` | Blue (#C5DEF5) | Minimal — nice to have |

**Configuration:**
```json
{
  "priority_labels": {
    "enabled": true,
    "default": "priority:P2"
  }
}
```

**Behavior:**
- **`start`**: Applies default priority (P2 unless configured otherwise)
- **`set-priority`**: Changes priority with mutual exclusivity (removes old, adds new)
- **`split`**: Children inherit parent's priority automatically
- **`create-labels`**: Creates priority labels if enabled

Use `set-priority` to change priority:
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-priority my_scope priority:P1
```

## 4. Create / Adopt / Verify Decision Tree

When a pipeline step needs a GH issue for a scope:

```
1. Read scope-tracker.jsonl for this scope's gh_issue field
   │
   ├─ gh_issue EXISTS
   │  └─ Run: lifecycle.sh start <scope>
   │     (start will verify the issue, adopt it, regenerate context file)
   │
   └─ gh_issue DOES NOT EXIST
      │
      ├─ User provided an issue number (#N)?
      │  └─ Run: lifecycle.sh associate <scope> <N>
      │
      ├─ Pipeline step should auto-create? (plan-scope: yes, execute-preflight: no)
      │  └─ Run: lifecycle.sh start <scope>
      │     (start will search-then-create)
      │
      └─ Pipeline step should ask user? (execute-preflight: yes)
         └─ Ask: "No GitHub Issue found for scope '{scope}'.
            Enter issue number/link, say 'create', or 'skip'."
```

**Key rule:** `scope-tracker.jsonl`'s `gh_issue` field is the single source of truth. Whoever sets it first wins. Subsequent steps adopt it.

## 4.1. Split Handling (Scope Size Gate Failure)

When a scope fails the hard size gate during planning (too many criteria, files, or subsystems):

```
1. Scope-check coordinator returns FAIL with recommended breakdown
   │
2. Planning coordinator calls: lifecycle.sh split <parent> <child1> <child2> ...
   │
   ├─ Tracker updates:
   │  ├─ Parent scope: status="split", split_into=[child1, child2, ...]
   │  └─ Each child: status="pending", split_from=parent
   │
   └─ GH operations (if enabled):
      ├─ Create child issues with body: "Split from #N (parent_scope)"
      ├─ Comment on parent: "Scope split into smaller pieces: #A, #B, #C"
      ├─ Add status:split label to parent
      └─ Close parent issue
```

**Key rules:**
- Child scopes are **independent** — they can be planned/executed in any order
- Parent issue is **closed** — all future work happens on child issues
- Child tracker entries have `split_from` field linking back to parent
- Child issues are regular `ap:scope` issues (no special `ap:child` label needed)

## 5. Context File

The lifecycle script generates `.agent_process/work/{scope}/.run/gh-issue-context.md` at `start` and `associate` time. This file contains:

- Issue number and repo
- Current status label
- Scope and iteration
- Pre-filled commands for common operations

**Sub-agents receive this file instead of the full issue body.** It's tiny (~15 lines) and contains everything needed to interact with the issue.

## 6. Prohibitions

These rules exist because past violations caused duplicate issues, context bloat, and broken state:

- **Never edit issue body directly** — use the lifecycle script
- **Never load full issue body into agent context** — use the issue number as a pointer, or read `.run/gh-issue-context.md`
- **Never run `gh` without going through the lifecycle script** — the script handles `--repo`, retries, and tracker sync
- **Never create duplicate issues** — always check `scope-tracker.jsonl` first via `start` (which checks tracker before creating)
- **Never skip the lifecycle script for "simple" operations** — even a comment should go through `lifecycle.sh comment`

## 7. Error Handling

The lifecycle script follows the HALT protocol:

- **Transient errors** (502, 503, timeout, rate limit): retried once automatically
- **Permanent errors** (401, 404, validation): prints `HALT:` message and returns non-zero
- **GH disabled**: all actions return 0 silently (local state still written)

When a HALT occurs:
1. Local state (`scope-tracker.jsonl`, `scope-events.log`) is still written
2. The calling coordinator should stop GH operations but may continue with non-GH work
3. Report the error to the user — don't swallow it

## 8. Sub-Agent Pattern

Parent coordinators spawn a **cheap** sub-agent for GH operations:

```markdown
Spawn a cheap sub-agent:
  - Input: process/github-issues-handling.md + .run/gh-issue-context.md (if exists)
  - Task: "Verify GH issue for scope {scope}. Update status to {label}."
  - Output: Updated .run/gh-issue-context.md
```

The parent coordinator does NOT read issues, run `gh`, or process labels. Simple single-command status updates (one bash call already in the orchestration) are acceptable inline — the sub-agent pattern is for anything involving decisions or multiple commands.
