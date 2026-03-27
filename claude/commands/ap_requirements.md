---
name: ap_requirements
description: Create, import, brainstorm, and manage project requirements
argument-hint: add | import | brainstorm | list ["details"]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, TodoWrite, Agent]
arguments:
  - name: action
    required: true
    type: string
    description: |
      Action to perform:
      - add: Create new requirement (offers brainstorm if metaswarm available)
      - import: Import existing file as requirement (adds frontmatter, standardizes name)
      - brainstorm: Structured ideation → formal requirement (requires metaswarm)
      - list: Show all requirements with status
  - name: details
    required: false
    type: string
    description: |
      Additional details depending on action:
      - add: "requirement title"
      - import: "file_path [--supersedes old_requirement_id]"
      - brainstorm: "idea or problem description"
      - list: "category" (optional filter)
---

# Requirements Management

**Purpose:** Create, import, brainstorm, and manage formal requirements for `.agent_process` projects.

## Process Documentation

Before proceeding, familiarize yourself with:
- **Naming conventions:** `.agent_process/process/naming_conventions.md` (IDs, files, categories)
- **Metaswarm integration:** `.agent_process/process/metaswarm-integration.md` (optional brainstorm/design review)

## Template Variables

When generating files from templates, resolve these variables before writing:

| Variable | Resolution | Example |
|----------|------------|---------|
| `{{ current_date }}` | Today's date in `YYYY-MM-DD` format | `2025-06-15` |
| `{{ git_author }}` | Run `git config user.name` in the project directory | `Jane Smith` |
| `{{ details }}` | The `details` argument passed to the command | (user-provided) |

**`{{ git_author }}` fallback:** If `git config user.name` returns empty, fall back to `git config user.email`. If both are empty, use `[Unknown — run git config user.name to set]`.

## Quick Reference

```bash
# Create requirements
/ap_requirements add "User authentication system"       # Direct or brainstorm-assisted
/ap_requirements import "path/to/draft.md"               # Import existing file
/ap_requirements brainstorm "Improve the login experience" # Ideation → requirement (needs metaswarm)

# Browse requirements
/ap_requirements list                                    # All requirements by category
/ap_requirements list "infrastructure"                   # Filter by category
```

## Metaswarm Availability Check

Before proceeding with any action, determine metaswarm status:

1. Read `.agent_process/quality-config.json`
2. Check `metaswarm.enabled` — if `false` or missing, set `METASWARM_AVAILABLE = false`
3. If enabled, verify metaswarm is actually installed:
   - Check for metaswarm commands: `ls ~/.claude/commands/brainstorm.md 2>/dev/null`
   - Or check project-local: `ls .claude/commands/brainstorm.md 2>/dev/null`
