# PR Shepherd

**Type:** How-To Guide (Diátaxis)
**Purpose:** Monitor a PR through CI and review until it's merge-ready

---

## Overview

The PR shepherd is an optional post-PR agent that monitors CI pipeline status, responds to reviewer comments, fixes lint/type issues, and reports merge-readiness. It extends the workflow from "PR created" to "PR ready to merge."

**Activation:** Pass `--shepherd` to `/ap_release`, or request PR monitoring when creating a release.

**Philosophy:** The shepherd is a CI babysitter with commenting privileges — not an autonomous decision-maker. It reports readiness; the human clicks merge.

---

## When to Use

| Situation | Use Shepherd? | Why |
|-----------|--------------|-----|
| Simple PR, fast CI, single reviewer | No | Overhead exceeds benefit |
| Multi-file PR with lint/type CI checks | Yes | Auto-fixes save round-trips |
| PR needs to sit open for review | Yes | Monitors and responds while you move on |
| Hotfix that must merge ASAP | Yes | Actively watches for blockers |
| Draft PR / WIP | No | Not ready for monitoring |

---

## How It Works

### Activation

```bash
# During release
/ap_release pr --shepherd
/ap_release release minor --shepherd

# The shepherd launches automatically after the PR is created
```

### What the Shepherd Does

#### 1. Monitor CI Pipeline

The shepherd checks CI status using `gh pr checks`:

- **All passing** → Reports merge-ready
- **Lint/formatting failure** → Fixes with a new commit on the branch
- **Type errors** → Fixes with a new commit on the branch
- **Test failures** → Diagnoses; fixes if within scope files, reports if not
- **Build failures** → Reports to user with specific failure context

#### 2. Respond to Review Comments

The shepherd reads review comments via `gh pr view --comments`:

- **Questions about implementation** → Drafts responses explaining choices
- **Change requests within scope** → Implements the change, commits to branch
- **Out-of-scope requests** → Notes them for the user with explanation

#### 3. Report Merge-Readiness

When all conditions are met, the shepherd produces a status report:

```markdown
## PR Shepherd Report

**PR:** https://github.com/org/repo/pull/123
**Status:** 🟢 MERGE-READY | 🟡 IN PROGRESS | 🔴 BLOCKED

**CI Checks:** all passing / N failing
**Review Status:** approved / changes requested / no reviews
**Unresolved Threads:** 0 / N

**Actions Taken:**
- Fixed ESLint warning in profile.tsx (commit abc123)
- Responded to question about error handling approach

**Blockers (if any):**
- Waiting for review from @teammate
```

---

## Boundaries

The shepherd has strict operating limits:

| Allowed | Not Allowed |
|---------|-------------|
| Modify files already changed in the PR | Create new files (without user approval) |
| Push fix commits to the PR branch | Force-push or rebase |
| Respond to review comments | Merge the PR |
| Diagnose CI failures | Dismiss reviews |
| Report status | Make scope decisions |

**Escalation rule:** If the shepherd fails to fix the same issue after 3 attempts, it stops and reports to the user. No infinite fix loops.

**Scope constraint:** The shepherd only touches files already in the PR's diff. This prevents the common failure mode where an agent "fixes" an unrelated lint warning and introduces a regression in code it doesn't understand.

---

## Session Recovery

If the session ends while the shepherd is active, it can be relaunched manually:

```bash
# Check current PR status
gh pr checks <PR_NUMBER>
gh pr view <PR_NUMBER> --comments

# Re-read the shepherd step in ap_release.md and re-launch
```

The shepherd is stateless — it reads the PR's current state from GitHub each time. No local state file needed.

---

## Integration Points

| Component | How it interacts with the shepherd |
|-----------|------------------------------------|
| `/ap_release` Step 9.5 | Launches the shepherd after PR creation |
| `gh` CLI | Primary interface for PR status and comments |
| Scope branch | All shepherd commits go to the PR branch |
| CI pipeline | Shepherd reads check results, fixes failures |
| Human reviewer | Shepherd responds to comments, human merges |

---

## Troubleshooting

**Q: The shepherd keeps failing on the same lint issue.**
A: After 3 attempts, it stops and reports. The issue likely requires understanding outside the PR's changed files. Fix it manually.

**Q: A reviewer requested changes outside the PR scope.**
A: The shepherd flags these as "out of scope" and doesn't act. Add them to the backlog or address in a follow-up scope.

**Q: CI passes but reviewer hasn't approved yet.**
A: The shepherd reports 🟡 IN PROGRESS with "Waiting for review" as the blocker. It doesn't nag reviewers.

**Q: The shepherd made a fix I don't agree with.**
A: Revert the commit on the branch. The shepherd pushes normal commits — they're easy to revert. Consider this feedback for the PR shepherd's prompt tuning.

**Q: Can the shepherd handle multiple PRs?**
A: One shepherd per PR. If you have multiple PRs, launch `/ap_release --shepherd` for each.

---

## Relationship to Other Components

The shepherd is downstream of everything else in the agent process:

```
Plan → Execute → Review → APPROVE → /ap_release → PR Created → Shepherd
                                                                    │
                                                          ┌─────────┴──────────┐
                                                          │ Monitor CI         │
                                                          │ Respond to reviews │
                                                          │ Fix lint/types     │
                                                          │ Report readiness   │
                                                          └─────────┬──────────┘
                                                                    │
                                                              Human merges
```

The orchestrator never interacts with the shepherd. The shepherd runs after the orchestrator's APPROVE decision and operates entirely in the PR/CI domain.
