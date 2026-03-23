# Quality Gate Configuration

> **Diátaxis type:** Reference (information-oriented)

## Overview

`quality-config.json` controls which quality gates and metaswarm-inspired features are active in a project. It lives at `.agent_process/quality-config.json` and is created by `install.sh` with sensible defaults. The file is preserved on reinstall.

If the file doesn't exist, all features use their built-in defaults (equivalent to the shipped config).

---

## Schema

### `knowledge_base`

Controls the JSONL knowledge base system (Phase 1).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, Steps 2.5, 9.5, and 9.6 are skipped entirely. |
| `query_during_planning` | boolean | `true` | Whether Step 2.5 queries knowledge files during planning. |
| `deposit_on_approve` | boolean | `true` | Whether Step 9.5 deposits code learnings on APPROVE. |
| `deposit_on_block_pivot` | boolean | `true` | Whether Step 9.6 deposits process observations on BLOCK/PIVOT. |

### `adversarial_review`

Controls the fresh-agent adversarial review (Phase 1, platform-adaptive since Phase 2).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, Step 4.5 of `ap_exec` and Step 3.7 of the orchestrator are skipped. |
| `skip_for_trivial` | boolean | `true` | Whether to skip review for trivial scopes (below thresholds). |
| `trivial_threshold_files` | number | `2` | Scopes with this many or fewer changed files are considered trivial. |
| `trivial_threshold_criteria` | number | `1` | Scopes with this many or fewer criteria are considered trivial. |

### `work_unit_decomposition`

Controls the DAG-based work unit decomposition (Phase 2).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, Step 1.25 always skips decomposition. |
| `trigger_threshold_files` | number | `3` | Minimum implementation files to trigger decomposition. |
| `trigger_threshold_layers` | number | `2` | Minimum system layers to trigger decomposition. |
| `max_work_units` | number | `6` | Soft cap on work units per scope. |

### `design_review`

Controls the multi-reviewer design review gate (Phase 3).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Master switch. **Disabled by default** — opt-in only. |
| `trigger` | string | `"complexity:complex"` | Which `complexity` value in requirement frontmatter triggers the gate. |
| `max_revision_cycles` | number | `2` | Maximum plan revision cycles before human escalation. |
| `min_reviewers` | number | `2` | Minimum specialist reviewers per design review. |
| `max_reviewers` | number | `4` | Maximum specialist reviewers per design review. |

### `beads`

Controls BEADS durable state integration (Phase 3).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, BEADS is fully ignored even if `bd` is on the PATH. |
| `auto_install` | boolean | `true` | Whether to attempt installing `bd` CLI if not found. Set `false` for air-gapped environments. |
| `server` | object | `null` | Remote Dolt server connection. When present, `bd` connects here instead of requiring local Dolt. |
| `server.host` | string | — | Dolt server hostname or IP. Examples: `"127.0.0.1"` (local), `"beads.company.com"` (shared). |
| `server.port` | number | `3307` | Dolt server port. |
| `server.user` | string | `"root"` | Dolt database user. |

**Password** is set via the `BEADS_DOLT_PASSWORD` environment variable — never in config files. Use `direnv` (`.envrc`) or shell profile for per-project passwords.

**Per-project routing:** Each project's `quality-config.json` can point at a different server. Personal projects use local Dolt; company projects use a shared instance.

```json
// Personal project — local Dolt on your laptop
{ "beads": { "enabled": true } }

// Company project — shared GCE server
{ "beads": { "enabled": true, "server": { "host": "34.x.x.x", "port": 3307, "user": "beads" } } }

// No BEADS — file-based state only
{ "beads": { "enabled": false } }
```

When `server` is present, local Dolt installation is not required — `bd` connects to the remote instance directly. The `ap_exec` Step 0.5 exports `BEADS_DOLT_SERVER_HOST`, `BEADS_DOLT_SERVER_PORT`, and `BEADS_DOLT_SERVER_USER` from this config before any `bd` commands run.

### `pr_shepherd`

Controls the PR shepherd agent (Phase 2).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, `--shepherd` flag is ignored. |

---

## How Features Check the Config

Each feature reads the config at its activation point using a simple pattern:

```bash
# Read a value from quality-config.json (with default fallback)
enabled=$(python3 -c "
import json, sys
try:
    cfg = json.load(open('.agent_process/quality-config.json'))
    print(cfg.get('adversarial_review', {}).get('enabled', True))
except:
    print(True)  # default if file missing or malformed
" 2>/dev/null || echo "True")
```

Or in prompt instructions, the agent reads the file and checks the relevant section before proceeding.

**Fallback behavior:** If `quality-config.json` doesn't exist or is malformed, every feature uses its built-in default (typically `enabled: true` except design review which defaults to `false`).

---

## Customization Examples

**Disable adversarial review entirely:**
```json
{ "adversarial_review": { "enabled": false } }
```

**Lower the work unit decomposition threshold:**
```json
{ "work_unit_decomposition": { "trigger_threshold_files": 2 } }
```

**Enable design review for all complex scopes:**
```json
{ "design_review": { "enabled": true } }
```

**Disable BEADS auto-installation (air-gapped):**
```json
{ "beads": { "auto_install": false } }
```

**Minimal config (everything defaults):**
```json
{}
```

---

## Integration Points

| Component | Checks |
|-----------|--------|
| `ap_exec` Step 1.25 | `work_unit_decomposition.enabled` and thresholds |
| `ap_exec` Step 2.5 | `knowledge_base.enabled` and `query_during_planning` |
| `ap_exec` Step 4.5 | `adversarial_review.enabled` and `skip_for_trivial` |
| `ap_exec` BEADS init | `beads.enabled` and `beads.auto_install` |
| `01_plan_scope_instructions.md` | `design_review.enabled` and settings |
| `02_review_iteration_instructions.md` Step 3.7 | `adversarial_review.enabled` |
| `02_review_iteration_instructions.md` Step 9.5 | `knowledge_base.deposit_on_approve` |
| `02_review_iteration_instructions.md` Step 9.6 | `knowledge_base.deposit_on_block_pivot` |
| `ap_release` Step 9.5 | `pr_shepherd.enabled` |
| `install.sh` | Creates the file with defaults; preserves on reinstall |
