# Steps 07-10: Post-Decision Actions

**Model tier:** capable
**Tools needed:** Read, Write, Bash
**Input:** scope, iteration, decision output (`.run/review/06-decision.md`)
**Output:** `.run/review/07-10-post-decision.md`

---

## Your Task

Execute the appropriate post-decision actions based on the decision in `.run/review/06-decision.md`. **Wait for human approval before executing destructive actions** (folder creation, status updates, scope changes).

Read the decision first, then follow the matching section below.

---

## If APPROVE

1. **Update iteration_plan.md:** Set latest iteration, decision = APPROVE, date
2. **Update requirement doc:** Change frontmatter `status:` to `approved`, update body text
3. **Deposit knowledge (Step 9.5):**
   - Check `quality-config.json` → `knowledge_base.deposit_on_approve`
   - If enabled, extract 0-3 learnings → append to `$KB_DIR/*.jsonl`
   - Use metaswarm-compatible schema: `id`, `type`, `fact`, `recommendation`, `confidence`, `provenance`, `tags`, `affectedFiles`
   - Knowledge dir: `.agent_process/knowledge/`
4. **Suggest release workflow:** `/ap_release pr` or `/ap_release beta`
6. **Suggest artifact validation:** `bash .agent_process/scripts/evaluate-scope.sh .agent_process/work/{scope}`

## If ITERATE

1. **Create sub-iteration folder:**
   ```bash
   mkdir -p .agent_process/work/{scope}/{next_iteration}
   ```
2. **Write placeholder results.md** with 1-3 required fixes from the decision
3. **Update iteration_plan.md:** Latest iteration pointer, decision = ITERATE
4. **Update validation script** if fixes touch new files not in original scope
5. **Deposit process knowledge (Step 9.7, conditional):**
   - Only if the reviewer spots a generalizable lesson about process, scope structure, or agent behavior
   - If found, deposit 0-2 process observations to `.agent_process/knowledge/*.jsonl`
   - Most ITERATEs won't produce learnings — that's fine
6. Hand back to implementation session: `/ap_exec {scope} {next_iteration}`

## If BLOCK

1. **Update iteration_plan.md:** Decision = BLOCK, date, reason
2. **Update requirement doc:** Change frontmatter `status:` to `blocked`
3. **Deposit process knowledge (Step 9.6):**
   - Check `quality-config.json` → `knowledge_base.deposit_on_block_pivot`
   - If systemic pattern found, deposit 0-2 process observations
4. **Escalate to human** with decision options (ship/pivot/abort)

## If PIVOT

1. **Update iteration_plan.md:** Decision = PIVOT, date, proposed changes
2. **Deposit process knowledge (Step 9.6)** if systemic pattern found
3. Do NOT update requirement doc — wait for human approval of scope change
5. **Get human approval** before modifying criteria or creating new iteration

---

## Knowledge Deposit Schema

```json
{"id": "snake_case_id", "type": "pattern|gotcha|decision|anti-pattern",
 "fact": "Description", "recommendation": "What to do",
 "confidence": "high|medium|low",
 "provenance": [{"source": "agent", "reference": "{scope}/{iteration}", "date": "YYYY-MM-DD"}],
 "tags": ["keyword1"], "affectedFiles": ["path/to/file"],
 "createdAt": "ISO8601", "updatedAt": "ISO8601"}
```

Knowledge directory:
```bash
KB_DIR=".agent_process/knowledge"
```

---

## Output Format

Write to `.run/review/07-10-post-decision.md`:

```markdown
# Post-Decision Actions

**Decision:** {APPROVE/ITERATE/BLOCK/PIVOT}

## Actions Taken
- {action 1: what was done}
- {action 2: what was done}

## Knowledge Deposited
- {entry id → file.jsonl} (or "None")

## Next Step
{APPROVE: Run `/ap_release pr` to create PR}
{ITERATE: Run `/ap_exec {scope} {next_iteration}` in implementation session}
{BLOCK: Human decides — ship as-is, pivot, or abort}
{PIVOT: Human approves revised criteria, then re-plan with `orchestration/plan-scope.md`}
```
