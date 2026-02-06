---
name: ap_project
description: Generic project roadmap and requirements management for .agent_process projects
argument-hint: init | discover | status | set-status | archive | archive-completed | add-todo | add-requirement | import-requirement | sync | report | help ["details"]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, TodoWrite]
arguments:
  - name: action
    required: true
    type: string
    description: |
      Action to perform:
      - init: Initialize roadmap infrastructure (empty or from discovery)
      - discover: Scan requirements_docs/ and work/, build/update roadmap
      - status: Show current project status summary
      - set-status: Manually set requirement status (complete|in-progress|blocked|on-hold)
      - archive: Archive a requirement (completed|abandoned|superseded|out-of-scope)
      - archive-completed: Move all approved work scopes from work/ to work_archive/approved/
      - add-todo: Add item to backlog
      - add-requirement: Create new requirement from template
      - import-requirement: Import existing file as requirement (adds frontmatter, standardizes name)
      - sync: Reconcile roadmap with actual work/ status
      - report: Generate stakeholder status report
      - help: Show detailed help for all commands
  - name: details
    required: false
    type: string
    description: |
      Additional details depending on action:
      - set-status: "<requirement_id> <status> [reason]"
      - archive: "<requirement_id> <type> [reason]"
      - add-todo: "description"
      - add-requirement: "name"
      - import-requirement: "file_path [--supersedes old_id]"
      - report: "type (executive|detailed|weekly)"
---

# Generic Project Management

**Purpose:** Manage project roadmap and requirements for any `.agent_process` project structure.

## Process Documentation

Before proceeding, familiarize yourself with the process documentation:
- **Naming conventions:** `.agent_process/process/naming_conventions.md` (IDs, files, categories)
- **Discovery process:** `.agent_process/process/roadmap_discovery.md`
- **Schema specification:** `.agent_process/process/roadmap_schema.md`
- **Update procedures:** `.agent_process/process/roadmap_update.md`

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
# Setup (run once)
/ap_project init                    # Initialize roadmap infrastructure
/ap_project discover                # Scan project and build roadmap

# Daily usage
/ap_project status                  # Check where things stand
/ap_project add-todo "Session expiry doesn't redirect to login"  # Prompts for details
/ap_project add-requirement "User authentication system"
/ap_project import-requirement "path/to/draft.md"  # Import existing file

# Status management
/ap_project set-status "lexical_epic_05 complete All tests passing"
/ap_project set-status "ai_radar_scope_18 blocked Waiting for API"
/ap_project archive "old_feature abandoned Replaced by new approach"

# Maintenance
/ap_project sync                    # Reconcile roadmap with work/ status
/ap_project report                  # Generate stakeholder report
/ap_project report "detailed"       # Specify report type

# Help
/ap_project help                    # Show all commands
```

## Current Action: {{ action }}

---

{% if action == "init" %}

## Initialize Roadmap Infrastructure

### Step 1: Check Current State

Check if roadmap already exists:

```bash
ls -la .agent_process/roadmap/ 2>/dev/null || echo "No roadmap directory found"
```

### Step 2: Create Directory Structure

Create the roadmap directory and initial files:

```bash
mkdir -p .agent_process/roadmap
```

### Step 3: Verify Requirement Frontmatter

**IMPORTANT:** For discovery to work efficiently, requirements should use YAML frontmatter:

```yaml
---
id: lexical_epic_06_save       # Used for matching work directories
category: lexical_editor       # Used for grouping
priority: HIGH                 # CRITICAL, HIGH, MEDIUM, LOW
---
# Requirements: Save Behavior
```

**Check how many requirements have frontmatter:**

```bash
# Count requirements with frontmatter
grep -l "^---" .agent_process/requirements_docs/**/*.md 2>/dev/null | wc -l
# Count total requirements
find .agent_process/requirements_docs -name "*.md" ! -path "*/_TEMPLATE_*" ! -path "*/bugs/*" | wc -l
```

**If most requirements lack frontmatter:** The discover step will fall back to path-based IDs, but this causes fuzzy matching issues with hierarchical structures. Consider running a migration to add frontmatter (see `/ap_project help frontmatter-migration`).

### Step 4: Create Initial Files

Create roadmap files with proper structure. Note: Previous versions used separate `work_scope_details.md` and `phase_status.md` files — these are **deprecated** and have been consolidated into `master_roadmap.md`.

**Master Roadmap** (consolidated format):
```markdown
# Project Roadmap

> **Last Updated:** [CURRENT_TIMESTAMP]
> **Discovery Source:** Not yet discovered
> **Requirements with Work:** 0 | **Complete:** 0 | **In Progress:** 0 | **Blocked:** 0

## Status Summary

**Overall Completion: 0%** (0/0 requirements with active work)

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ Complete | 0 | 0% |
| 🚧 In Progress | 0 | 0% |
| ❌ Blocked | 0 | 0% |
| 📋 Not Started | 0 | 0% |

## Category Breakdown

| Category | Complete | In Progress | Blocked | Completion |
|----------|----------|-------------|---------|------------|

*Run `/ap_project discover` to populate categories from existing project.*

## Active Work (In Progress)

| Requirement | Category | Work Scopes |
|-------------|----------|-------------|

*No active work discovered yet.*

## Blocked Items

| Requirement | Category | Work Scopes | Notes |
|-------------|----------|-------------|-------|

*No blocked items.*

## Matching Statistics

- **Total work directories:** 0
- **Direct matches (frontmatter IDs):** 0
- **Project mapping matches:** 0
- **Fuzzy matches:** 0
- **Orphaned work:** 0

## Requirements by Category

*Run `/ap_project discover` to populate requirements.*

---

*Generated by `/ap_project init` on [CURRENT_TIMESTAMP]*
```

**Backlog:**
```markdown
# Project Backlog

> Items not yet formal requirements.

## CRITICAL Priority

*Add items with `/ap_project add-todo "description"`*

## HIGH Priority

## MEDIUM Priority

## LOW Priority
```

**Configuration:**
```json
{
  "include_patterns": ["**/*.md"],
  "exclude_patterns": [
    "**/bugs/**",
    "**/_TEMPLATE_*",
    "**/artifacts/**"
  ],
  "priority_mapping": {
    "_comment": "Canonical values: CRITICAL, HIGH, MEDIUM, LOW. Legacy mappings normalize variants.",
    "CRITICAL": "CRITICAL",
    "HIGH": "HIGH",
    "MEDIUM": "MEDIUM",
    "LOW": "LOW",
    "P0": "CRITICAL",
    "P1": "HIGH",
    "P2": "MEDIUM",
    "High": "HIGH",
    "Medium": "MEDIUM",
    "Low": "LOW",
    "high": "HIGH",
    "medium": "MEDIUM",
    "low": "LOW"
  },
  "categories": {
    "auto_detect": true,
    "prefix_mappings": {
      "_comment": "Map requirement ID prefixes to categories. Only needed if auto_detect fails."
    }
  },
  "status_markers": {
    "_comment": "STANDARDIZED markers. All new results.md files MUST use these exact formats.",
    "complete": ["**Status:** COMPLETE", "**Status:** ✅ COMPLETE"],
    "blocked": ["**Status:** BLOCKED"],
    "in_progress": ["**Status:** IN_PROGRESS"],
    "failed": ["**Status:** FAILED"]
  },
  "project_mappings": {
    "work_to_requirement": {
      "_comment": "Only needed if requirements lack frontmatter IDs. Maps work dir names to requirement IDs."
    }
  },
  "status_overrides": {
    "_comment": "Runtime overrides from /ap_project set-status command."
  }
}
```

**NOTE:** Status markers are now STANDARDIZED. All `/ap_exec` iterations should use `**Status:** COMPLETE`, `**Status:** BLOCKED`, etc. This eliminates the need for discovery-based marker detection.

### Step 5: Offer Next Steps

Recommend next actions:
1. Run `/ap_project discover` to scan existing project
2. Or start adding requirements manually with `/ap_project add-requirement`

{% elif action == "discover" %}

## Discover Project Structure

### Step 1: Scan Requirements

Use Python for reliable cross-platform scanning. **Frontmatter is checked FIRST** for id, category, and priority.

```python
python3 << 'PYEOF'
import os
import re
import json
import yaml
from pathlib import Path

req_dir = Path(".agent_process/requirements_docs")
config_file = Path(".agent_process/roadmap/.roadmap_config.json")
exclude_patterns = ["bugs/", "_TEMPLATE_"]

# Load category prefix mappings from config (fallback only)
category_prefixes = {}
try:
    config = json.loads(config_file.read_text())
    category_prefixes = config.get("categories", {}).get("prefix_mappings", {})
except:
    pass

def parse_frontmatter(content):
    """Extract YAML frontmatter if present. Returns dict or None."""
    if not content.startswith('---'):
        return None
    try:
        # Find closing ---
        end_match = re.search(r'\n---\s*\n', content[3:])
        if not end_match:
            return None
        yaml_content = content[3:end_match.start() + 3]
        return yaml.safe_load(yaml_content)
    except:
        return None

def get_category_fallback(req_id, rel_path):
    """Determine category using prefix mappings first, then directory structure."""
    for prefix, cat in category_prefixes.items():
        if prefix.startswith("_"):
            continue
        if req_id.startswith(prefix):
            return cat
    parts = rel_path.parts
    return parts[0] if len(parts) > 1 else "root"

def get_path_based_id(rel_path):
    """Generate ID from path (fallback when no frontmatter id)."""
    return str(rel_path.with_suffix("")).replace("/", "_").replace("-", "_")

stats = {"with_frontmatter": 0, "without_frontmatter": 0}

for md_file in req_dir.rglob("*.md"):
    path_str = str(md_file)
    if any(exc in path_str for exc in exclude_patterns):
        continue

    rel_path = md_file.relative_to(req_dir)

    try:
        content = md_file.read_text()
    except:
        continue

    # FRONTMATTER FIRST - check for id, category, priority, archived status
    fm = parse_frontmatter(content)

    # Skip archived requirements
    if fm and fm.get("archived"):
        continue

    if fm and fm.get("id"):
        # Use frontmatter values (preferred)
        req_id = fm["id"]
        category = fm.get("category", get_category_fallback(req_id, rel_path))
        priority = fm.get("priority", "MEDIUM").upper()
        stats["with_frontmatter"] += 1
    else:
        # Fall back to path-based extraction
        req_id = get_path_based_id(rel_path)
        category = get_category_fallback(req_id, rel_path)
        priority_match = re.search(r'\*\*Priority[:\*]*\*?\s*(\w+)', content)
        priority = priority_match.group(1).upper() if priority_match else "MEDIUM"
        stats["without_frontmatter"] += 1

    # Read first heading for display name
    heading_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    display_name = heading_match.group(1) if heading_match else md_file.stem

    print(f"{req_id}|{category}|{priority}|{display_name[:50]}")

