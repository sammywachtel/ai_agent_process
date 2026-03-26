# Step 2.5: Query Knowledge Base

**Model tier:** cheap
**Tools needed:** Grep, Read
**Input:** Requirement file path, scope name
**Output:** `.run/planning/025-knowledge.md`

---

## Your Task

Search the project's knowledge base for entries relevant to this scope. The knowledge base stores patterns, gotchas, decisions, and anti-patterns from previous iterations.

## Find the Knowledge Directory

Check in order:
1. `.beads/knowledge/` (BEADS-enabled projects)
2. `.agent_process/knowledge/` (fallback)

If neither exists, write "No knowledge base found" to the output and stop.

## Extract Search Terms

From the requirement file, extract:
- Category name (e.g., `auth`, `frontend`, `decomposition`)
- Key component or file names mentioned
- Technical concepts involved (e.g., "sub-agent", "coordinator", "prompt")

## Search

```bash
# Search by tags/keywords
grep -i "<keyword1>\|<keyword2>" "$KB_DIR"/*.jsonl

# Search by affected files
grep -i "<filename_pattern>" "$KB_DIR"/*.jsonl
```

**Note:** `bd prime` outputs generic workflow context, not knowledge queries. Grep is the correct tool for searching knowledge entries. Metaswarm's `/metaswarm:prime` skill adds keyword/file filtering if available, but this step uses grep as the universal method.

## Output Format

Write to `.run/planning/025-knowledge.md`:

```markdown
# Knowledge Base Query Results

**Scope:** {scope_name}
**Keywords searched:** {keyword1}, {keyword2}, {keyword3}
**Knowledge directory:** {path used}

## Relevant Entries

### {entry.id} ({entry.type}, confidence: {entry.confidence})
**Fact:** {entry.fact}
**Recommendation:** {entry.recommendation}
**Source:** {entry.provenance[0].source} — {entry.provenance[0].reference}

{Repeat for each relevant entry}

## Summary
{Count} relevant entries found. Key takeaways:
- {takeaway 1}
- {takeaway 2}
```

If no entries found:
```markdown
# Knowledge Base Query Results

**Scope:** {scope_name}
**Keywords searched:** {keywords}

*No relevant knowledge base entries for this scope.*
```
