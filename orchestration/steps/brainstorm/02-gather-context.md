# Step 02: Gather Project Context

**Model tier:** cheap
**Tools needed:** Read, Grep, Bash
**Input:** idea (from user)
**Output:** `.agent_process/brainstorms/.run/02-context.md`

---

## Your Task

Collect context that grounds the brainstorm in this specific project.

## Gather

1. **Read project README** (if exists) — understand what this project does
2. **Scan existing requirements:**
   ```bash
   ls .agent_process/requirements_docs/ 2>/dev/null
   ```
3. **Check backlog** for related items:
   ```bash
   grep -i "relevant_keywords" .agent_process/roadmap/backlog.md 2>/dev/null
   ```
4. **Query knowledge base** for related patterns/gotchas:
   ```bash
   KB_DIR=".agent_process/knowledge"
   grep -i "relevant_keywords" "$KB_DIR"/*.jsonl 2>/dev/null
   ```

Extract keywords from the idea to search with.

## Output Format

```markdown
# Project Context

**Project:** {name from README or directory}
**Idea:** {user's idea}

## Relevant Context
- {bullet points grounding the idea in this project}

## Existing Related Work
- {any related requirements, backlog items, or knowledge entries}
```
