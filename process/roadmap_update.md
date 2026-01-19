# Roadmap Update Process

**Purpose:** Define when and how the roadmap is maintained during project execution.

**See also:** `naming_conventions.md` for requirement ID formats and file naming rules.

---

## Update Triggers

### 1. Iteration Completion (Automatic)

**When:** After writing `results.md` with completion status (✅ COMPLETE, 🚫 BLOCKED, etc.)

**What gets updated:**
- Requirement status and work scope counts in `master_roadmap.md`
- Category completion percentages in `master_roadmap.md`
- Active Work and Blocked Items sections in `master_roadmap.md`
- Last Updated timestamp

**Who triggers:** Orchestration prompts (Claude following instructions, not commands)

### 2. New Requirement Added (Manual)

**When:** User creates new requirement file or uses `/ap_project add-requirement` or `/ap_project import-requirement`

**What gets updated:**
- Add new row to `master_roadmap.md` in appropriate category section
- Update category counts and status summary in `master_roadmap.md`
- If using `import-requirement`: Adds frontmatter, standardizes filename (see `naming_conventions.md`)
- If creating manually: Re-run discovery to detect structure changes

### 3. Backlog Management (Manual)

**When:** User adds/resolves todo items or uses `/ap_project add-todo`

**What gets updated:**
- Add/remove items from `backlog.md`
- Move items to formal requirements if they become scope-sized

### 4. Project Structure Changes (On-Demand)

**When:** User runs `/ap_project sync` or significant directory restructuring

**What gets updated:**
- Full re-discovery of requirements and work directories
- Regenerate `master_roadmap.md` with fresh matching statistics
- Reconcile orphaned work or requirements

---

## Update Procedures

### Orchestration-Triggered Updates

**Context:** These are instructions for Claude during `/ap_exec` or iteration review, not commands.

#### Step 1: Detect Completion

```markdown
# Instructions for Claude (in orchestration prompt)

After writing results.md, check if status changed to ✅ COMPLETE, 🚫 BLOCKED, etc.

If status changed:
1. Read current `.agent_process/roadmap/master_roadmap.md`
2. Find the requirement in the appropriate category section
3. Update the work scope count and status icon
4. Move requirement between Active Work / Blocked Items sections as needed
5. Recalculate category completion percentages
```

#### Step 2: Update Master Roadmap

All updates are made to `master_roadmap.md`. The file contains consolidated sections:

```markdown
# Example updates in master_roadmap.md

## Status Summary (recalculate)
| Status | Count | Percentage |
|--------|-------|------------|
| ✅ Complete | [N] | [%] | ← Recalculate totals

## Category Breakdown (recalculate)
| Category | Complete | In Progress | Blocked | Completion |
|----------|----------|-------------|---------|------------|
| {Category} | [N] | [N] | [N] | [%] | ← Recalculate based on work scope updates

## Active Work / Blocked Items (move requirements as needed)
| Requirement | Category | Work Scopes |
|-------------|----------|-------------|
| {requirement_id} | {category} | [N] | ← Add/remove based on status change

## Requirements by Category (update status icon)
| Status | Priority | Requirement | Work Scopes |
|--------|----------|-------------|-------------|
| [icon] | [PRIORITY] | {Display Name} | [N] | ← Update status icon and work scope count
```

**Iteration format:** Count major iterations + progression. Examples:
- `1 (01)` - Single iteration, no PIVOT
- `2 (01→02)` - Two major iterations (one PIVOT)
- `1+2 (01_b)` - One major + 2 sub-iterations

---

## Detailed Post-Iteration Instructions

**For orchestration to reference:** These step-by-step instructions should be included in iteration review prompts.

### When to Execute

Execute these steps **after** you have:
1. Completed an iteration
2. Written `results.md` with status (✅ COMPLETE, 🚫 BLOCKED, etc.)
3. Validated all acceptance criteria

**Skip if:**
- Iteration is still in progress
- Results.md shows IN_PROGRESS status
- Roadmap directory doesn't exist (project not using roadmap yet)

### Step-by-Step Procedure

#### 1. Check if Roadmap Exists

```bash
ls .agent_process/roadmap/
```

If no roadmap directory exists, skip remaining steps.

#### 2. Identify Current Work

Determine identifiers from work directory name:
- **Work scope:** Directory name (e.g., `feature_scope_15_description`)
- **Requirement ID:** Extract by removing `_scope_XX_` pattern

**Examples:**
```
Work: feature_name_scope_01_first_component
→ Requirement: feature_name

Work: category_feature_scope_02_second_component
→ Requirement: category_feature
```

