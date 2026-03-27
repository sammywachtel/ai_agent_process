# Step 01: Gather Context

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** context mode (scope/noscope), scope name, iteration name
**Output:** `.run/release/01-context.md`

---

## Your Task

Gather the information needed for changelog and release. Two modes:

### Scope Mode (default)

```bash
cat .agent_process/work/current_iteration.conf
```

Read:
- `.agent_process/work/{scope}/{iteration}/results.md` — what was implemented
- `.agent_process/work/{scope}/iteration_plan.md` — scope context

Extract: summary, files changed, change type (feature/fix/breaking), user-facing changes.

### No-Scope Mode (noscope arg)

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git diff --stat ${DEFAULT_BRANCH}...HEAD
git status --short
```

Read key changed files to understand the work. Summarize findings.

### Build Number (both modes)

```bash
LAST_BUILD=$(git tag -l "build/*" | sed 's|build/||' | sort -n | tail -1)
BUILD_NUM=$(( ${LAST_BUILD:-0} + 1 ))
echo "Build number: ${BUILD_NUM}"
```

## Output Format

Write to `.run/release/01-context.md`:

```markdown
# Release Context

**Mode:** scope / noscope
**Scope:** {name or "none"}
**Iteration:** {name or "none"}
**Build number:** {N}

## Changes Summary
- {bullet points describing what changed}

**Change type:** feature / fix / refactor / docs / chore
**User-facing:** YES / NO
```
