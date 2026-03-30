# Quality Gate Configuration

> **Diátaxis type:** Reference (information-oriented)

## Overview

`quality-config.json` controls which quality gates and metaswarm-inspired features are active in a project. It lives at `.agent_process/quality-config.json` and is created by `install.sh` with sensible defaults. The file is preserved on reinstall.

If the file doesn't exist, all features use their built-in defaults (equivalent to the shipped config).

---

## Schema

### `pre_flight`

Controls pre-flight checks before implementation begins (Phase 2).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, Step 0.7 is skipped entirely. |
| `session_recovery` | boolean | `true` | Detect interrupted work from previous runs and warn before overwriting. |
| `working_tree_check` | boolean | `true` | Check for uncommitted changes in files that overlap with the scope. |
| `branch_check` | boolean | `true` | Verify correct scope branch, auto-checkout if needed, warn if behind remote. |
| `git_context` | boolean | `true` | Load recent git history for files in scope to give the implementation agent awareness of recent changes. |

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
| `server.host` | string | — | Dolt server hostname or IP. For IAP tunnel setups, use `"127.0.0.1"`. |
| `server.port` | number | `3308` | Tunnel port. Written to `.beads/dolt-server.port` by `install.sh`. Use `3308` for remote (reserves `3307` for local Dolt). |
| `server.user` | string | `"root"` | MySQL user. Written to `.beads/metadata.json` by `install.sh`. |

**Password sources** (checked in order):
1. `BEADS_DOLT_PASSWORD` env var
2. `.beads/.env` file (per-project, loaded automatically by `bd`)
3. `~/.config/beads/credentials` keyed by `[host:port]` (per-machine)

For remote server setups, passwords are managed via GCP Secret Manager and fetched by `make get-my-creds` or `make setup` in the dolt infrastructure project.

**Per-project routing:** Each project's `quality-config.json` can point at a different server. Personal projects use local Dolt; company projects use a shared instance.

```json
// Personal project — local Dolt on your laptop (port 3307)
{ "beads": { "enabled": true } }

// Company project — remote Dolt via IAP tunnel (port 3308)
{ "beads": { "enabled": true, "server": { "host": "127.0.0.1", "port": 3308, "user": "sam" } } }

// No BEADS — file-based state only
{ "beads": { "enabled": false } }
```

When `server` is present, local Dolt installation is not required — `bd` connects through the IAP tunnel. During `install.sh`:
- `server.port` is written to `.beads/dolt-server.port` (gitignored, per-machine — this is the primary port source for `bd`)
- `server.user` is written to `.beads/metadata.json` via `bd dolt set user`
- Auto-backup and auto-push are disabled (incompatible with remote server mode)
- Credentials are read from `~/.config/beads/credentials` by matching `[host:port]`

The `beads-lifecycle.sh` script handles BEADS lifecycle during execution (Step 0.5).

### `pr_shepherd`

Controls the PR shepherd agent (Phase 2).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch. When `false`, `--shepherd` flag is ignored. |

### `metaswarm`

Controls optional metaswarm integration for brainstorming, design review, and more.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Master switch. **Disabled by default** — opt-in only. |
| `_user_configured` | boolean | `false` | Set by `install.sh` after user makes a choice. Prevents re-prompting on reinstall. |
| `features` | object | — | Per-feature toggles (all default `true` when master is enabled). |
| `features.brainstorm` | boolean | `true` | Enable brainstorm workflow in `/ap_requirements`. |
| `features.design_review` | boolean | `true` | Offer design review after brainstorm/import. |
| `features.prime` | boolean | `true` | Enable knowledge priming in `/ap_exec` (Phase 2 — not yet implemented). |
| `features.pr_shepherd` | boolean | `true` | Enable metaswarm PR shepherd in `/ap_release` (Phase 3 — not yet implemented). |
| `features.self_reflect` | boolean | `true` | Enable self-reflection after APPROVE (Phase 3 — not yet implemented). |

**Detection:** When `enabled` is `true`, AP commands also verify metaswarm is installed (checks for `~/.claude/commands/brainstorm.md`). If enabled but not installed, commands warn once and continue without metaswarm features.

**See:** `process/metaswarm-integration.md` for full integration reference.

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
| `ap_exec` Step 0.7 | `pre_flight.enabled` and individual check flags |
| `ap_exec` Step 1.25 | `work_unit_decomposition.enabled` and thresholds |
| `ap_exec` Step 2.5 | `knowledge_base.enabled` and `query_during_planning` |
| `ap_exec` Step 4.5 | `adversarial_review.enabled` and `skip_for_trivial` |
| `ap_exec` BEADS init | `beads.enabled` and `beads.auto_install` |
| `orchestration/coordinators/plan-scope.md (coordinator) + orchestration/steps/planning/ (step files)` | `design_review.enabled` and settings |
| `orchestration/coordinators/review-iteration.md + steps/review/` Step 3.7 | `adversarial_review.enabled` |
| `orchestration/coordinators/review-iteration.md + steps/review/` Step 9.5 | `knowledge_base.deposit_on_approve` |
| `orchestration/coordinators/review-iteration.md + steps/review/` Step 9.6 | `knowledge_base.deposit_on_block_pivot` |
| `ap_release` Step 9.5 | `pr_shepherd.enabled` |
| `ap_requirements` brainstorm | `metaswarm.enabled` and `metaswarm.features.brainstorm` |
| `ap_requirements` add | `metaswarm.enabled` (offers brainstorm option) |
| `ap_requirements` import | `metaswarm.enabled` and `metaswarm.features.design_review` |
| `install.sh` | Creates the file with defaults; preserves on reinstall |
