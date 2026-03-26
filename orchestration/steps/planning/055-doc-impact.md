# Step 5.5: Identify Documentation Impact

**Model tier:** cheap
**Tools needed:** Read, Grep
**Input:** Requirement file, files-in-scope output (`.run/planning/04-files-in-scope.md`)
**Output:** `.run/planning/055-doc-impact.md`

---

## Your Task

Determine which documentation needs updating based on this scope's changes. Per the "Zero Documentation Drift" rule, docs update in the same commit as code.

## Fast-Track Assessment

Answer these questions:

**End User Impact:**
1. Does this scope change visible behavior (UI, features, workflows)?
2. Does this scope change how users accomplish tasks?

**Developer User Impact:**
1. Does this scope change public API (endpoints, functions, interfaces)?
2. Does this scope change integration points (config, dependencies)?
3. Does this scope introduce architectural decisions?

**All "no"?** → Internal implementation change, no doc impact.

**Any "yes"?** → Search for affected docs below.

## Search for Affected Docs

Use the files-in-scope list to search for documentation references:

```bash
# Search for references to changed components
grep -r "ComponentName" docs/
grep -r "FunctionName" docs/

# Search README files
grep -r "featureName" */README.md

# Search for config references
grep -r "config.optionName" docs/
```

## Documentation Types by Change

| Change Type | End User Docs | Developer Docs |
|-------------|---------------|----------------|
| New UI feature | Yes | Maybe |
| New API endpoint | No* | Yes |
| Architecture decision | No | Yes |
| Config option change | Maybe | Yes |
| Bug fix (no API change) | No | No |
| Internal refactor | No | No |

*Unless API is directly exposed to end users

## Output Format

Write to `.run/planning/055-doc-impact.md`:

```markdown
# Documentation Impact Assessment

**Scope:** {scope_name}

## Fast-Track
- End user impact: YES/NO — {brief reason}
- Developer user impact: YES/NO — {brief reason}

## Affected Documentation

### End User Docs
- {path/to/doc.md} — {what needs updating}
- Or: *None — no user-facing changes*

### Developer Docs
- {path/to/doc.md} — {what needs updating}
- Or: *None — internal implementation only*

## Recommended Criteria Additions
- [ ] {Doc criterion to add to frozen criteria, if any}
```