# Report frontmatter coverage
import sys
print(f"# Frontmatter: {stats['with_frontmatter']} with, {stats['without_frontmatter']} without", file=sys.stderr)
if stats["without_frontmatter"] > stats["with_frontmatter"]:
    print("# WARNING: Most requirements lack frontmatter. Consider adding frontmatter for better matching.", file=sys.stderr)
PYEOF
```

**What frontmatter provides:**
- `id:` - Explicit requirement ID (matches work directory names directly)
- `category:` - Explicit category (no prefix mapping needed)
- `priority:` - Explicit priority (no regex parsing needed)

**Fallback behavior** (when no frontmatter):
- ID generated from file path (e.g., `ai_radar/scope_18/requirements.md` → `ai_radar_scope_18_requirements`)
- Category from parent directory or prefix_mappings
- Priority from `**Priority:**` markdown pattern

### Step 2: Scan Work Directories

Use Python for robust iteration and status detection:

```python
python3 << 'PYEOF'
import os
import re
import json
from pathlib import Path
from datetime import datetime

work_dir = Path(".agent_process/work")
config_file = Path(".agent_process/roadmap/.roadmap_config.json")

# Load status markers from config
try:
    config = json.loads(config_file.read_text())
    status_markers = config.get("status_markers", {})
except:
    status_markers = {"complete": ["✅ COMPLETE"], "blocked": ["BLOCKED"]}

def get_iteration_status(content):
    """Detect status from results.md content using configured markers."""
    for marker in status_markers.get("complete", []):
        if marker in content:
            return "COMPLETE"
    for marker in status_markers.get("blocked", []):
        if marker in content:
            return "BLOCKED"
    for marker in status_markers.get("failed", []):
        if marker in content:
            return "FAILED"
    return "IN_PROGRESS"

def get_approval_state(plan_content):
    """Extract approval decision from iteration_plan.md.

    Returns tuple: (decision, state)
    - decision: APPROVE, ITERATE, PIVOT, BLOCK, or None
    - state: APPROVED, NEEDS_REVIEW, IN_PROGRESS, BLOCKED, or None
    """
    if not plan_content:
        return None, None

    # Look for Decision marker (e.g., "- Decision: ✅ APPROVE (2026-01-16)")
    decision_match = re.search(r'Decision:\s*(?:✅|🔄|🔀|🚫)?\s*(APPROVE|ITERATE|PIVOT|BLOCK)', plan_content, re.IGNORECASE)
    if decision_match:
        decision = decision_match.group(1).upper()
        if decision == "APPROVE":
            return decision, "APPROVED"
        elif decision in ["ITERATE", "PIVOT"]:
            return decision, "NEEDS_REVIEW"
        elif decision == "BLOCK":
            return decision, "BLOCKED"

    return None, None

def get_latest_iteration(work_path):
    """Find the latest iteration directory (handles two-level iteration model).

    Iteration model:
    - Major iterations: iteration_01, iteration_02, iteration_03 (criteria changes via PIVOT)
    - Sub-iterations: iteration_01_a, iteration_01_b (minor fixes via ITERATE)

    Sorting by name works correctly:
    iteration_01 < iteration_01_a < iteration_01_b < iteration_02 < iteration_02_a
    """
    iterations = [d for d in work_path.iterdir() if d.is_dir() and d.name.startswith("iteration_")]
    if not iterations:
        return None, 0
    iterations.sort(key=lambda x: x.name)
    return iterations[-1], len(iterations)

for scope_dir in work_dir.iterdir():
    if not scope_dir.is_dir():
        continue

    scope_id = scope_dir.name

    # Check iteration_plan.md for approval state (orchestrator decision)
    plan_file = scope_dir / "iteration_plan.md"
    approval_decision = None
    scope_state = None
    if plan_file.exists():
        try:
            plan_content = plan_file.read_text()
            approval_decision, scope_state = get_approval_state(plan_content)
        except:
            pass

    # Get latest iteration info
    latest_iter, iter_count = get_latest_iteration(scope_dir)

    if not latest_iter:
        # No iterations yet - scope planned but not executed
        state = scope_state or "NOT_STARTED"
        print(f"{scope_id}|0|{state}|||{approval_decision or 'PENDING'}")
        continue

    # Check iteration results
    results_file = latest_iter / "results.md"
    if not results_file.exists():
        # Iteration started but no results yet
        state = scope_state or "IN_PROGRESS"
        print(f"{scope_id}|{iter_count}|{state}|{latest_iter.name}||{approval_decision or 'PENDING'}")
        continue

    try:
        results_content = results_file.read_text()
        iter_status = get_iteration_status(results_content)
        mtime = datetime.fromtimestamp(results_file.stat().st_mtime).strftime("%Y-%m-%d")

        # Determine overall scope state
        # Priority: approval decision > iteration status
        if scope_state:
            # Orchestrator made a decision - use that
            final_state = scope_state
        elif iter_status == "COMPLETE":
            # Iteration complete but no orchestrator decision yet
            final_state = "NEEDS_REVIEW"
        else:
            # In progress or blocked at iteration level
            final_state = iter_status

    except:
        iter_status = "IN_PROGRESS"
        final_state = scope_state or "IN_PROGRESS"
        mtime = ""

    print(f"{scope_id}|{iter_count}|{final_state}|{latest_iter.name}|{mtime}|{approval_decision or 'PENDING'}")
PYEOF
```

**Output format (pipe-delimited):**
```
{scope_id}|{iter_count}|{final_state}|{latest_iter_name}|{mtime}|{approval_decision}
```

**Fields:**
1. `scope_id` - Work scope directory name
2. `iter_count` - Total number of iterations (major + sub)
3. `final_state` - Overall scope status: APPROVED, NEEDS_REVIEW, IN_PROGRESS, BLOCKED, NOT_STARTED
4. `latest_iter_name` - Most recent iteration directory name (e.g., iteration_01_b)
5. `mtime` - Last modified date of results.md (YYYY-MM-DD)
6. `approval_decision` - Orchestrator decision from iteration_plan.md: APPROVE, ITERATE, PIVOT, BLOCK, or PENDING

**State determination logic:**
- **APPROVED** - iteration_plan.md shows "Decision: APPROVE"
- **NEEDS_REVIEW** - Iteration complete but no orchestrator decision yet, OR "Decision: ITERATE/PIVOT"
- **IN_PROGRESS** - Iteration in progress, no results yet
- **BLOCKED** - "Decision: BLOCK" or iteration blocked
- **NOT_STARTED** - No iterations executed yet (plan only)

**Why Python instead of shell:**
- Shell globs and pipes break with complex paths and special characters
- `sort -V` behaves inconsistently across platforms
- `while read` loops break when combined with pipes
- Python's pathlib handles edge cases reliably

### Step 3: Build Fuzzy Matches

Use Python to match work directories to requirements.

**Matching priority:**
1. **Frontmatter IDs** - If requirement has `id:` in frontmatter, use direct string match (best)
2. **Project mappings** - Explicit `work_to_requirement` entries in config (always wins)
3. **Fuzzy matching** - Algorithmic fallback (least reliable)

**With frontmatter IDs:** Most matching becomes direct and reliable. Fuzzy matching only kicks in for legacy requirements without frontmatter.

```python
python3 << 'PYEOF'
import json
import re
from pathlib import Path
from difflib import SequenceMatcher

config_file = Path(".agent_process/roadmap/.roadmap_config.json")

# Load configuration
config = json.loads(config_file.read_text())
work_to_req = config.get("project_mappings", {}).get("work_to_requirement", {})

# Requirements list (from Step 1 output - parse or pass as argument)
# For this script, assume requirements are passed via stdin or file
# Format: req_id|category|priority|name (one per line)

def normalize(s):
    """Normalize string for comparison."""
    return re.sub(r'[_\-\s]+', '_', s.lower()).strip('_')

def fuzzy_match(work_id, requirements):
    """Find best matching requirement for a work directory."""
    work_norm = normalize(work_id)

    # Strategy 1: Direct match
    for req_id in requirements:
        if normalize(req_id) == work_norm:
            return req_id, "direct", 1.0

    # Strategy 2: Remove scope patterns and retry
    # e.g., "ai_radar_scope_18_stability" -> "ai_radar_stability"
    work_no_scope = re.sub(r'_scope_\d+[a-z]?_?', '_', work_id)
    work_no_scope = re.sub(r'_+', '_', work_no_scope).strip('_')
    for req_id in requirements:
        if normalize(req_id) == normalize(work_no_scope):
            return req_id, "no_scope", 0.9

    # Strategy 3: Substring matching (either direction)
    for req_id in requirements:
        req_norm = normalize(req_id)
        if work_norm in req_norm or req_norm in work_norm:
            return req_id, "substring", 0.8

    # Strategy 4: Common prefix (at least 15 chars)
    best_match = None
    best_prefix_len = 0
    for req_id in requirements:
        req_norm = normalize(req_id)
        # Find common prefix length
        prefix_len = 0
        for i, (a, b) in enumerate(zip(work_norm, req_norm)):
            if a == b:
                prefix_len = i + 1
            else:
                break
        if prefix_len >= 15 and prefix_len > best_prefix_len:
            best_prefix_len = prefix_len
            best_match = req_id

    if best_match:
        return best_match, "prefix", 0.7

    # Strategy 5: Sequence matching (last resort, threshold 0.6)
    best_ratio = 0
    for req_id in requirements:
        ratio = SequenceMatcher(None, work_norm, normalize(req_id)).ratio()
        if ratio > best_ratio:
            best_ratio = ratio
            best_match = req_id

    if best_ratio >= 0.6:
        return best_match, "sequence", best_ratio

    return None, "orphan", 0

def match_all(work_dirs, requirements):
    """Match all work directories to requirements.

    Note: 'requirements' list comes from Step 1 output, which already uses
    frontmatter IDs where available. This means:
    - Requirements WITH frontmatter: ID is the explicit frontmatter id (e.g., 'lexical_epic_06_save')
    - Requirements WITHOUT frontmatter: ID is path-based (e.g., 'lexical_editor_epic_06_save_behavior_requirements')

    Work directories with names matching frontmatter IDs will get direct matches.
    """
    results = {
        "matched": [],      # {"work": ..., "req": ..., "method": ..., "confidence": ...}
        "orphans": [],      # {"work": ..., "status": ...}
        "from_mapping": 0,
        "from_direct": 0,   # Direct matches (likely frontmatter IDs)
        "from_fuzzy": 0
    }

    for work_id, status in work_dirs:
        # Check project_mappings FIRST (always wins)
        if work_id in work_to_req:
            results["matched"].append({
                "work": work_id,
                "req": work_to_req[work_id],
                "method": "project_mapping",
                "confidence": 1.0,
                "status": status
            })
            results["from_mapping"] += 1
            continue

        # Try fuzzy matching (includes direct match as first strategy)
        req_id, method, confidence = fuzzy_match(work_id, requirements)

        if req_id:
            results["matched"].append({
                "work": work_id,
                "req": req_id,
                "method": method,
                "confidence": confidence,
                "status": status
            })
            # Track direct matches separately (these are the frontmatter wins)
            if method == "direct":
                results["from_direct"] += 1
            else:
                results["from_fuzzy"] += 1
        else:
            results["orphans"].append({
                "work": work_id,
                "status": status
            })

    return results