#### 3. Update Master Roadmap

Read `.agent_process/roadmap/master_roadmap.md` and update all relevant sections:

**Status mapping:**
- "✅ COMPLETE" in results.md → ✅ icon
- "🚫 BLOCKED" → ❌ icon
- "🚧 IN PROGRESS" → 🚧 icon

**Update these sections:**

1. **Status Summary table** - Recalculate counts and percentages
2. **Category Breakdown table** - Update category completion percentage
3. **Active Work section** - Add/remove requirement based on status
4. **Blocked Items section** - Add/remove requirement if blocked/unblocked
5. **Requirements by Category section** - Update status icon and work scope count
6. **Last Updated timestamp** in header

**Aggregate status logic:**
- All scopes complete → ✅ Complete
- Any scope blocked → ❌ Blocked
- Mix of complete/incomplete → 🚧 In Progress

**Completion calculation:**
```
% Complete = (Complete Requirements / Total Requirements) × 100
```

#### 4. Capture Follow-up Items

If results.md contains "Follow-up" or "Known Issues" sections:
- Add HIGH priority items to `.agent_process/roadmap/backlog.md`
- Note if items need their own scope

### Error Handling

If roadmap files are missing or malformed:
1. Note the issue in results.md
2. Continue with iteration completion normally
3. User can run `/ap_project sync` to rebuild

---

### Command-Triggered Updates

**Context:** User invokes `/ap_project` commands for manual management.

#### Discovery/Sync Process

1. **Full scan** of `requirements_docs/` and `work/`
2. **Fuzzy matching** work directories to requirements
3. **Status aggregation** from latest results.md files
4. **Regenerate `master_roadmap.md`** from discovered state
5. **Preserve configuration** in `.roadmap_config.json` (project_mappings, status_overrides)

#### Incremental Updates

For small changes (add todo, update priority):
1. **Read current `master_roadmap.md`**
2. **Apply specific change** (add row, update field)
3. **Update Last Updated timestamp**
4. **Validate consistency** (percentages still add up)

---

## Update Safeguards

### Data Preservation

- **Backup current roadmap** before major updates (`.roadmap_backup_TIMESTAMP/`)
- **Preserve manual edits** like category overrides, priority adjustments
- **Warn before destructive operations** (full regeneration)

### Consistency Checks

After any update, validate:
- **Completion percentages** add up to 100%
- **Work scope counts** match actual directories
- **Status logic** (can't be Complete with In Progress work scopes)
- **Timestamp ordering** (last activity ≤ current time)

### Error Handling

- **Graceful degradation** - partial updates on file access errors
- **Clear error messages** - which files failed, what to fix
- **Rollback capability** - restore from backup if update fails

---

## Performance Considerations

### Incremental Discovery

- **Track Last Updated** in `master_roadmap.md` header
- **Only re-scan changed files/directories** when possible
- **Skip full fuzzy matching** if structure unchanged

### Large Project Handling

- **Limit discovery** to 1000 files, warn if exceeded
- **Paginate large tables** in roadmap files
- **Summarize instead of listing** if >100 work scopes per requirement

---

## Integration Points

### With Orchestration

The orchestration system should include instructions for Claude to follow after iteration completion. These instructions should be embedded in the iteration review prompts (e.g., `02_review_iteration_prompt.md` or similar) and reference this process document.

**Key points for orchestration integration:**
- After writing results.md, Claude should check if roadmap exists
- If roadmap exists, follow the "Orchestration-Triggered Updates" section above
- Reference this document for detailed procedures
- No dependency on slash commands - use Read/Write/Edit tools directly

### With Commands

**File:** `.claude/commands/ap_project.md`

Provides user interface for:
- Manual roadmap updates
- Adding requirements/todos
- Syncing with current state
- Generating status reports

### With Existing Workflows

- **Compatible with current orchestration** - doesn't change `/ap_exec` behavior
- **Supplements todo_requirements.md** - migrates items to backlog.md
- **Works with any requirement format** - doesn't require schema changes

---

## Migration from Existing Projects

### Bootstrap Process

For projects with existing requirements but no roadmap:

1. **Run discovery** on current state
2. **Create initial roadmap files** from discovered data
3. **Migrate todo_requirements.md** to backlog.md
4. **Add orchestration prompts** for future maintenance

### Backwards Compatibility

- **Keep existing todo_requirements.md** until fully migrated
- **Don't require roadmap** for orchestration to work
- **Optional adoption** - teams can use roadmap or not

This process ensures roadmap stays synchronized with project reality while being flexible enough for any team's workflow.