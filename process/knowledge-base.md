# Knowledge Base

**Type:** How-To Guide (Diátaxis)
**Purpose:** Query, deposit, and curate project knowledge across iterations

---

## Overview

The knowledge base is a set of JSONL files that accumulate project wisdom over time. Each APPROVE deposits 0-3 code learnings; each BLOCK or PIVOT may deposit 0-2 process observations; each planning phase queries for relevant entries. The system starts empty and gets smarter with every scope — even blocked ones.

### Storage Location

Knowledge lives in **`.beads/knowledge/`** when BEADS is enabled. This is the same location metaswarm uses, creating a shared knowledge store accessible to both AP orchestration and metaswarm.

When BEADS is disabled, knowledge falls back to **`.agent_process/knowledge/`**.

**How to find the right directory:**
```bash
# Check BEADS-managed knowledge first, fall back to AP-managed
if [ -d ".beads/knowledge" ]; then
  KB_DIR=".beads/knowledge"
elif [ -d ".agent_process/knowledge" ]; then
  KB_DIR=".agent_process/knowledge"
fi
```

---

## Knowledge Files

| File | What goes here | Example |
|------|---------------|---------|
| `patterns.jsonl` | Recommended approaches that worked | "Auth uses middleware pattern, not decorators" |
| `gotchas.jsonl` | Things that bit us, non-obvious pitfalls | "Session tokens in localStorage breaks compliance" |
| `decisions.jsonl` | Architectural choices with rationale | "Chose JWT refresh over sliding window (latency)" |
| `anti-patterns.jsonl` | Approaches that failed or should be avoided | "Don't cache decoded tokens — invalidation nightmare" |
| `codebase-facts.jsonl` | Facts about how code works | "Thread model stores drafts only, not threads" |
| `api-behaviors.jsonl` | External API quirks and behaviors | "API returns 429 after ~100 req/min" |

The first four files are core AP files. The last two (`codebase-facts`, `api-behaviors`) are metaswarm-compatible extensions — use them when BEADS is enabled and the distinction is helpful.

---

## Entry Schema

AP uses the metaswarm-compatible knowledge schema so entries are shared between AP and metaswarm.

### Full Schema (BEADS-managed)

```json
{
  "id": "unique_snake_case_id",
  "type": "pattern|gotcha|decision|anti_pattern|api_behavior|code_quirk|performance|security",
  "fact": "Clear description of the knowledge",
  "recommendation": "What to do about it",
  "confidence": "high|medium|low",
  "provenance": [
    {
      "source": "agent|human|documentation|test|production",
      "reference": "scope_name/iteration_XX",
      "date": "YYYY-MM-DD"
    }
  ],
  "tags": ["auth", "middleware"],
  "affectedFiles": ["src/middleware/auth.ts"],
  "createdAt": "YYYY-MM-DDTHH:MM:SSZ",
  "updatedAt": "YYYY-MM-DDTHH:MM:SSZ"
}
```

### Minimal Schema (fallback, no BEADS)

When BEADS is disabled, a simpler schema works:

```json
{
  "id": "unique_snake_case_id",
  "type": "pattern|gotcha|decision|anti_pattern",
  "fact": "Clear description of the knowledge",
  "recommendation": "What to do about it",
  "confidence": "high|medium|low",
  "tags": ["auth"],
  "source_iteration": "scope_name/iteration_XX",
  "date": "YYYY-MM-DD"
}
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique snake_case identifier within the file |
| `type` | Yes | Knowledge category (must match the file it's in) |
| `fact` | Yes | Clear description — scannable in under 5 seconds |
| `recommendation` | Yes | Actionable guidance — what to do with this knowledge |
| `confidence` | Recommended | `high` (verified multiple times), `medium` (observed once), `low` (suspected) |
| `provenance` | BEADS only | Source chain: who discovered it, where, when |
| `tags` | Recommended | Search keywords for filtered queries |
| `affectedFiles` | BEADS only | Glob patterns for files this applies to |
| `source_iteration` | Fallback only | Shorthand for provenance when BEADS unavailable |
| `date` | Fallback only | Shorthand for provenance date |

**Rules:**
- `id` must be unique within its file
- `fact` should be scannable in under 5 seconds
- `recommendation` should be actionable — "Use X because Y", not just "X exists"
- Entries are append-only in normal operation

---

## How to Query (Planning Phase)

The orchestrator queries the knowledge base before creating `iteration_plan.md`. Two methods, depending on what's available:

### Method 1: `bd prime` (BEADS workflow context)

`bd prime` outputs generic BEADS workflow context (session close protocol, command reference). It does **not** query or filter knowledge entries — it's a context dump, not a knowledge search tool.

```bash
bd prime        # Generic workflow context
bd prime --full # Force full CLI output
```

**Note:** Metaswarm's `/metaswarm:prime` skill wraps `bd prime` with additional intelligence, but those filtering capabilities (`--keywords`, `--work-type`, `--files`) are metaswarm features, not `bd` features. If you see documentation referencing those flags on `bd prime` directly, it's incorrect.

### Method 2: grep (primary query method)

```bash
# Find the knowledge directory
KB_DIR=".beads/knowledge"
[ ! -d "$KB_DIR" ] && KB_DIR=".agent_process/knowledge"