# Output results as JSON for further processing
# In practice, this script runs after Steps 1 and 2 provide the data
print(json.dumps({
    "mapping_count": len(work_to_req),
    "_comment": "Run with actual data from Steps 1 and 2",
    "_metrics_explanation": {
        "from_direct": "Work dirs that matched requirement IDs exactly (frontmatter wins)",
        "from_mapping": "Work dirs matched via project_mappings config",
        "from_fuzzy": "Work dirs matched via algorithmic fallback (less reliable)",
        "orphans": "Work dirs with no matching requirement (need investigation)"
    }
}))
PYEOF
```

**How it works:**
1. **Project mappings checked first** - Entries in `project_mappings.work_to_requirement` always win
2. **Direct matching (frontmatter IDs)** - If requirement has frontmatter `id:` matching work dir name, it's a direct match
3. **Fuzzy matching fallback** - Only used for work dirs that don't match any frontmatter ID
4. **Reports source** - Each match indicates method (project_mapping, direct, substring, prefix, sequence)

**Goal:** With frontmatter IDs, most matches should be "direct" or "project_mapping". High "from_fuzzy" count suggests requirements need frontmatter migration.

### Step 3.5: LLM Critical Evaluation (REQUIRED)

**⚠️ Do not blindly trust algorithmic matching. Think about what you're seeing.**

Before finalizing discovery, critically evaluate:

1. **Do orphan counts make sense?** Completed orphans are almost always matching failures.
2. **Are completion percentages plausible?** 0% with many work dirs = something's wrong.
3. **Investigate completed orphans:** Read their results.md — which requirement do they belong to?

**If issues found:**
- Add explicit mappings to `.roadmap_config.json` under `project_mappings.work_to_requirement`
- Document genuinely orphan work in the orphan summary

See `.agent_process/process/roadmap_discovery.md` Phase 3.5 for full investigation protocol.

### Step 4: Aggregate Status

For each requirement:
- Count associated work scopes
- Determine aggregate status (Complete/In Progress/Not Started/Blocked)
- Calculate completion percentage

### Step 5: Generate Roadmap Files

Create or update:
- `master_roadmap.md` - consolidated view with status summary, category breakdown, active work, blocked items, matching statistics, and requirements by category

### Step 6: Migrate Existing Todo Items

**Migrate items from `todo_requirements.md` to `backlog.md`** (to sunset the old system):

```python
python3 << 'PYEOF'
import re
from pathlib import Path
from datetime import datetime

todo_file = Path(".agent_process/requirements_docs/todo_requirements.md")
backlog_file = Path(".agent_process/roadmap/backlog.md")

if not todo_file.exists():
    print("No todo_requirements.md found - skipping migration")
    exit(0)

content = todo_file.read_text()

# Parse todo items (various formats)
# Format 1: - [ ] **Item** - description
# Format 2: - [ ] Item description
# Format 3: ## Priority section followed by items
items_by_priority = {"CRITICAL": [], "HIGH": [], "MEDIUM": [], "LOW": []}
current_priority = "MEDIUM"

for line in content.split("\n"):
    # Check for priority headers
    priority_match = re.match(r'^##\s*(CRITICAL|HIGH|MEDIUM|LOW)', line, re.IGNORECASE)
    if priority_match:
        current_priority = priority_match.group(1).upper()
        continue

    # Check for todo items
    todo_match = re.match(r'^-\s*\[[ x]\]\s*(.+)', line)
    if todo_match:
        item_text = todo_match.group(1).strip()
        # Skip already completed items (checked boxes)
        if line.strip().startswith("- [x]"):
            continue
        items_by_priority[current_priority].append(item_text)

# Read existing backlog
existing_backlog = ""
if backlog_file.exists():
    existing_backlog = backlog_file.read_text()

# Generate migration section
migration_date = datetime.now().strftime("%Y-%m-%d")
total_migrated = sum(len(items) for items in items_by_priority.values())

if total_migrated > 0:
    print(f"Migrating {total_migrated} items from todo_requirements.md")

    # Append migrated items to backlog (marked with source)
    migration_section = f"\n\n<!-- Migrated from todo_requirements.md on {migration_date} -->\n"
    for priority in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        if items_by_priority[priority]:
            migration_section += f"\n## {priority} Priority (Migrated)\n\n"
            for item in items_by_priority[priority]:
                migration_section += f"- [ ] {item}\n"

    # Write updated backlog
    with open(backlog_file, "a") as f:
        f.write(migration_section)

    print(f"✅ Migrated to backlog.md")
    print(f"   Consider deleting todo_requirements.md after verifying migration")
else:
    print("No pending items found in todo_requirements.md")
PYEOF
```

**After migration:**
- New todos should use `/ap_project add-todo` (writes to `backlog.md`)
- `todo_requirements.md` can be deleted once migration is verified
- This consolidates to a single todo system

### Step 7: Update Requirements Frontmatter Status

**IMPORTANT:** After determining status from work directories, update each requirement file's frontmatter to match.

```python
python3 << 'PYEOF'
import re
import yaml
from pathlib import Path
from datetime import datetime

def parse_frontmatter(content):
    """Extract YAML frontmatter if present."""
    if not content.startswith('---'):
        return None, None

    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return None, None

    end_pos = end_match.end() + 3
    yaml_content = content[3:end_match.start() + 3]
    body = content[end_pos:]

    try:
        fm = yaml.safe_load(yaml_content) or {}
        return fm, body
    except:
        return None, None

def update_frontmatter_status(file_path, new_status):
    """Update status field in frontmatter. Returns True if updated."""
    content = file_path.read_text()
    fm, body = parse_frontmatter(content)

    if fm is None:
        return False

    # Normalize status values
    status_map = {
        "APPROVED": "complete",
        "COMPLETE": "complete",
        "NEEDS_REVIEW": "needs_review",
        "IN_PROGRESS": "in_progress",
        "BLOCKED": "blocked",
        "NOT_STARTED": "not_started"
    }
    normalized_status = status_map.get(new_status.upper(), new_status.lower().replace(" ", "_"))

    # Only update if status changed
    current_status = fm.get("status", "").lower().replace(" ", "_").replace("-", "_")
    if current_status == normalized_status:
        return False

    fm["status"] = normalized_status

    # Write updated frontmatter
    new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---\n" + body
    file_path.write_text(new_content)
    return True

# Read requirements and their statuses from previous discovery
# This assumes you've built a requirements dict with status info
req_dir = Path(".agent_process/requirements_docs")
roadmap_file = Path(".agent_process/roadmap/master_roadmap.md")

if not roadmap_file.exists():
    print("No roadmap found - skipping frontmatter update")
    exit(0)

# Parse roadmap to extract requirement statuses
roadmap_content = roadmap_file.read_text()
status_updates = {}

# Extract status from roadmap Requirements by Category sections
# Format: | ✅ | HIGH | requirement_name | 3 |
status_icons = {
    "✅": "complete",
    "🚧": "in_progress",
    "❌": "blocked",
    "📋": "not_started",
    "🔍": "needs_review",
    "⏸️": "on_hold"
}

for line in roadmap_content.split("\n"):
    if line.startswith("| ") and any(icon in line for icon in status_icons):
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 4:
            icon = parts[1]
            req_link = parts[3]  # Requirement column

            # Extract requirement ID from markdown link [display](path)
            match = re.search(r'\[([^\]]+)\]\(([^\)]+)\)', req_link)
            if match:
                req_path = match.group(2)
                status = next((s for i, s in status_icons.items() if i == icon), "not_started")
                status_updates[req_path] = status

# Update requirement files
updated_count = 0
for req_path, new_status in status_updates.items():
    file_path = Path(".agent_process") / req_path
    if file_path.exists():
        if update_frontmatter_status(file_path, new_status):
            updated_count += 1
            print(f"Updated {file_path.name}: {new_status}")

print(f"\n✅ Updated {updated_count} requirement frontmatter status fields")
PYEOF
```

**This ensures requirement files are the source of truth for status information.**

### Step 8: Report Discovery Results

Provide summary:
- Requirements found and categorized
- Work directories matched/orphaned
- Status distribution
- Frontmatter status fields updated
- Recommended next actions

{% elif action == "status" %}

## Show Project Status

### Step 1: Read Current Roadmap

Read and parse existing roadmap files:

```bash
cat .agent_process/roadmap/master_roadmap.md 2>/dev/null || echo "No roadmap found. Run '/ap_project init' first."
```

### Step 2: Extract Key Metrics

From the roadmap files, extract:
- Total requirements and completion percentages
- Current phase/category status
- Active work (In Progress items)
- Blocked items requiring attention
- Recent activity (Last 7 days)

### Step 2.5: Check Work Scope Existence

**CRITICAL:** Before suggesting next actions, verify which requirements have work scopes:

```bash
# For each requirement ID, check if work scope exists
for req_id in $(grep -o '\| [a-z_0-9]* \|' .agent_process/roadmap/master_roadmap.md | tr -d '| '); do
  if [[ -d ".agent_process/work/${req_id}" ]]; then
    echo "HAS_WORK: ${req_id}"
  else
    echo "NO_WORK: ${req_id}"
  fi
done
```

**Store this information** to use when generating next action recommendations in Step 4.

### Step 3: Display Summary

Present a concise status summary:

```
🎯 Project Status Summary

Overall: [XX]% complete ([N] of [M] requirements)
Active Work: [N] requirements in progress
Blocked: [N] items requiring attention
Recent: [N] completions in last 7 days

📊 By Category:
- [Category 1]: [XX]% ([N]/[M])
- [Category 2]: [XX]% ([N]/[M])
- [...]

🔥 Priority Items:
- [Item 1] (CRITICAL) - Status
- [Item 2] (HIGH) - Status
- [...]

