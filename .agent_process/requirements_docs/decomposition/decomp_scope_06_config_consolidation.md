---
id: decomp_scope_06_config_consolidation
type: requirement
category: decomposition
status: planned
priority: medium
---

# Requirements: Config Consolidation

---

## Objective
Move central sync configuration from `process/ap_release_central_sync.md` (a markdown file pretending to be config) into `quality-config.json` where all other feature configuration lives. The markdown file becomes a pure how-to guide with no parseable config in it.

## Background
Configuration is currently scattered across two locations:
- `quality-config.json` — beads, pre_flight, adversarial_review, work_unit_decomposition, design_review, pr_shepherd, metaswarm, knowledge_base
- `process/ap_release_central_sync.md` — central repo sync (ENABLED, CENTRAL_REPO_PATH, PROJECT_FOLDER)

The markdown file uses grep-based parsing (`grep "ENABLED:"`) which is fragile and already caused a bug where `sed` replaced documentation examples along with the actual config values. Moving to `quality-config.json` gives us proper JSON parsing, consistent with every other feature flag.

---

## Acceptance Criteria

### AC-1: Config moved to quality-config.json
- [ ] New `central_sync` section in `quality-config.json` schema
- [ ] Fields: `enabled` (boolean), `central_repo_path` (string), `project_folder` (string)
- [ ] `install.sh` writes central sync config to `quality-config.json` instead of templating the markdown file

### AC-2: Release step reads from quality-config.json
- [ ] `orchestration/steps/release/07-09-commit-tag-push.md` reads central sync config from `quality-config.json`
- [ ] No more grep-based parsing of markdown for config values

### AC-3: Markdown file becomes documentation only
- [ ] `process/ap_release_central_sync.md` becomes a how-to guide explaining central sync
- [ ] No `ENABLED:`, `CENTRAL_REPO_PATH:`, or `PROJECT_FOLDER:` parseable config lines
- [ ] References `quality-config.json` for actual configuration

### AC-4: Installer migration
- [ ] `install.sh` reads existing central sync values from old markdown format during upgrade
- [ ] Writes them to `quality-config.json`
- [ ] Overwrites the markdown file with the documentation-only version
- [ ] Idempotent — works on fresh installs and upgrades

### AC-5: Documentation updated
- [ ] `process/quality-configuration.md` documents the new `central_sync` section
- [ ] `process/ap_release_central_sync.md` updated to reference `quality-config.json`

---

## Files Expected to Change

**Modified files:**
- `install.sh` — write central sync config to `quality-config.json`
- `orchestration/steps/release/07-09-commit-tag-push.md` — read from `quality-config.json`
- `process/ap_release_central_sync.md` — strip config, keep as how-to guide
- `process/quality-configuration.md` — document new section

---

## Dependencies
- **Scope 4 (Release)** — the release step file must exist before we change how it reads config

---

## Testing Strategy
1. Fresh install — verify central sync config lands in `quality-config.json`
2. Upgrade from old format — verify migration reads markdown values and writes to JSON
3. Run `ap_release pr` — verify central sync works from `quality-config.json`
4. Verify documentation-only markdown file has no parseable config