4. Results:
   - `METASWARM_AVAILABLE = true` — metaswarm enabled and installed
   - `METASWARM_AVAILABLE = false, METASWARM_INSTALL_NEEDED = true` — enabled in config but not installed
   - `METASWARM_AVAILABLE = false, METASWARM_INSTALL_NEEDED = false` — disabled in config (don't mention it)

**Rule:** When `METASWARM_INSTALL_NEEDED = true`, inform the user once:
> "Metaswarm is enabled in quality-config.json but doesn't appear to be installed.
> Install via: `claude plugin install metaswarm` then re-run.
> Continuing without metaswarm features."

Then proceed with the non-metaswarm path. Don't block on it.

## Current Action: {{ action }}

---

{% if action == "add" %}

## Create New Requirement

**Requirement Name:** {{ details }}

### Step 1: Validate Input

{% if not details %}
Error: Please provide a requirement name.
Usage: `/ap_requirements add "User authentication system"`
{% endif %}

### Step 2: Offer Brainstorm (if metaswarm available)

**Only if `METASWARM_AVAILABLE = true` AND `metaswarm.features.brainstorm = true`:**

Ask the user:
> "Would you like to brainstorm this idea first? Brainstorming produces a richer requirement
> with design review feedback, trade-off analysis, and structured success criteria.
>
> 1. **Brainstorm first** (recommended for complex or exploratory features)
> 2. **Create directly** (for well-understood requirements)"

- If user chooses brainstorm → tell them to run `/ap_brainstorm "{{ details }}"` (it handles the full workflow including requirement creation)
- If user chooses direct → continue to Step 3

**If `METASWARM_AVAILABLE = false`:** Skip this step entirely. Do not mention brainstorm.

### Step 3: Determine Location

Ask user where to place the requirement:
- Root level (`requirements_docs/{name}.md`)
- Existing category (`requirements_docs/{category}/{name}.md`)
- New category (`requirements_docs/{new_category}/{name}.md`)

### Step 4: Generate Requirement ID

Create normalized ID from name and location:
```
Name: "User authentication system"
Location: Root level
→ ID: user_authentication_system
→ File: requirements_docs/user_authentication_system.md
```

### Step 5: Create from Template

Use the requirement template from `.agent_process/requirements_docs/_TEMPLATE_requirements.md`:

```markdown
---
id: {{ requirement_id }}
type: requirement
category: {{ category }}
status: not_started
priority: {{ priority }}
---

# Requirements: {{ details }}

---

## Objective
[One clear sentence describing what this scope achieves]

## Background
[Why is this needed? What problem does it solve?]

---

## Technical Requirements

1. [Specific requirement 1]
2. [Specific requirement 2]
3. [...]

---

## Success Criteria
- [ ] [Measurable criterion 1]
- [ ] [Measurable criterion 2]
- [ ] [...]

---

## Files Expected to Change
- `path/to/file1.tsx`
- `path/to/file2.ts`

**Estimated:** 4-8 files

---

## Out of Scope
[Explicitly list what is NOT included]

---

## Known Risks
- [Risk 1 and mitigation strategy]
- [Risk 2 and mitigation strategy]
```

**Note:** The `type: requirement` field is mandatory — discovery and sync will ignore files without it.

### Step 6: Update Roadmap

Add new requirement to master roadmap with NOT_STARTED status.

### Step 7: Suggest Next Steps

Recommend:
- Fill in the requirement details with acceptance criteria and scope
- Set appropriate priority based on impact and effort
- **Use orchestrator planning workflow** when ready:
  1. Copy requirement content to `.agent_process/orchestration/plan-scope.md`
  2. Run through orchestrator to create iteration plan with validation
  3. Orchestrator will create work scope directory and iteration_01/
  4. Then use `/ap_exec {scope_name} iteration_01` to execute the plan
- If criteria change after review, use PIVOT to create iteration_02, etc.

**Note:** Do NOT run `/ap_exec` directly - orchestrator must plan the scope first.

{% elif action == "brainstorm" %}

## Brainstorm → Requirement

**Use `/ap_brainstorm "{{ details }}"` instead.**

`/ap_brainstorm` provides multi-agent brainstorming (Product, Architecture, Critical perspectives), optional design review, and transforms the output into a formal AP requirement — all in one command.

```bash
/ap_brainstorm "{{ details }}"
```

{% elif action == "import" %}

## Import Existing File as Requirement

**Input:** {{ details }}

Import an existing markdown file as a formal requirement. Adds frontmatter if missing, standardizes the filename, and adds to roadmap.

**Reference:** `.agent_process/process/naming_conventions.md`

### Step 1: Parse Input

{% if not details %}
**Error:** Please provide a file path.

**Usage:**
```bash
/ap_requirements import "path/to/file.md"
/ap_requirements import "path/to/file.md --supersedes old_requirement_id"
```
{% else %}

Parse the details argument:
- **File path:** First part (required)
- **--supersedes:** Optional flag with old requirement ID to archive

### Step 2: Read and Validate Source File

1. Check file exists
2. Read content
3. Extract frontmatter if present

```python
from pathlib import Path
import re

file_path = Path("{{ details }}".split("--supersedes")[0].strip())
if not file_path.exists():
    raise FileNotFoundError(f"File not found: {file_path}")

content = file_path.read_text()

# Extract frontmatter if present
frontmatter = {}
if content.startswith("---"):
    fm_match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if fm_match:
        import yaml
        frontmatter = yaml.safe_load(fm_match.group(1)) or {}
```

### Step 3: Analyze Content and Gather Context

Before prompting the user, gather all the information needed to make smart suggestions:

```python
# 1. Infer category from frontmatter or content
if frontmatter.get("category"):
    inferred_category = frontmatter["category"]
    category_source = "frontmatter"
else:
    content_lower = content.lower()
    # Try to match against existing category directories
    existing_categories = [d.name for d in Path(".agent_process/requirements_docs").iterdir() if d.is_dir() and not d.name.startswith("_")]
    inferred_category = "uncategorized"
    category_source = "no category keywords found"
    for cat in existing_categories:
        # Check if category name words appear in content
        cat_words = cat.replace("_", " ")
        if cat_words in content_lower:
            inferred_category = cat
            category_source = f"content mentions '{cat_words}'"
            break

# 2. Find next epic/scope number for this category
existing_ids = [extract IDs from master_roadmap.md for this category]
# e.g., for lexical_editor: lexical_epic_01, lexical_epic_06, lexical_epic_07
next_number = max([extract numbers]) + 1  # e.g., 8

# 3. Extract a short descriptor from the title or filename
title = extract first # heading from content
descriptor = derive 1-3 word descriptor  # e.g., "navigation", "save_bugs"

# 4. Build suggested ID
suggested_id = f"{category_prefix}_epic_{next_number:02d}_{descriptor}"
# e.g., "lexical_epic_08_navigation"

# 5. Get priority from frontmatter or content
if frontmatter.get("priority"):
    inferred_priority = frontmatter["priority"].upper()
    priority_source = "frontmatter"
else:
    # Look for **Priority:** in content
    priority_match = re.search(r'\*\*Priority[:\*]*\*?\s*(\w+)', content)
    if priority_match:
        inferred_priority = priority_match.group(1).upper()
        priority_source = "parsed from content"
    else:
        inferred_priority = "MEDIUM"
        priority_source = "default"
```

### Step 4: Confirm Category with User

Use AskUserQuestion to confirm the category:

**Question:** "What category should this requirement belong to?"

**Header:** "Category"

**Context to show:**
```
Naming convention: Requirements are organized by category (e.g., lexical_editor, ai_radar, word_tools).
See: .agent_process/process/naming_conventions.md

I detected: {inferred_category}
Reason: {category_source}
```

**Options:**
1. `{inferred_category}` (Recommended) - "{category_source}"
2. Other standard categories as applicable (from existing category directories)
3. "Other" - user provides custom category

### Step 5: Confirm Requirement ID with User

Use AskUserQuestion to confirm the ID:

**Question:** "What ID should this requirement use?"

**Header:** "Requirement ID"

**Context to show:**
```
Naming convention: {category}_{descriptor} or {category}_epic_{NN}_{descriptor}
Existing {category} requirements: {list existing IDs in this category}
Next available number: {next_number}

I suggest: {suggested_id}
Reason: Follows epic numbering pattern, next available is {next_number},
        descriptor '{descriptor}' derived from title.
```

**Options:**
1. `{suggested_id}` (Recommended) - "Follows project naming pattern"
2. `{filename_based_id}` - "Based on current filename"
3. If frontmatter had an id: `{frontmatter_id}` - "From existing frontmatter"
4. "Other" - user provides custom ID

### Step 6: Confirm Priority with User

Use AskUserQuestion to confirm the priority:

**Question:** "What priority level for this requirement?"

**Header:** "Priority"

**Context to show:**
```
Priority levels: CRITICAL (blocking), HIGH (important), MEDIUM (normal), LOW (nice-to-have)

I detected: {inferred_priority}
Reason: {priority_source}
```

**Options:**
1. `{inferred_priority}` (Recommended) - "{priority_source}"
2. Other priority levels (CRITICAL, HIGH, MEDIUM, LOW)

### Step 7: Check for Conflicts

After user confirms ID, check if it already exists:

```python
roadmap_path = Path(".agent_process/roadmap/master_roadmap.md")
if roadmap_path.exists():
    roadmap_content = roadmap_path.read_text()
    if f"| {confirmed_id} |" in roadmap_content or f"id: {confirmed_id}" in roadmap_content:
        # CONFLICT - go back to Step 5 with error message
        # "ID '{confirmed_id}' already exists. Please choose a different ID."
```

**If conflict detected:** Loop back to Step 5 with the conflict noted.

### Step 8: Handle --supersedes (if provided)

If `--supersedes old_id` was specified:

1. Verify old_id exists in roadmap
2. Archive it using the archive flow:
   - Move to archived_roadmap.md
   - Add to .roadmap_config.json archived_requirements
   - Log to .roadmap_audit.jsonl
3. Add `supersedes: old_id` to new requirement's frontmatter

### Step 9: Write Frontmatter

Build complete frontmatter from confirmed values:

```yaml
---
id: {confirmed_id}
type: requirement
category: {confirmed_category}
status: not_started
priority: {confirmed_priority}
supersedes: {old_id if --supersedes else omit}
---
```

**Note:** The `type: requirement` field is mandatory — discovery and sync will ignore files without it.

### Step 10: Determine Target Location

**ALWAYS place files in category subdirectory** (unless uncategorized):

```python
target_dir = Path(".agent_process/requirements_docs")
if confirmed_category != "uncategorized":
    target_dir = target_dir / confirmed_category
target_dir.mkdir(parents=True, exist_ok=True)

# Use confirmed_id for the filename
target_file = target_dir / f"{confirmed_id}.md"

# Check if source is already at target
source_path = Path(file_path)
if source_path.resolve() == target_file.resolve():
    needs_move = False
else:
    needs_move = True
    # Check target doesn't already exist (different file)
    if target_file.exists():
        raise FileExistsError(f"Target file already exists: {target_file}")
```

**Key behavior:** Even if the source file is already inside `requirements_docs/`, if it's not in the correct category subdirectory, it MUST be moved. The filename will also change to match the confirmed ID.

### Step 11: Write File

1. Write content with updated frontmatter to target location (using confirmed_id as filename)
2. If `needs_move` is True, delete the original file after successful write
3. If source was already at target, just update frontmatter in place

### Step 12: Offer Design Review (if metaswarm available)

**Only if `METASWARM_AVAILABLE = true` AND `metaswarm.features.design_review = true`:**

Ask the user:
> "Run multi-agent design review on this imported requirement? [y/N]"

If yes:
> Run: `/review-design`
> Append review feedback to the requirement's Notes section.

### Step 13: Update Roadmap (Incremental)

Add to master_roadmap.md without full re-discovery.

**IMPORTANT: Do not modify table structure.** Match the existing column format exactly.

1. Find the appropriate category section (e.g., `### Lexical Editor`)
2. Look at the existing table format in that section
3. Add a new row matching that exact format:
   ```
   | 📋 | {PRIORITY} | {display_name} | 0 |
   ```
4. Update the category completion percentage in the section header
5. Update the Status Summary counts at the top (increment "Not Started" count)

**Do NOT:**
- Add new columns to tables
- Change table structure
- Modify `.roadmap_config.json` prefix mappings (frontmatter category is authoritative)

### Step 14: Report Success

Print a clean summary:

```
✓ Imported: {req_id}
  File:     requirements_docs/{category}/{req_id}.md
  Category: {category}
  Priority: {priority}
  Status:   not_started (added to roadmap)
```

If file was moved:
```
  Moved from: {original_path}
```

If --supersedes was used:
```
  Archived: {old_id} (superseded)
```

{% endif %}

{% elif action == "list" %}

## List Requirements

**Filter:** {{ details }}

### Step 1: Scan Requirements

Glob `.agent_process/requirements_docs/**/*.md` — exclude files matching `_TEMPLATE_*`.

For each file, parse YAML frontmatter to extract:
- `id` (required — skip files without it)
- `type` (must be `requirement` — skip others)
- `status` (default: `not_started`)
- `category` (default: `uncategorized`)
- `priority` (default: `MEDIUM`)

Also extract the first `# ` heading as the display title.

### Step 2: Apply Filter

If `{{ details }}` is provided, filter to requirements where `category` matches (case-insensitive).

### Step 3: Display

Group by category, sort by priority within each group (CRITICAL → HIGH → MEDIUM → LOW).

**Status icons:**
- ✅ `approved` — Approved by orchestrator
- 🔍 `completed` — Implementation done, awaiting review
- 🚧 `in_progress` — Work underway
- ❌ `blocked` — External blocker
- 📋 `not_started` — Not yet started
- 🗄️ `archived` — Archived

**Format:**

```
## Requirements Overview

### {Category Name} ({completed_count}/{total_count} complete)

| Status | Priority | ID | Title |
|--------|----------|----|-------|
| ✅ | HIGH | lexical_epic_01 | Save state management |
| 🚧 | CRITICAL | lexical_epic_05 | Navigation overhaul |
| 📋 | MEDIUM | lexical_epic_08 | Plugin system |

### {Another Category} ({completed_count}/{total_count} complete)
...

---
**Summary:** {total} requirements | {approved} approved | {in_progress} active | {blocked} blocked | {not_started} pending
```

{% endif %}