📝 Recent Activity:
- [Requirement] completed on [Date]
- [Requirement] started on [Date]
```

### Step 4: Identify Action Items

**CRITICAL:** Check if work scope directories actually exist before suggesting `/ap_exec`.

Recommend next actions based on actual work scope state:

**For requirements with NO work scope (only requirements doc exists, no work/{scope}/ directory):**
- These need orchestrator planning FIRST
- Example output:
  ```
  📋 {requirement_id}
     Status: Needs orchestrator planning

     Next steps:
     1. Copy requirement to .agent_process/orchestration/01_plan_scope_prompt.md
     2. Run through orchestrator to create iteration plan
     3. Orchestrator creates work/{scope_name}/iteration_01/
     4. Then execute with /ap_exec {scope_name} iteration_01

     DO NOT run /ap_exec yet - no work scope exists
  ```
- DO NOT suggest `/ap_exec {requirement_id} iteration_01` (no work scope exists yet)
- Offer to populate the orchestration prompt file for the user

**For requirements WITH work scope (work/{scope_name}/ directory exists):**
- Verify directory exists: `ls .agent_process/work/{scope_name}/ 2>/dev/null`
- If exists:
  - Check iteration_plan.md for Decision marker (APPROVE, ITERATE, PIVOT, BLOCK)
  - Check latest iteration results.md for iteration status
  - **If iteration COMPLETE but no Decision:** `Needs orchestrator review`
    - Tell user to run orchestrator review (NOT /ap_project set-status)
    - Orchestrator adds Decision to iteration_plan.md
    - Next sync automatically picks up the decision
  - **If Decision = APPROVE:** `Scope complete ✓`
  - **If Decision = ITERATE:** `Continue with sub-iteration: /ap_exec {scope} {current}_a`
  - **If Decision = PIVOT:** `Continue with new iteration: /ap_exec {scope} {next_major}`
  - **If Decision = BLOCK:** `Blocked - resolve issues first`
  - **If iteration IN_PROGRESS:** `Continue: /ap_exec {scope} {current_iteration}`
- If doesn't exist: Treat as "NO work scope" case above

**NEVER suggest `/ap_project set-status` for orchestration-managed work.** Status comes from orchestrator decisions in iteration_plan.md, not manual overrides.

**For blocked items:**
- Identify what's blocking them
- Suggest next steps to unblock

**For backlog items:**
- Consider which should become formal requirements
- Suggest priority based on impact and effort

**Format for action items (show the mapping clearly):**
```
## Next Actions

### ✓ Approved & Complete

1. **Requirement:** rose2_patient_data_tab
   **Work Scope:** work/rose2_patient_data_tab/ ✓ (exists)
   **Status:** iteration_01_c (COMPLETE)
   **Approval:** APPROVE ✓ (2026-01-16)
   **Next:** Scope complete, no further action needed

### 🔍 Needs Review (iteration complete, awaiting decision)

2. **Requirement:** rose2_dashboard_enhancement
   **Work Scope:** work/rose2_dashboard_enhancement/ ✓ (exists)
   **Status:** iteration_02 (COMPLETE)
   **Approval:** PENDING (awaiting orchestrator review)
   **Next:** Review iteration_02 results with orchestrator

### 🚧 In Progress (continue execution)

3. **Requirement:** rose2_adopt_shared_data_patterns
   **Work Scope:** work/rose2_adopt_shared_data_patterns/ ✓ (exists)
   **Status:** iteration_01 (IN_PROGRESS)
   **Approval:** PENDING
   **Command:** /ap_exec rose2_adopt_shared_data_patterns iteration_01

### 📋 Needs Planning (no work scope yet)

4. **Requirement:** ailab_import_pattern_cleanup_02_prevail_scripts_and_mace_imports
   **Work Scope:** work/ailab_import_pattern_cleanup_02_prevail_scripts_and_mace_imports/ ✗ (missing)
   **Approval:** N/A (no work yet)
   **Next Steps:**
   - Copy requirement to .agent_process/orchestration/01_plan_scope_prompt.md
   - Run through orchestrator to create iteration plan
   - Orchestrator creates the work scope directory
   - Then execute with /ap_exec {scope_name} iteration_01

### ❌ Blocked

5. **Requirement:** {blocked_requirement}
   **Work Scope:** work/{scope}/ ✓ (exists)
   **Status:** iteration_01 (BLOCKED)
   **Approval:** BLOCK
   **Blocker:** {description}
   **Next Steps:** Resolve blocker first
```

**Key principle:** Show requirement ID, work scope path, approval state, and existence check to make status completely clear.

{% elif action == "add-todo" %}

## Add Backlog Item

**User Input:** {{ details }}

### Step 1: Validate Input

Ensure description is provided:
{% if not details %}
Error: Please provide a description for the todo item.
Usage: `/ap_project add-todo "Fix the login bug on mobile"`
{% endif %}

### Step 2: Gather Item Details

**Use AskUserQuestion to collect structured information:**

Ask about the item to build a complete backlog entry:

1. **Priority** - How urgent is this?
   - CRITICAL: Blocking other work or critical bug
   - HIGH: Important bug or user-impacting issue
   - MEDIUM: Useful improvement or non-critical bug
   - LOW: Nice-to-have, cosmetic, or future consideration

2. **Type** - What kind of work is this?
   - Bug Fix: Something broken that needs fixing
   - Feature: New capability or functionality
   - Enhancement: Improvement to existing feature
   - Tech Debt: Code quality, refactoring, infrastructure

3. **Source** - Where did this come from?
   - User request with date
   - Bug report (with optional screenshot/reference path)
   - Iteration discovery (which iteration found it)
   - Code review or testing

4. **Brief Description** - 1-3 sentences explaining:
   - What's the problem or what's needed?
   - What's the impact if not addressed?

5. **Acceptance Criteria** - How do we know it's done?
   - 2-5 specific, testable criteria
   - Written as checkboxes

6. **References** (optional):
   - Bug reference file path
   - Screenshot path
   - Related files or components

### Step 3: Check for Related/Duplicate Items

**Before adding, scan existing backlog for potential duplicates or related items.**

Read `.agent_process/roadmap/backlog.md` and search for items that:
- Have similar titles or keywords
- Address the same component/feature area
- Describe overlapping problems or solutions
- Could be consolidated into a single, more comprehensive item

**If related items found, use AskUserQuestion:**

```
Found potentially related backlog item(s):

1. "Save Now Button State Bug" (MEDIUM priority)
   - Also involves state not updating correctly after song operations

Options:
```

Present these choices:
1. **Consolidate** - Merge the new item into the existing one (update existing entry with additional context/criteria)
2. **Replace** - Remove the original and add the new item (if new item is more comprehensive)
3. **Add separately** - Keep both items as distinct work (if they're related but different enough)
4. **Cancel** - Don't add the new item (if it's truly a duplicate)

**Consolidation behavior:**
- Preserve the higher priority of the two items
- Merge acceptance criteria (deduplicate identical criteria)
- Combine descriptions into a more comprehensive one
- Keep all references (bug files, screenshots) from both
- Note in the entry: "Consolidated from: [original title]"

**Example consolidation:**
```markdown
### Save Button and State Synchronization Issues
**Source:** Bug reports (2026-01-02, 2026-01-18)
**Type:** Bug Fix
*Consolidated from: "Save Now Button State Bug"*

Multiple state synchronization bugs affect the save button display and related UI elements. The save button shows incorrect state after reopening songs, and related state updates don't reflect in the UI.

**Acceptance Criteria:**
- [ ] Save button correctly reflects actual save state on song load
- [ ] No false "unsaved changes" indicator after reopening
- [ ] State resets properly when navigating between songs
- [ ] [New criteria from consolidated item...]

---
```

### Step 4: Generate Backlog Entry

Create a structured entry following this format:

```markdown
### [Concise Title from Description]
**Source:** [Source type] ([date or context])
**Type:** [Bug Fix|Feature|Enhancement|Tech Debt]
**Bug Reference:** [path] (only if applicable)
**Screenshot:** [path] (only if applicable)

[1-3 sentence description of the issue/feature and its impact]

**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

---
```

### Step 5: Update Backlog

Read current `.agent_process/roadmap/backlog.md` and:

1. Find the appropriate priority section (CRITICAL, HIGH, MEDIUM, LOW)
2. Add the new entry at the end of that section (before the `---` divider)
3. Update the `Last Updated` timestamp in the header
4. If consolidating: remove the original entry and add the merged entry

**Example entry:**

```markdown
### Auto-Redirect to Login on Session Expiry
**Source:** User report (2026-01-02)
**Type:** Bug Fix

When session ends/times out, app doesn't redirect to login. User remains on page with failing API calls, causing confusion and broken UI state.

**Acceptance Criteria:**
- [ ] Detect session expiry from API 401 responses
- [ ] Automatically redirect to login page when session is invalid
- [ ] Show user-friendly message (not raw error)
- [ ] Preserve intended destination URL for post-login redirect
- [ ] Clear stale auth state in Redux/local storage

---
```

### Step 6: Confirm and Suggest Next Steps

After adding the item:

1. **Confirm addition** (varies by action taken):

   **New item added:**
   ```
   ✅ Added to backlog (HIGH priority):
   "Auto-Redirect to Login on Session Expiry"

   Type: Bug Fix
   Acceptance Criteria: 5 items
   ```

   **Consolidated with existing:**
   ```
   ✅ Consolidated into existing backlog item (HIGH priority):
   "Save Button and State Synchronization Issues"

   Merged with: "Save Now Button State Bug"
   Type: Bug Fix
   Acceptance Criteria: 6 items (3 new + 3 existing)
   ```

   **Replaced existing:**
   ```
   ✅ Replaced backlog item (HIGH priority):
   "Comprehensive State Sync Fix" replaces "Save Now Button State Bug"

   Type: Bug Fix
   Acceptance Criteria: 5 items
   ```

2. **Suggest next steps based on complexity:**
   - **Simple fix:** "This looks like a focused bug fix. Ready to work on when prioritized."
   - **Complex feature:** "This might need a formal requirement. Consider `/ap_project add-requirement` to define scope and acceptance criteria in more detail."
   - **AI-related:** "This involves AI integration. Consider running `/ap_design` to design the approach before implementation."
   - **After consolidation:** "The consolidated item now covers more scope. Review to ensure acceptance criteria are still achievable in one work unit."

{% elif action == "add-requirement" %}

## Create New Requirement

**Requirement Name:** {{ details }}

### Step 1: Validate Input

{% if not details %}
Error: Please provide a requirement name.
Usage: `/ap_project add-requirement "User authentication system"`
{% endif %}

### Step 2: Determine Location

Ask user where to place the requirement:
- Root level (`requirements_docs/{name}.md`)
- Existing category (`requirements_docs/{category}/{name}.md`)
- New category (`requirements_docs/{new_category}/{name}.md`)

### Step 3: Generate Requirement ID

Create normalized ID from name and location:
```
Name: "User authentication system"
Location: Root level
→ ID: user_authentication_system
→ File: requirements_docs/user_authentication_system.md
```

### Step 4: Create from Template

Use the requirement template from `.agent_process/requirements_docs/_TEMPLATE_requirements.md`:

```markdown
# Requirements: {{ details }}

**Date:** {{ current_date }}
**Author:** {{ git_author }}
**Priority:** [CRITICAL | HIGH | MEDIUM | LOW]

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

### Step 5: Update Roadmap

Add new requirement to master roadmap with NOT_STARTED status.

### Step 6: Suggest Next Steps

