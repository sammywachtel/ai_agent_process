# BEADS Integration

> **Diátaxis type:** How-To Guide (task-oriented)

## Overview

BEADS is a git-native issue tracking CLI that provides durable state tracking for AP work units. When available, execution state persists across session interruptions — a new session can load the BEADS epic and continue from the last completed work unit.

**BEADS is optional.** The framework works identically without it, using file-based state (`current_iteration.conf`, `current_work_unit.conf`, results.md). BEADS adds resilience, not functionality.

---

## Setup

### During Framework Installation

`install.sh` prompts: "Install and enable BEADS? [Y/n]"

- **Y (default):** Installs `bd` CLI (npm → brew → curl fallback) and sets `beads.enabled: true` in `quality-config.json`
- **n:** Sets `beads.enabled: false` and `beads.auto_install: false`. Framework uses file-based state.

### Runtime Auto-Installation

If `bd` is not found at execution time and `beads.auto_install` is `true`, `ap_exec` attempts installation:

1. npm: `npm install -g @beads/bd`
2. curl: `curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`

The attempt is cached per session (`.agent_process/.beads_install_attempted`) to avoid retrying on every `/ap_exec` call.

### Manual Installation

```bash
# npm (recommended — works in most containers)
npm install -g @beads/bd

# Homebrew (macOS)
brew install beads

# Go
go install github.com/steveyegge/beads/cmd/bd@latest

# Installer script
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
```

After installation, initialize in your project:
```bash
bd init
```

---

## How It Works

### Epic Lifecycle

Each AP scope maps to a BEADS epic:

```
/ap_exec my_feature iteration_01
         ↓
bd epic create my_feature --description "AP scope: my_feature"
         ↓
[Work unit decomposition creates tasks]
bd task create my_feature --id WU-001 --description "Schema migration"
bd task create my_feature --id WU-002 --description "API endpoint"
bd task create my_feature --id WU-003 --description "Frontend component"
         ↓
[Execution updates task state]
bd task update my_feature WU-001 --label in-progress
bd task update my_feature WU-001 --label complete
         ↓
[On APPROVE]
bd epic close my_feature --label approved
```

### State Tracking

| Event | BEADS Command | File-Based Equivalent |
|-------|--------------|----------------------|
| Scope started | `bd epic create {scope}` | `current_iteration.conf` |
| Work unit started | `bd task update ... --label in-progress` | `current_work_unit.conf` |
| Work unit complete | `bd task update ... --label complete` | Updated in results.md |
| Work unit blocked | `bd task update ... --label blocked` | Updated in results.md |
| Scope approved | `bd epic close ... --label approved` | iteration_plan.md updated |

### Session Recovery

When a session is interrupted and a new session starts:

**With BEADS:**
```bash
bd epic show my_feature
# Shows: WU-001 complete, WU-002 in-progress, WU-003 pending
# Resume from WU-002
```

**Without BEADS (file-based fallback):**
```bash
cat .agent_process/work/my_feature/current_work_unit.conf
# CURRENT_UNIT=WU-002
# Resume from WU-002
```

Both paths reach the same result. BEADS is more durable (survives context compaction and session boundaries) but the file-based state works for most scopes that complete in a single session.

---

## Configuration

In `.agent_process/quality-config.json`:

```json
{
  "beads": {
    "enabled": true,
    "auto_install": true
  }
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Master switch. `false` = BEADS fully ignored even if `bd` is on PATH |
| `auto_install` | `true` | Whether to attempt installing `bd` if not found. `false` = no install attempts |

---

## When BEADS Adds Value

| Scenario | BEADS Benefit |
|----------|--------------|
| Complex scope with 4+ work units | Tracks completion state across potential interruptions |
| Long-running scope spanning multiple sessions | Epic persists across session boundaries |
| Context compaction mid-execution | BEADS state survives; file-based state may be lost |
| Simple single-session scope | Minimal benefit — file-based state is sufficient |

---

## Troubleshooting

**`bd` not found after installation attempt:**
- Check `npm prefix -g` to see where npm installed it
- Container PATH may not include the npm global bin directory
- Try: `export PATH="$(npm prefix -g)/bin:$PATH"` then retry

**BEADS epic already exists:**
- `bd epic show {scope}` will succeed on re-invocation. `ap_exec` checks before creating.

**BEADS and file-based state disagree:**
- File-based state (results.md, `current_work_unit.conf`) is always the source of truth for the orchestrator's review
- BEADS is complementary, not authoritative
- If they disagree, trust the files

**Air-gapped environment:**
- Set `beads.auto_install: false` in `quality-config.json`
- Framework falls back to file-based state silently
- No network calls attempted

---

## Integration Points

| Component | Interaction |
|-----------|-------------|
| `ap_exec` Step 0.5 | Detects BEADS, auto-installs if enabled, creates/resumes epic |
| `ap_exec` Step 1.3 | Creates BEADS tasks for each work unit |
| `ap_exec` execution loop | Updates task labels (in-progress, complete, blocked) |
| `install.sh` | Prompts user, installs CLI, sets config |
| `quality-config.json` | `beads` section controls enabled state and auto-install |
| results.md | BEADS epic status included in Work Unit Summary when available |