# Search by keyword across all files
grep -i "auth\|session\|jwt" "$KB_DIR"/*.jsonl

# Search by affected files (BEADS schema)
grep -i "middleware\|auth.ts" "$KB_DIR"/*.jsonl
```

### Include Findings in Plan

Add matches to `## Known Patterns & Constraints`:

```markdown
## Known Patterns & Constraints

**From knowledge base:**
- **[pattern]** Auth uses middleware pattern, not route decorators (confidence: high)
- **[gotcha]** Session tokens must not use localStorage — compliance requirement
- **[decision]** JWT refresh tokens over sliding window (latency trade-off)
- **[anti_pattern]** Don't cache decoded tokens — invalidation creates subtle bugs

**No matches found for:** [list keywords that returned nothing]
```

If no entries exist (common early on), note it — the knowledge base grows with each APPROVE (code learnings) and BLOCK/PIVOT (process observations).

---

## How to Deposit (Review Phase)

The knowledge base accepts two types of deposits at different decision points:

| Decision | What to deposit | Why it's safe |
|----------|----------------|---------------|
| **APPROVE** | Code patterns, gotchas, decisions, anti-patterns (0-3 entries) | Code is verified — learnings are grounded in working implementation |
| **BLOCK/PIVOT** | Process observations only (0-2 entries) | Process patterns don't depend on code correctness |
| **ITERATE** | Nothing | Code isn't verified and criteria haven't changed — too early to generalize |

### Code Knowledge Deposit (APPROVE)

After an APPROVE decision, the orchestrator extracts 0-3 learnings.

### Step 1: Find the Knowledge Directory

```bash
KB_DIR=".beads/knowledge"
[ ! -d "$KB_DIR" ] && KB_DIR=".agent_process/knowledge"
```

### Step 2: Reflect on the Iteration

Ask these questions about the completed work:
1. Did we discover a pattern worth reusing? → `patterns.jsonl`
2. Did something non-obvious bite us? → `gotchas.jsonl`
3. Did we make an architectural choice with trade-offs? → `decisions.jsonl`
4. Did we try something that failed? → `anti-patterns.jsonl`

### Step 3: Write Entries

**Good entry (specific, reusable, metaswarm-compatible):**
```json
{"id": "auth_middleware_pattern", "type": "pattern", "fact": "Auth checks use Express middleware, not route-level decorators", "recommendation": "Apply auth middleware in app.ts before route registration. Don't use decorators — they cause route ordering issues in Express 5.", "confidence": "high", "provenance": [{"source": "agent", "reference": "auth_scope_01/iteration_02", "date": "2025-03-15"}], "tags": ["auth", "middleware", "express"], "affectedFiles": ["src/app.ts", "src/middleware/auth.ts"], "createdAt": "2025-03-15T00:00:00Z", "updatedAt": "2025-03-15T00:00:00Z"}
```

**Bad entry (too vague to be useful):**
```json
{"id": "auth_stuff", "type": "pattern", "fact": "Auth is tricky", "recommendation": "Be careful.", "confidence": "low", "tags": [], "createdAt": "2025-03-15T00:00:00Z", "updatedAt": "2025-03-15T00:00:00Z"}
```

### Step 4: Append to the Right File

```bash
echo '{"id": "auth_middleware_pattern", ...}' >> "$KB_DIR/patterns.jsonl"
```

### Step 5: Deposit 0 Entries When Appropriate

Not every scope produces learnings. If the work was straightforward and nothing surprising happened, deposit nothing. Don't force entries just to fill the knowledge base.

### Process Knowledge Deposit (BLOCK or PIVOT)

After a BLOCK or PIVOT decision, the orchestrator may extract 0-2 *process observations*. These are things about scope structure, agent behavior, or review patterns — valid regardless of whether the code shipped.

#### What Qualifies

- Implementation agents consistently miss something (e.g., stale doc references)
- A type of acceptance criterion always blocks (e.g., operational gates)
- Scope structure caused predictable problems
- Review caught a systemic pattern worth flagging for future planners

#### What Does NOT Qualify

- Code patterns or architectural decisions → wait for APPROVE
- Library-specific gotchas → wait for APPROVE (approach might change on retry)
- One-off blockers (missing API key, broken CI) → not systemic, not worth preserving

#### Example

```json
{"id": "impl_agents_miss_stale_doc_refs", "type": "gotcha", "fact": "Implementation agents claim docs need no update while stale references remain", "recommendation": "When removing code, always grep docs/ for references. Agents skip this — review must catch it.", "confidence": "high", "provenance": [{"source": "agent", "reference": "gemini_hybrid_06_hard_cutover/iteration_01", "date": "2026-03-21"}], "tags": ["documentation", "refactoring", "agent-behavior"], "affectedFiles": ["docs/**/*.md"], "createdAt": "2026-03-21T00:00:00Z", "updatedAt": "2026-03-21T00:00:00Z"}
```

Most BLOCKs and PIVOTs won't produce process learnings — that's fine. Only deposit when you see something likely to repeat.

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
| Planning (Step 2.5) | Query knowledge via grep | `orchestration/steps/planning/025-knowledge-query.md` |
| Planning output | Include findings in `## Known Patterns & Constraints` | `templates/iteration-plan.md` |
| Review (APPROVE, Step 9.5) | Extract 0-3 code learnings → `$KB_DIR/*.jsonl` | `orchestration/steps/review/07-10-post-decision.md` |
| Review (BLOCK/PIVOT, Step 9.6) | Extract 0-2 process observations → `$KB_DIR/*.jsonl` | `orchestration/steps/review/07-10-post-decision.md` |
| `bd prime` | Generic BEADS workflow context (not knowledge search) | Reads `.beads/` metadata |
| Metaswarm `/metaswarm:prime` | Wraps `bd prime` with keyword/file filtering | Reads `$KB_DIR/*.jsonl` |
| Metaswarm `/metaswarm:self-reflect` | Mines PR comments + conversation history → knowledge | Writes `$KB_DIR/*.jsonl` |

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