Recommend:
- Fill in the requirement details with acceptance criteria and scope
- Set appropriate priority based on impact and effort
- **Use orchestrator planning workflow** when ready:
  1. Copy requirement content to `.agent_process/orchestration/01_plan_scope_prompt.md`
  2. Run through orchestrator to create iteration plan with validation
  3. Orchestrator will create work scope directory and iteration_01/
  4. Then use `/ap_exec {scope_name} iteration_01` to execute the plan
- If criteria change after review, use PIVOT to create iteration_02, etc.

**Note:** Do NOT run `/ap_exec` directly - orchestrator must plan the scope first.

{% elif action == "import-requirement" %}

## Import Existing File as Requirement

**Input:** {{ details }}

Import an existing markdown file as a formal requirement. Adds frontmatter if missing, standardizes the filename, and adds to roadmap.

**Reference:** `.agent_process/process/naming_conventions.md`

### Step 1: Parse Input

{% if not details %}
**Error:** Please provide a file path.

**Usage:**
```bash
/ap_project import-requirement "path/to/file.md"
/ap_project import-requirement "path/to/file.md --supersedes old_requirement_id"
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
    if "lexical" in content_lower or "editor" in content_lower:
        inferred_category = "lexical_editor"
        category_source = "content mentions 'lexical' or 'editor'"
    elif "ai radar" in content_lower or "feedback" in content_lower:
        inferred_category = "ai_radar"
        category_source = "content mentions 'ai radar' or 'feedback'"
    elif "word tool" in content_lower or "collection" in content_lower:
        inferred_category = "word_tools"
        category_source = "content mentions 'word tool' or 'collection'"
    elif "test" in content_lower or "quality" in content_lower:
        inferred_category = "code_quality"
        category_source = "content mentions 'test' or 'quality'"
    else:
        inferred_category = "uncategorized"
        category_source = "no category keywords found"

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
2. Other standard categories as applicable (lexical_editor, ai_radar, word_tools, code_quality, song_settings, infrastructure)
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
category: {confirmed_category}
status: not_started
priority: {confirmed_priority}
supersedes: {old_id if --supersedes else omit}
---
```

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

**Key behavior:** Even if the source file is already inside `requirements_docs/`, if it's not in the correct category subdirectory, it MUST be moved. The filename will also change to match the confirmed ID. For example:
- `requirements_docs/lexical_save_state_navigation.md` with confirmed ID `lexical_epic_08_navigation`
- → Move to `requirements_docs/lexical_editor/lexical_epic_08_navigation.md`

### Step 11: Write File

1. Write content with updated frontmatter to target location (using confirmed_id as filename)
2. If `needs_move` is True, delete the original file after successful write
3. If source was already at target, just update frontmatter in place

### Step 12: Update Roadmap (Incremental)

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

### Step 13: Report Success

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

{% elif action == "sync" %}

## Sync Roadmap with Reality

### Step 1: Backup Current State

Create backup of existing roadmap:

```bash
cp -r .agent_process/roadmap .agent_process/roadmap_backup_$(date +%Y%m%d_%H%M%S)
```

### Step 2: Full Re-Discovery

Run complete discovery process:
1. Re-scan all requirements_docs/ files
2. Re-scan all work/ directories
3. Re-build fuzzy matches
4. Re-calculate all status aggregations

### Step 3: Compare with Current State

Identify discrepancies:
- Requirements in roadmap but not found in discovery
- Work directories not reflected in roadmap
- Status mismatches between results.md and roadmap

### Step 4: Report Discrepancies

Show user what changed:
```
🔍 Sync Analysis

New requirements found: [N]
- [requirement_1]
- [requirement_2]

New work directories: [N]
- [work_scope_1] (status: Complete)
- [work_scope_2] (status: In Progress)

Status changes: [N]
- [requirement] In Progress → Complete
- [requirement] Not Started → In Progress

Orphaned work: [N]
- [work_scope] (no matching requirement)

Missing work: [N]
- [requirement] (has requirement but no work)
```

### Step 5: Update All Files

Regenerate roadmap from current state:
- `master_roadmap.md` - consolidated view with all status information

Preserve configuration in `.roadmap_config.json` (category prefix_mappings, project_mappings, status_overrides).

### Step 5.5: Update Requirements Frontmatter Status

**IMPORTANT:** After reconciling status, update each requirement file's frontmatter to match the discovered/computed status.

Use the same Python script from `discover` Step 7 to update frontmatter status fields based on the regenerated roadmap:

```python
python3 << 'PYEOF'
import re
import yaml
from pathlib import Path

def parse_frontmatter(content):
    """Extract YAML frontmatter if present."""
    if not content.startswith('---'):
        return None, None

    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return None, None

    end_pos = end_match.end() + 3
    yaml_content = content[3:end_match.start() + 3]
    body = content[end_pos:]

    try:
        fm = yaml.safe_load(yaml_content) or {}
        return fm, body
    except:
        return None, None

def update_frontmatter_status(file_path, new_status):
    """Update status field in frontmatter. Returns True if updated."""
    content = file_path.read_text()
    fm, body = parse_frontmatter(content)

    if fm is None:
        return False

    # Normalize status values
    status_map = {
        "APPROVED": "complete",
        "COMPLETE": "complete",
        "NEEDS_REVIEW": "needs_review",
        "IN_PROGRESS": "in_progress",
        "BLOCKED": "blocked",
        "NOT_STARTED": "not_started"
    }
    normalized_status = status_map.get(new_status.upper(), new_status.lower().replace(" ", "_"))

    # Only update if status changed
    current_status = fm.get("status", "").lower().replace(" ", "_").replace("-", "_")
    if current_status == normalized_status:
        return False

    fm["status"] = normalized_status

    # Write updated frontmatter
    new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---\n" + body
    file_path.write_text(new_content)
    return True

roadmap_file = Path(".agent_process/roadmap/master_roadmap.md")

if not roadmap_file.exists():
    print("No roadmap found - skipping frontmatter update")
    exit(0)

# Parse roadmap to extract requirement statuses
roadmap_content = roadmap_file.read_text()
status_updates = {}

# Extract status from roadmap Requirements by Category sections
status_icons = {
    "✅": "complete",
    "🚧": "in_progress",
    "❌": "blocked",
    "📋": "not_started",
    "🔍": "needs_review",
    "⏸️": "on_hold"
}

for line in roadmap_content.split("\n"):
    if line.startswith("| ") and any(icon in line for icon in status_icons):
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 4:
            icon = parts[1]
            req_link = parts[3]

            match = re.search(r'\[([^\]]+)\]\(([^\)]+)\)', req_link)
            if match:
                req_path = match.group(2)
                status = next((s for i, s in status_icons.items() if i == icon), "not_started")
                status_updates[req_path] = status

# Update requirement files
updated_count = 0
for req_path, new_status in status_updates.items():
    file_path = Path(".agent_process") / req_path
    if file_path.exists():
        if update_frontmatter_status(file_path, new_status):
            updated_count += 1
            print(f"Updated {file_path.name}: {new_status}")

print(f"\n✅ Updated {updated_count} requirement frontmatter status fields")
PYEOF
```

**This ensures requirement files stay in sync with the discovered status.**

### Step 6: Validate Consistency

Check that updated roadmap is consistent:
- Percentages add up correctly
- Work scope counts match directories
- Status logic is valid
- Timestamps are reasonable

### Step 7: Suggest Next Actions

**IMPORTANT:** `/ap_project sync` is a discovery and status tool only. It does NOT create work directories or plan scopes.

Based on sync findings, provide guidance:

**For requirements with MISSING WORK (requirement exists but no work scope):**

Show which requirements need planning with clear mapping:
```
📋 Requirements Ready for Planning:

1. **Requirement:** ailab_import_pattern_cleanup_02_prevail_scripts_and_mace_imports
   **Expected Work Scope:** work/ailab_import_pattern_cleanup_02/ ✗ (missing)
   **Status:** Needs orchestrator planning first
   **Approval:** N/A (no work scope yet)

   Next steps:
   1. Copy requirement to .agent_process/orchestration/01_plan_scope_prompt.md
   2. Run through orchestrator to create iteration plan
   3. Orchestrator creates work/{scope_name}/iteration_01/
   4. Then execute with /ap_exec {scope_name} iteration_01

   DO NOT run /ap_exec yet - no work scope directory exists.

2. **Requirement:** {requirement_id_2}
   **Expected Work Scope:** work/{requirement_id_2}/ ✗ (missing)
   **Approval:** N/A (no work scope yet)
   ...
```

**Offer to help:**
```
Would you like me to populate the orchestration prompt for one of these? (yes/no)

If yes, I'll:
1. Update .agent_process/orchestration/01_plan_scope_prompt.md with the requirement
2. You run it through your orchestrator (separate agent/process)
3. Orchestrator creates the work scope and iteration_01/
4. Then you can execute with /ap_exec {scope_name} iteration_01
```

**CRITICAL - Do NOT suggest:**
- ❌ `/ap_project set-status "{requirement} complete"` - Bypasses orchestration
- ❌ "Mark as complete" - Orchestrator makes this decision
- ❌ Manual status changes for orchestrated work

**DO suggest:**
- ✓ "Run orchestrator review on iteration_01_a"
- ✓ "Orchestrator will add Decision: APPROVE to iteration_plan.md"
- ✓ "Next sync will automatically update status"

**For requirements IN PROGRESS (incomplete work scopes):**

Show clear mapping between requirement, work scope, and approval state:
```
🚧 In Progress Work:

1. **Requirement:** rose2_adopt_shared_data_patterns
   **Work Scope:** work/rose2_adopt_shared_data_patterns/ ✓ (exists)
   **Current:** iteration_01 (COMPLETE)
   **Approval:** NEEDS_REVIEW (no orchestrator decision yet)
   **Next:** Review with orchestrator before continuing

2. **Requirement:** infrastructure_cleanup
   **Work Scope:** work/infrastructure_cleanup/ ✓ (exists)
   **Current:** iteration_01_b (IN_PROGRESS)
   **Approval:** ITERATE (orchestrator requested fixes)
   **Next:** Complete iteration_01_b, then review again

3. **Requirement:** {requirement_3}
   **Work Scope:** work/{scope_3}/ ✓ (exists)
   **Current:** {iteration} ({iter_status})
   **Approval:** APPROVED ✓
   **Status:** Scope complete, ready for next requirement
```

**Approval state meanings:**
- **PENDING** - Iteration not complete yet, no decision needed
- **NEEDS_REVIEW** - Iteration complete, awaiting orchestrator review
- **ITERATE** - Orchestrator wants fixes in sub-iteration (e.g., _a, _b)
- **PIVOT** - Orchestrator changed criteria, new major iteration needed (e.g., 02)
- **APPROVE** - Orchestrator approved scope, work complete ✓
- **BLOCK** - Cannot proceed, scope blocked

