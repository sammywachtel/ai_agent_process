# Knowledge Base

**Type:** How-To Guide (Diátaxis)
**Purpose:** Query, deposit, and curate project knowledge across iterations

---

## Overview

The knowledge base is a set of JSONL files in `.agent_process/knowledge/` that accumulate project wisdom over time. Each APPROVE deposits 0-3 learnings; each planning phase queries for relevant entries. The system starts empty and gets smarter with every completed scope.

---

## Knowledge Files

| File | What goes here | Example |
|------|---------------|---------|
| `patterns.jsonl` | Recommended approaches that worked | "Auth uses middleware pattern, not decorators" |
| `gotchas.jsonl` | Things that bit us, non-obvious pitfalls | "Session tokens in localStorage breaks compliance" |
| `decisions.jsonl` | Architectural choices with rationale | "Chose JWT refresh over sliding window (latency)" |
| `anti-patterns.jsonl` | Approaches that failed or should be avoided | "Don't cache decoded tokens — invalidation nightmare" |

---

## Entry Schema

Every entry (except the first `_schema` line) follows this format:

```json
{
  "id": "unique_snake_case_id",
  "scope": "category or area (e.g., auth, frontend, database)",
  "summary": "One-line description for scanning",
  "detail": "Full explanation with context, rationale, and evidence",
  "source_iteration": "scope_name/iteration_XX where this was learned",
  "date": "YYYY-MM-DD"
}
```

**Rules:**
- `id` must be unique within its file
- `scope` should match requirement categories when possible (enables filtered queries)
- `summary` should be scannable in under 5 seconds
- `detail` should include enough context that someone unfamiliar can understand *why*
- Entries are append-only in normal operation

---

## How to Query (Planning Phase)

The orchestrator queries the knowledge base before creating `iteration_plan.md`. This is documented in `orchestration/01_plan_scope_instructions.md`, but here's the standalone process:

### Step 1: Identify Search Terms

From the scope you're planning, extract:
- The requirement category (e.g., `auth`, `frontend`, `lexical_editor`)
- Key file paths or component names
- Technical concepts involved (e.g., "JWT", "state management", "API design")

### Step 2: Search Knowledge Files

```bash
# Search by category/scope
grep -i "auth" .agent_process/knowledge/*.jsonl

# Search by keyword across all files
grep -i "session\|token\|jwt" .agent_process/knowledge/*.jsonl

# Search for entries related to specific files
grep -i "login\|session" .agent_process/knowledge/*.jsonl
```

### Step 3: Include Relevant Findings

Add matches to the `## Known Patterns & Constraints` section of `iteration_plan.md`:

```markdown
## Known Patterns & Constraints

**From knowledge base:**
- **Pattern:** Auth uses middleware pattern (decision: 2024-Q3, source: auth_scope_01/iteration_02)
- **Gotcha:** Session tokens must not use localStorage (compliance requirement)
- **Decision:** JWT refresh tokens over sliding window (latency trade-off)
- **Anti-pattern:** Don't cache decoded tokens — invalidation creates subtle bugs

**No matches found for:** [list keywords that returned nothing — helps future curation]
```

### Step 4: Handle Empty Results

If no relevant entries exist (common early on), note it:

```markdown
## Known Patterns & Constraints

*No relevant knowledge base entries found for scope: user_auth*
*Keywords searched: auth, session, login, JWT*
```

This is fine — the knowledge base grows with each APPROVE.

---

## How to Deposit (Review Phase)

After an APPROVE decision, the orchestrator extracts 0-3 learnings. This is documented in `orchestration/02_review_iteration_instructions.md`, but here's the standalone process:

### Step 1: Reflect on the Iteration

Ask these questions about the completed work:
1. Did we discover a pattern worth reusing? → `patterns.jsonl`
2. Did something non-obvious bite us? → `gotchas.jsonl`
3. Did we make an architectural choice with trade-offs? → `decisions.jsonl`
4. Did we try something that failed? → `anti-patterns.jsonl`

### Step 2: Write Entries

**Good entry (specific, reusable):**
```json
{"id": "auth_middleware_pattern", "scope": "auth", "summary": "Auth checks use Express middleware, not route-level decorators", "detail": "Decorators caused issues with route ordering in Express 5. Middleware pattern applied in app.ts before route registration ensures consistent auth checking. See auth_scope_01/iteration_02 for migration details.", "source_iteration": "auth_scope_01/iteration_02", "date": "2025-03-15"}
```

**Bad entry (too vague to be useful):**
```json
{"id": "auth_stuff", "scope": "general", "summary": "Auth is tricky", "detail": "Had some issues with auth.", "source_iteration": "unknown", "date": "2025-03-15"}
```

### Step 3: Append to the Right File

```bash
# Append a pattern entry
echo '{"id": "auth_middleware_pattern", "scope": "auth", ...}' >> .agent_process/knowledge/patterns.jsonl
```

### Step 4: Deposit 0 Entries When Appropriate

Not every scope produces learnings. If the work was straightforward and nothing surprising happened, deposit nothing. Don't force entries just to fill the knowledge base.

---

## How to Curate (Manual Maintenance)

Over time, the knowledge base may need cleanup. This is a manual process — do it when entries become stale or the files get large.

### When to Curate

- **File exceeds ~100 entries**: Some entries may be obsolete
- **Contradictory entries exist**: A newer decision may supersede an older one
- **Entries reference deleted code**: Clean up after major refactors
- **Planning queries return too many results**: Tighten scope tags

### How to Curate

1. **Review entries**: Read through the file, identify stale or redundant entries
2. **Remove obsolete entries**: Delete lines for patterns/decisions that no longer apply
3. **Consolidate duplicates**: Merge similar entries into one comprehensive entry
4. **Update scope tags**: Ensure scope values match current category names
5. **Preserve the schema line**: Always keep the first `_schema` line intact

### Curation Tips

- **Don't over-curate**: Some "old" entries are still valuable context
- **Preserve the why**: Even if a pattern was abandoned, knowing *why* it was abandoned helps
- **Date helps**: Entries with old dates are candidates for review, not automatic deletion
- **Anti-patterns are permanent**: Something that failed once will likely fail again — keep these

---

## Integration Points

| Phase | Action | File |
|-------|--------|------|
| Planning (Step 3) | Query knowledge base for scope-relevant entries | `01_plan_scope_instructions.md` |
| Planning output | Include findings in `## Known Patterns & Constraints` | `templates/iteration-plan.md` |
| Review (APPROVE) | Extract 0-3 learnings and append to knowledge files | `02_review_iteration_instructions.md` |

---

## Troubleshooting

**Q: Knowledge base is empty, should I pre-populate it?**
A: No. Let it grow organically through APPROVE deposits. Pre-populated entries lack the context that comes from actually experiencing the issue.

**Q: Queries return too many results, overwhelming the iteration plan.**
A: Filter more aggressively by scope/category. Include only entries directly relevant to the files you're changing, not the entire category.

**Q: An entry is wrong — the pattern it recommends caused problems.**
A: Move it to `anti-patterns.jsonl` with updated detail explaining what went wrong. Don't just delete it — future planners need to know what *not* to do.

**Q: Two entries contradict each other.**
A: The newer entry wins. Update the older entry's detail to note it was superseded, or remove it entirely. Add the superseding entry's ID to the detail for traceability.