**For ORPHANED WORK (work directory but no matching requirement):**
```
⚠️  Orphaned Work Detected:

- {work_scope_1} (no matching requirement found)

Consider:
1. Create requirement: `/ap_project add-requirement` to document this work
2. Update project_mappings in .roadmap_config.json if naming mismatch
3. Archive if work is obsolete
```

{% elif action == "report" %}

## Generate Status Report

### Step 1: Determine Report Type

{% if details %}
Report type: {{ details }}
{% else %}
Default to stakeholder summary report.
{% endif %}

### Step 2: Gather Data

Read all roadmap files and extract:
- Overall completion statistics
- Phase/category breakdown
- Recent accomplishments (last 2 weeks)
- Upcoming priorities
- Risks and blockers

### Step 3: Generate Report

Create stakeholder-friendly markdown report:

```markdown
# Project Status Report

**Date:** {{ current_date }}
**Period:** [Previous report date] - [Current date]

## Executive Summary

[1-2 paragraph summary of overall progress, key accomplishments, and outlook]

## Progress Overview

📊 **Overall Progress:** [XX]% complete ([N] of [M] requirements)

### By Phase/Category
- **[Category 1]:** [XX]% complete ([N]/[M]) - [Status description]
- **[Category 2]:** [XX]% complete ([N]/[M]) - [Status description]
- **[...]**

## Recent Accomplishments

✅ **Completed Requirements:**
- **[Requirement 1]** - [Brief description]
- **[Requirement 2]** - [Brief description]

## Current Focus

🚧 **In Progress:**
- **[Requirement 1]** - [Status/blockers]
- **[Requirement 2]** - [Status/blockers]

## Upcoming Priorities

📋 **Next Quarter:**
1. **[Priority 1]** - [Why important]
2. **[Priority 2]** - [Why important]
3. **[Priority 3]** - [Why important]

## Risks & Blockers

⚠️ **Current Blockers:**
- **[Blocker 1]** - [Impact and mitigation]
- **[Blocker 2]** - [Impact and mitigation]

🔴 **Risks to Track:**
- **[Risk 1]** - [Probability and impact]
- **[Risk 2]** - [Probability and impact]

## Metrics

- **Velocity:** [Requirements/work scopes completed per week/month]
- **Quality:** [Rework percentage, iteration counts]
- **Predictability:** [Estimation accuracy]
```

### Step 4: Save Report

Save to `.agent_process/reports/status_{{ timestamp }}.md`

### Step 5: Suggest Distribution

Recommend sharing the report with stakeholders and setting up recurring generation.

{% elif action == "set-status" %}

## Set Requirement Status

Manually override the status of a requirement. Manual overrides always win over automatic discovery.

### Step 1: Parse Arguments

Extract from `{{ details }}`:
- **requirement_id**: The requirement to update (required)
- **status**: One of `complete`, `in-progress`, `blocked`, `on-hold`, `needs-review` (required)
- **reason**: Why the status is being changed (optional but recommended)

**Example formats:**
```
"lexical_epic_05_stress_part_2 complete Implementation finished"
"ai_radar_scope_18 blocked Waiting for backend API"
"code_quality_epic_07 on-hold Deprioritized for Q2"
```

### Step 2: Validate Requirement Exists

```python
python3 << 'PYEOF'
import json
from pathlib import Path

req_id = "{{ details }}".split()[0] if "{{ details }}" else ""
roadmap = Path(".agent_process/roadmap/master_roadmap.md")

if not roadmap.exists():
    print("ERROR: No roadmap found. Run '/ap_project init' first.")
    exit(1)

content = roadmap.read_text()
if req_id and req_id not in content:
    print(f"WARNING: Requirement '{req_id}' not found in roadmap.")
    print("Check spelling or run '/ap_project discover' to update.")
else:
    print(f"OK: Requirement '{req_id}' found.")
PYEOF
```

### Step 3: Validate Status Transition

**Validation rules:**

| Current Status | Allowed Transitions | Requires Confirmation |
|----------------|---------------------|----------------------|
| not-started | in-progress, blocked, on-hold | No |
| in-progress | complete, blocked, on-hold, needs-review | complete without work dirs |
| blocked | in-progress, on-hold | No |
| on-hold | in-progress, not-started | No |
| complete | in-progress (reopening) | Yes - requires reason |

**Warning conditions (proceed with confirmation):**
- Marking `complete` when no work directories exist
- Marking `complete` when work directories show IN_PROGRESS
- Reopening a `complete` requirement

### Step 4: Update Status Override

Add to `.agent_process/roadmap/.roadmap_config.json` under `status_overrides`:

```json
{
  "status_overrides": {
    "requirement_id": {
      "status": "complete",
      "reason": "User-provided reason",
      "set_by": "manual",
      "set_at": "2026-01-17T22:30:00Z"
    }
  }
}
```

### Step 5: Log to Audit Trail

Append to `.agent_process/roadmap/.roadmap_audit.jsonl`:

```json
{"timestamp": "2026-01-17T22:30:00Z", "action": "set-status", "requirement": "req_id", "old_status": "in-progress", "new_status": "complete", "reason": "User reason"}
```

### Step 6: Update Roadmap Display

Re-run discovery aggregation to update `master_roadmap.md` with the new status (respecting manual override).

### Step 6.5: Update Requirement Frontmatter Status

**IMPORTANT:** Update the requirement file's frontmatter to match the manually set status.

```python
python3 << 'PYEOF'
import re
import yaml
import json
from pathlib import Path

req_id = "{{ details }}".split()[0] if "{{ details }}" else ""
new_status = "{{ details }}".split()[1] if len("{{ details }}".split()) > 1 else ""

def parse_frontmatter(content):
    """Extract YAML frontmatter if present."""
    if not content.startswith('---'):
        return None, None

    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return None, None

    end_pos = end_match.end() + 3
    yaml_content = content[3:end_match.start() + 3]
    body = content[end_pos:]

    try:
        fm = yaml.safe_load(yaml_content) or {}
        return fm, body
    except:
        return None, None

def update_frontmatter_status(file_path, new_status):
    """Update status field in frontmatter."""
    content = file_path.read_text()
    fm, body = parse_frontmatter(content)

    if fm is None:
        print(f"WARNING: {file_path.name} has no frontmatter - cannot update status")
        return False

    # Normalize status value
    normalized_status = new_status.lower().replace(" ", "_").replace("-", "_")

    old_status = fm.get("status", "not_started")
    fm["status"] = normalized_status

    # Write updated frontmatter
    new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---\n" + body
    file_path.write_text(new_content)

    print(f"✅ Updated frontmatter: {file_path.name}")
    print(f"   status: {old_status} → {normalized_status}")
    return True

# Find requirement file by ID
req_dir = Path(".agent_process/requirements_docs")
req_file = None

# Search for file matching requirement ID
for candidate in req_dir.rglob("*.md"):
    if candidate.stem == req_id:
        req_file = candidate
        break

    # Also check frontmatter id field
    try:
        content = candidate.read_text()
        fm, _ = parse_frontmatter(content)
        if fm and fm.get("id") == req_id:
            req_file = candidate
            break
    except:
        pass

if req_file and req_file.exists():
    update_frontmatter_status(req_file, new_status)
else:
    print(f"WARNING: Could not find requirement file for '{req_id}'")
    print(f"Searched in: {req_dir}")
PYEOF
```

**This ensures the requirement file's frontmatter status stays in sync with the manual override.**

### Step 7: Confirm Change

Report the change:
```
✅ Status updated: lexical_epic_05_stress_part_2
   Previous: in-progress
   New: complete
   Reason: Implementation finished
   Logged to: .roadmap_audit.jsonl
   Frontmatter: Updated in requirement file
```

{% elif action == "archive" %}

## Archive Requirement

Remove a requirement from the active roadmap without deleting it. Archived requirements are preserved for historical reference.

### Step 1: Parse Arguments

Extract from `{{ details }}`:
- **requirement_id**: The requirement to archive (required)
- **archive_type**: One of `completed`, `abandoned`, `superseded`, `out-of-scope` (required)
- **reason**: Why the requirement is being archived (optional but recommended)

**Example formats:**
```
"old_feature_requirement abandoned Superseded by new approach"
"lexical_epic_00 completed All work finished and verified"
"experimental_feature out-of-scope Not aligned with product direction"
```

### Step 2: Validate Requirement Exists

Same validation as set-status.

### Step 3: Pre-Archive Validation

**Check for related work directories:**
```python
python3 << 'PYEOF'
import json
from pathlib import Path

req_id = "{{ details }}".split()[0] if "{{ details }}" else ""
archive_type = "{{ details }}".split()[1] if len("{{ details }}".split()) > 1 else "unknown"
work_dir = Path(f".agent_process/work")

# Archive type to folder mapping
type_to_folder = {
    "completed": "approved",
    "superseded": "superseded",
    "abandoned": "abandoned",
    "out-of-scope": "out-of-scope"
}
dest_folder = type_to_folder.get(archive_type, archive_type)

# Check if any work directories reference this requirement
related_work = [d.name for d in work_dir.iterdir() if d.is_dir() and req_id in d.name]

if related_work:
    print(f"INFO: Found {len(related_work)} related work directories:")
    for w in related_work[:5]:
        print(f"  - {w}")
    if len(related_work) > 5:
        print(f"  ... and {len(related_work) - 5} more")
    print(f"\nThese will be moved to: work_archive/{dest_folder}/")
else:
    print("INFO: No related work directories found in work/")
PYEOF
```

**Also check `.roadmap_config.json` project_mappings** for work directories that map to this requirement but don't contain the requirement ID in their name.

**Confirmation required for:**
- Archiving requirements with IN_PROGRESS work
- Archiving requirements other requirements depend on

### Step 4: Move to Archive

Create/update `.agent_process/roadmap/archived_roadmap.md`:

```markdown
# Archived Requirements

> Requirements removed from active tracking. Preserved for reference.

## Completed

| ID | Name | Archived Date | Notes |
|----|------|---------------|-------|
| [req_id] | [Name] | 2026-01-17 | [Reason] |

## Abandoned

| ID | Name | Archived Date | Reason |
|----|------|---------------|--------|

## Superseded

| ID | Name | Archived Date | Superseded By |
|----|------|---------------|---------------|

## Out of Scope

| ID | Name | Archived Date | Reason |
|----|------|---------------|--------|
```

### Step 5: Update Exclusions

Add to `.agent_process/roadmap/.roadmap_config.json` under `archived_requirements`:

```json
{
  "archived_requirements": [
    {
      "id": "requirement_id",
      "type": "abandoned",
      "reason": "Superseded by new approach",
      "archived_at": "2026-01-17T22:30:00Z",
      "related_work": ["work_dir_1", "work_dir_2"]
    }
  ]
}
```

### Step 6: Move Related Work Directories

**IMPORTANT:** Move all related work directories to the appropriate archive folder based on archive type.

**Archive folder mapping:**
| Archive Type | Destination Folder |
|--------------|-------------------|
| `completed` | `work_archive/approved/` |
| `superseded` | `work_archive/superseded/` |
| `abandoned` | `work_archive/abandoned/` |
| `out-of-scope` | `work_archive/out-of-scope/` |

**Steps:**
1. Create the destination folder if it doesn't exist:
   ```bash
   mkdir -p .agent_process/work_archive/{type}/
   ```

2. Move each related work directory using `git mv` to preserve history:
   ```bash
   git mv .agent_process/work/{work_dir} .agent_process/work_archive/{type}/
   ```

3. Update `archived_roadmap.md` to note the archive location for each work directory.

**Example for superseded requirement:**
```bash
mkdir -p .agent_process/work_archive/superseded
git mv .agent_process/work/lexical_epic_06_scope_01 .agent_process/work_archive/superseded/
git mv .agent_process/work/lexical_epic_06_scope_02 .agent_process/work_archive/superseded/
```

**Note:** Use `git mv` instead of `mv` to preserve file history for archaeology purposes.

### Step 7: Log to Audit Trail

Append to `.agent_process/roadmap/.roadmap_audit.jsonl`:

```json
{"timestamp": "2026-01-17T22:30:00Z", "action": "archive", "requirement": "req_id", "type": "abandoned", "reason": "User reason"}
```

### Step 8: Update Requirement Frontmatter

**IMPORTANT:** Mark the requirement file's frontmatter as archived.

```python
python3 << 'PYEOF'
import re
import yaml
from pathlib import Path
from datetime import datetime

req_id = "{{ details }}".split()[0] if "{{ details }}" else ""
archive_type = "{{ details }}".split()[1] if len("{{ details }}".split()) > 1 else ""
reason = " ".join("{{ details }}".split()[2:]) if len("{{ details }}".split()) > 2 else ""

def parse_frontmatter(content):
    """Extract YAML frontmatter if present."""
    if not content.startswith('---'):
        return None, None

    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return None, None

    end_pos = end_match.end() + 3
    yaml_content = content[3:end_match.start() + 3]
    body = content[end_pos:]

    try:
        fm = yaml.safe_load(yaml_content) or {}
        return fm, body
    except:
        return None, None

def update_frontmatter_archived(file_path, archive_type, reason):
    """Mark requirement as archived in frontmatter."""
    content = file_path.read_text()
    fm, body = parse_frontmatter(content)

    if fm is None:
        print(f"WARNING: {file_path.name} has no frontmatter - cannot update")
        return False

    # Add archive metadata
    fm["archived"] = True
    fm["archive_type"] = archive_type
    fm["archived_date"] = datetime.now().strftime("%Y-%m-%d")
    if reason:
        fm["archive_reason"] = reason

    # Set status based on archive type
    if archive_type == "completed":
        fm["status"] = "complete"
    else:
        fm["status"] = "archived"

    # Write updated frontmatter
    new_content = "---\n" + yaml.dump(fm, default_flow_style=False, sort_keys=False) + "---\n" + body
    file_path.write_text(new_content)

    print(f"✅ Updated frontmatter: {file_path.name}")
    print(f"   archived: true")
    print(f"   archive_type: {archive_type}")
    return True

# Find requirement file
req_dir = Path(".agent_process/requirements_docs")
req_file = None

for candidate in req_dir.rglob("*.md"):
    if candidate.stem == req_id:
        req_file = candidate
        break

    try:
        content = candidate.read_text()
        fm, _ = parse_frontmatter(content)
        if fm and fm.get("id") == req_id:
            req_file = candidate
            break
    except:
        pass

if req_file and req_file.exists():
    update_frontmatter_archived(req_file, archive_type, reason)
else:
    print(f"WARNING: Could not find requirement file for '{req_id}'")
PYEOF
```

**This marks the requirement file as archived so discovery can skip it.**

### Step 9: Update Roadmap

Re-run discovery to exclude archived requirements from active metrics.

### Step 10: Confirm Archive

Report the change:
```
📦 Requirement archived: old_feature_requirement
   Type: abandoned
   Reason: Superseded by new approach
   Related work preserved: 2 directories
   Frontmatter: Marked as archived
   Logged to: .roadmap_audit.jsonl

   To restore: /ap_project restore "old_feature_requirement"
```

{% elif action == "archive-completed" %}

## Archive Completed Work Scopes

Move all approved work scopes from `work/` to `work_archive/approved/`. This preserves git history and updates requirement frontmatter with archive location.

### Step 1: Ensure Archive Directory Exists

```bash
mkdir -p .agent_process/work_archive/approved
```

### Step 2: Scan for Approved Scopes

Find all work scopes with "Decision: APPROVE" in their iteration_plan.md:

```python
python3 << 'PYEOF'
import os
import re
import yaml
from pathlib import Path
from datetime import datetime

WORK_DIR = Path(".agent_process/work")
ARCHIVE_DIR = Path(".agent_process/work_archive/approved")
REQ_DIR = Path(".agent_process/requirements_docs")

def parse_frontmatter(content):
    """Extract YAML frontmatter from markdown content."""
    if not content.startswith('---'):
        return None
    try:
        end_match = re.search(r'\n---\s*\n', content[3:])
        if not end_match:
            return None
        yaml_content = content[3:end_match.start() + 3]
        return yaml.safe_load(yaml_content)
    except:
        return None

def is_approved(scope_dir):
    """Check if scope has Decision: APPROVE in iteration_plan.md."""
    plan_file = scope_dir / "iteration_plan.md"
    if not plan_file.exists():
        return False
    try:
        content = plan_file.read_text()
        if re.search(r'Decision:\s*(?:✅\s*)?APPROVE', content, re.IGNORECASE):
            return True
    except:
        pass
    return False

def get_approval_date(scope_dir):
    """Extract approval date from iteration_plan.md."""
    plan_file = scope_dir / "iteration_plan.md"
    if not plan_file.exists():
        return datetime.now().strftime("%Y-%m-%d")
    try:
        content = plan_file.read_text()
        # Look for date in decision line: "Decision: ✅ APPROVE (2026-01-16)"
        match = re.search(r'Decision:\s*(?:✅\s*)?APPROVE\s*\((\d{4}-\d{2}-\d{2})\)', content, re.IGNORECASE)
        if match:
            return match.group(1)
    except:
        pass
    return datetime.now().strftime("%Y-%m-%d")

def find_requirement_by_id(scope_id):
    """Find requirement file matching this scope ID."""
    for md_file in REQ_DIR.rglob("*.md"):
        if "_TEMPLATE_" in str(md_file) or "/bugs/" in str(md_file):
            continue
        try:
            content = md_file.read_text()
            fm = parse_frontmatter(content)
            if fm and fm.get("id") == scope_id:
                return md_file, fm
        except:
            continue
    return None, None

# Scan for approved scopes
approved_scopes = []
if WORK_DIR.exists():
    for scope_dir in sorted(WORK_DIR.iterdir()):
        if not scope_dir.is_dir():
            continue
        if is_approved(scope_dir):
            scope_id = scope_dir.name
            approval_date = get_approval_date(scope_dir)
            req_file, req_fm = find_requirement_by_id(scope_id)
            category = req_fm.get("category", "unknown") if req_fm else "unknown"
            approved_scopes.append({
                "scope_id": scope_id,
                "scope_dir": str(scope_dir),
                "approval_date": approval_date,
                "req_file": str(req_file) if req_file else None,
                "category": category
            })

# Output results
if not approved_scopes:
    print("NO_APPROVED_SCOPES")
else:
    print(f"FOUND:{len(approved_scopes)}")
    for scope in approved_scopes:
        print(f"SCOPE|{scope['scope_id']}|{scope['approval_date']}|{scope['category']}|{scope['req_file'] or 'NO_REQ'}")
PYEOF
```

### Step 3: Show Archive Plan

Display what will be archived and ask for confirmation:

```
📦 Archive Plan

Found [N] approved work scopes ready for archive:

| Scope ID | Approved Date | Category | Requirement |
|----------|---------------|----------|-------------|
| scope_1  | 2026-01-24    | lexical  | ✓ linked    |
| scope_2  | 2026-01-24    | ai_radar | ✓ linked    |
| scope_3  | 2026-01-23    | unknown  | ✗ no match  |

Actions to perform:
1. Move work scopes from work/ to work_archive/approved/ (using git mv)
2. Update linked requirement frontmatter with:
   - status: approved
   - approved_date: [date]
   - work_location: work_archive/approved/[scope]/
3. Generate/update completed_work.md
4. Create atomic git commit

Proceed with archive? (yes/no)
```

### Step 4: Execute Archive

If user confirms, run the archive operation:

```python
python3 << 'PYEOF'
import os
import re
import yaml
import subprocess
from pathlib import Path
from datetime import datetime
from collections import defaultdict

WORK_DIR = Path(".agent_process/work")
ARCHIVE_DIR = Path(".agent_process/work_archive/approved")
REQ_DIR = Path(".agent_process/requirements_docs")
ROADMAP_DIR = Path(".agent_process/roadmap")

def parse_frontmatter(content):
    """Extract YAML frontmatter from markdown content."""
    if not content.startswith('---'):
        return None
    try:
        end_match = re.search(r'\n---\s*\n', content[3:])
        if not end_match:
            return None
        yaml_content = content[3:end_match.start() + 3]
        return yaml.safe_load(yaml_content)
    except:
        return None

def update_frontmatter(file_path, updates):
    """Update frontmatter fields in a markdown file."""
    content = file_path.read_text()
    if not content.startswith('---'):
        return False

    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return False

    end_pos = end_match.end() + 3
    yaml_content = content[3:end_match.start() + 3]
    body = content[end_pos:]

    try:
        fm = yaml.safe_load(yaml_content) or {}
    except:
        return False

    fm.update(updates)
    new_yaml = yaml.dump(fm, default_flow_style=False, sort_keys=False)
    new_content = f"---\n{new_yaml}---\n{body}"
    file_path.write_text(new_content)
    return True

def is_approved(scope_dir):
    """Check if scope has Decision: APPROVE in iteration_plan.md."""
    plan_file = scope_dir / "iteration_plan.md"
    if not plan_file.exists():
        return False
    try:
        content = plan_file.read_text()
        if re.search(r'Decision:\s*(?:✅\s*)?APPROVE', content, re.IGNORECASE):
            return True
    except:
        pass
    return False

def get_approval_date(scope_dir):
    """Extract approval date from iteration_plan.md."""
    plan_file = scope_dir / "iteration_plan.md"
    if not plan_file.exists():
        return datetime.now().strftime("%Y-%m-%d")
    try:
        content = plan_file.read_text()
        match = re.search(r'Decision:\s*(?:✅\s*)?APPROVE\s*\((\d{4}-\d{2}-\d{2})\)', content, re.IGNORECASE)
        if match:
            return match.group(1)
    except:
        pass
    return datetime.now().strftime("%Y-%m-%d")

def find_requirement_by_id(scope_id):
    """Find requirement file matching this scope ID."""
    for md_file in REQ_DIR.rglob("*.md"):
        if "_TEMPLATE_" in str(md_file) or "/bugs/" in str(md_file):
            continue
        try:
            content = md_file.read_text()
            fm = parse_frontmatter(content)
            if fm and fm.get("id") == scope_id:
                return md_file, fm
        except:
            continue
    return None, None

# Collect approved scopes
scopes_to_archive = []
for scope_dir in sorted(WORK_DIR.iterdir()):
    if not scope_dir.is_dir():
        continue
    if is_approved(scope_dir):
        scope_id = scope_dir.name
        approval_date = get_approval_date(scope_dir)
        req_file, req_fm = find_requirement_by_id(scope_id)
        category = req_fm.get("category", "unknown") if req_fm else "unknown"
        scopes_to_archive.append({
            "scope_id": scope_id,
            "scope_dir": scope_dir,
            "approval_date": approval_date,
            "req_file": req_file,
            "category": category
        })

if not scopes_to_archive:
    print("Nothing to archive.")
    exit(0)

# Execute archive
success = []
failed = []

for scope in scopes_to_archive:
    scope_id = scope["scope_id"]
    source = scope["scope_dir"]
    target = ARCHIVE_DIR / scope_id

    try:
        # Try git mv first (preserves history)
        result = subprocess.run(
            ["git", "mv", str(source), str(target)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            # Fallback to regular mv + git add (for untracked dirs)
            subprocess.run(["mv", str(source), str(target)], check=True)
            subprocess.run(["git", "add", str(target)], check=True)

        # Update requirement frontmatter if linked
        if scope["req_file"]:
            updates = {
                "status": "approved",
                "approved_date": scope["approval_date"],
                "work_location": f"work_archive/approved/{scope_id}/"
            }
            update_frontmatter(scope["req_file"], updates)

        success.append(scope)
        print(f"✓ Archived: {scope_id}")

    except Exception as e:
        failed.append({"scope_id": scope_id, "error": str(e)})
        print(f"✗ Failed: {scope_id} - {e}")

# Generate completed_work.md
if success:
    by_category = defaultdict(list)
    for scope in success:
        by_category[scope["category"]].append(scope)

    completed_file = ROADMAP_DIR / "completed_work.md"
    lines = [
        "# Completed Work Archive",
        "",
        "> Historical record of all approved and archived work scopes.",
        "",
        f"**Last Updated:** {datetime.now().strftime('%Y-%m-%d')}",
        f"**Total Archived:** {len(success)} scopes",
        "",
        "## Completed Scopes by Category",
        ""
    ]

    for category in sorted(by_category.keys()):
        scopes = by_category[category]
        lines.append(f"### {category} ({len(scopes)} scopes)")
        lines.append("")
        lines.append("| Scope ID | Approved Date | Requirement |")
        lines.append("|----------|---------------|-------------|")
        for s in sorted(scopes, key=lambda x: x["approval_date"], reverse=True):
            req_link = f"`{s['req_file'].name}`" if s["req_file"] else "—"
            lines.append(f"| {s['scope_id']} | {s['approval_date']} | {req_link} |")
        lines.append("")

    completed_file.write_text("\n".join(lines))
    print(f"\n✓ Updated: {completed_file}")

# Summary
print(f"\n📦 Archive Complete")
print(f"   Archived: {len(success)} scopes")
if failed:
    print(f"   Failed: {len(failed)} scopes")
    for f in failed:
        print(f"     - {f['scope_id']}: {f['error']}")
print(f"\nReminder: Run 'git commit -m \"Archive {len(success)} completed work scopes\"' to finalize.")
PYEOF
```

### Step 5: Create Git Commit

After successful archive, commit the changes:

```bash
git add .agent_process/work_archive/
git add .agent_process/requirements_docs/
git add .agent_process/roadmap/completed_work.md
git commit -m "$(cat <<'EOF'
Archive [N] completed work scopes

Move approved work scopes from work/ to work_archive/approved/
- Preserves git history via git mv
- Updates requirement frontmatter with archive location
- Generates completed_work.md historical record
EOF
)"
```

### Step 6: Report Results

```
✅ Archive operation complete

📦 Summary:
- Scopes archived: [N]
- Requirements updated: [M]
- Git commit created: [hash]

📁 Archive location: .agent_process/work_archive/approved/

📊 Active work remaining: [X] scopes in work/

Run `/ap_project status` to see updated project state.
```

{% elif action == "help" %}

## Command Reference

### `/ap_project init`
Initialize roadmap infrastructure. Creates directory structure, discovers status markers from existing results.md files, and sets up configuration.

**Usage:** `/ap_project init`

---

### `/ap_project discover`
Scan requirements_docs/ and work/ directories. Build or update the roadmap with current project state. Uses Python-based scanning for reliability.

**Usage:** `/ap_project discover`

---

### `/ap_project status`
Show current project status summary including completion percentages, active work, blocked items, and recommendations.

**Usage:** `/ap_project status`

---

### `/ap_project set-status`
Manually set the status of a requirement. Manual overrides always win over automatic discovery.

**Usage:** `/ap_project set-status "<requirement_id> <status> [reason]"`

**Statuses:** `complete`, `in-progress`, `blocked`, `on-hold`, `needs-review`

**Examples:**
```
/ap_project set-status "lexical_epic_05 complete All work finished"
/ap_project set-status "ai_radar_scope_18 blocked Waiting for API"
/ap_project set-status "code_quality_epic on-hold Deprioritized"
```

---

### `/ap_project archive`
Archive a requirement, removing it from active roadmap while preserving history.

**Usage:** `/ap_project archive "<requirement_id> <type> [reason]"`

**Types:** `completed`, `abandoned`, `superseded`, `out-of-scope`

**Examples:**
```
/ap_project archive "old_feature abandoned Replaced by new approach"
/ap_project archive "lexical_epic_00 completed All work verified"
```

---

### `/ap_project archive-completed`
Bulk archive all approved work scopes from `work/` to `work_archive/approved/`. Preserves git history, updates requirement frontmatter, and generates a historical record.

**Usage:** `/ap_project archive-completed`

**What it does:**
1. Scans `work/` for scopes with "Decision: APPROVE" in iteration_plan.md
2. Shows archive plan and asks for confirmation
3. Moves scopes using `git mv` (preserves history)
4. Updates linked requirement frontmatter with:
   - `status: approved`
   - `approved_date: [date from decision]`
   - `work_location: work_archive/approved/[scope]/`
5. Generates/updates `completed_work.md` historical record
6. Creates atomic git commit

**Example output:**
```
📦 Archive Plan

Found 5 approved work scopes ready for archive:

| Scope ID | Approved Date | Category |
|----------|---------------|----------|
| lexical_epic_01 | 2026-01-24 | lexical_editor |
| ai_radar_scope_18 | 2026-01-24 | ai_radar |

Proceed with archive? (yes/no)
```

**When to use:**
- After completing several work scopes to declutter `work/`
- Before generating project reports (cleaner metrics)
- Periodically as part of project maintenance

**Note:** Only archives scopes with explicit "Decision: APPROVE" from orchestrator review. In-progress or unapproved work remains in `work/`.

---

### `/ap_project add-todo`
Add a structured item to the project backlog with priority, type, description, and acceptance criteria.

**Usage:** `/ap_project add-todo "brief description"`

The command will prompt for additional details to create a complete backlog entry:
- Priority (CRITICAL, HIGH, MEDIUM, LOW)
- Type (Bug Fix, Feature, Enhancement, Tech Debt)
- Source (where it came from)
- Detailed description and acceptance criteria
- Optional references (bug files, screenshots)

**Example:**
```
/ap_project add-todo "Session expiry doesn't redirect to login"
```

Creates a structured entry like:
```markdown
### Auto-Redirect to Login on Session Expiry
**Source:** User report (2026-01-18)
**Type:** Bug Fix

When session expires, user stays on page with failing API calls instead of being redirected to login.

**Acceptance Criteria:**
- [ ] Detect session expiry from 401 responses
- [ ] Redirect to login with friendly message
- [ ] Preserve intended destination URL
```

---

### `/ap_project add-requirement`
Create a new requirement from template.

**Usage:** `/ap_project add-requirement "requirement_name"`

---

### `/ap_project import-requirement`
Import an existing markdown file as a formal requirement. Interactive flow confirms category, ID, and priority with the user before making changes.

**Usage:** `/ap_project import-requirement "file_path [--supersedes old_id]"`

**Examples:**
```bash
/ap_project import-requirement "drafts/new_feature.md"
/ap_project import-requirement "requirements_docs/misplaced_file.md"
/ap_project import-requirement "notes/auth_bugs.md --supersedes old_auth"
```

**Interactive Flow:**
1. Analyzes file content to infer category, suggest ID, detect priority
2. **Asks user to confirm category** - explains naming convention, shows why it chose what it chose
3. **Asks user to confirm ID** - suggests next epic number, shows existing IDs in category
4. **Asks user to confirm priority** - shows detected priority and source
5. Moves file to `requirements_docs/{category}/{confirmed_id}.md`
6. Updates roadmap (does not modify table structure)

**Key behaviors:**
- Suggests smart IDs following `{category}_epic_{NN}_{descriptor}` pattern
- Finds next available epic/scope number automatically
- **Always moves** file to category subdirectory with confirmed ID as filename
- Does NOT modify `.roadmap_config.json` (frontmatter is authoritative)

**See:** `.agent_process/process/naming_conventions.md`

---

### `/ap_project sync`
Reconcile roadmap with actual work/ directory status. Reports discrepancies between status_overrides and discovered state.

**Usage:** `/ap_project sync`

---

### `/ap_project report`
Generate a stakeholder status report.

**Usage:** `/ap_project report ["type"]`

**Types:** `executive`, `detailed`, `weekly` (default: executive)

---

### Configuration Files

| File | Purpose |
|------|---------|
| `.roadmap_config.json` | Discovery settings, status markers, project_mappings, status_overrides |
| `master_roadmap.md` | Consolidated roadmap (status, categories, active work, blocked items, all requirements) |
| `backlog.md` | Items not yet formal requirements |
| `archived_roadmap.md` | Archived requirements (preserved history, created on first archive) |
| `.roadmap_audit.jsonl` | Audit trail for manual changes (created on first status change) |

{% endif %}

---

## Error Handling

If any step fails:
1. **Show clear error message** with what went wrong
2. **Suggest corrective action** (missing files, permissions, etc.)
3. **Offer to continue** with partial data if possible
4. **Provide manual fix instructions** for complex issues

## Next Steps

After completing this action, consider:
- Running `/ap_project status` to see current state
- Using `/ap_exec` to start work on ready requirements
- Setting up regular `/ap_project sync` to keep roadmap current
