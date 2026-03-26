# BEADS Integration

> **Diátaxis type:** How-To Guide (task-oriented)

## Overview

BEADS is a git-native issue tracking CLI that provides durable state tracking for AP work units. When available, execution state persists across session interruptions — a new session can load the BEADS epic and continue from the last completed work unit.

**BEADS is optional.** The framework works identically without it, using file-based state (`current_iteration.conf`, `current_work_unit.conf`, results.md). BEADS adds resilience, not functionality.

---

## Prerequisites

BEADS requires two components:

| Component | Size | Auto-installed? | Install command |
|-----------|------|-----------------|-----------------|
| **Dolt** (database server) | ~100MB | **No** — user installs manually | `brew install dolt` |
| **bd** (BEADS CLI) | lightweight | Yes (npm/brew/curl) | `npm install -g @beads/bd` |

**Dolt is never auto-installed** due to its size (~100MB). The framework detects it and uses BEADS only when Dolt is already present. Without Dolt, BEADS is silently skipped — no errors, no warnings during execution.

---

## Setup

### Step 1: Install Dolt (manual, one-time)

```bash
# macOS
brew install dolt

# Linux — see https://docs.dolthub.com/introduction/installation
```

### Step 2: Framework Installation

`install.sh` detects Dolt and prompts: "Enable BEADS? [Y/n]"

- **Y (default):** Installs `bd` CLI if needed and sets `beads.enabled: true` in `quality-config.json`
- **n:** Sets `beads.enabled: false`. Framework uses file-based state.
- **No Dolt found:** Warns that Dolt is required, enables in config anyway (so it activates once Dolt is installed)

### Step 3: Project Initialization

`install.sh` and `ap_exec` both run `bd init` automatically if `.beads/` doesn't exist. This creates the BEADS database in the project directory. You can also do it manually:

```bash
bd init
```

### Runtime Auto-Installation (bd CLI only)

If `dolt` is found but `bd` is not at execution time, `ap_exec` attempts to install the lightweight `bd` CLI:

1. npm: `npm install -g @beads/bd`
2. curl: `curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`

The attempt is cached per session (`.agent_process/.beads_install_attempted`) to avoid retrying on every `/ap_exec` call.

### Manual Installation

```bash
# 1. Install Dolt (prerequisite)
brew install dolt

# 2. Install bd CLI
npm install -g @beads/bd   # or: brew install beads

# 3. Initialize in project
cd /path/to/project
bd init
```

---

## How It Works

### ⚠️ Agents: Use beads-lifecycle.sh, NOT bd Directly

**All agent-initiated BEADS operations MUST go through `beads-lifecycle.sh`**, not raw `bd` commands. The lifecycle script handles:

- **Docker host rewriting:** Rewrites `127.0.0.1` → `host.docker.internal` inside containers (Codex, Docker dev environments). Without this, `bd` tries to connect to localhost *inside the container*, which has no Dolt server — resulting in "access denied for user root" errors.
- **Credential loading:** Reads `~/.config/beads/credentials` and scopes to the project's configured host.
- **Auto-installation:** Installs `bd` if missing.
- **Breadcrumb writing:** Records state to `.beads-state` so the orchestrator can verify the step ran.

```bash
# ✅ Correct — agents always use the lifecycle script
BEADS_ITERATION=iteration_01 bash .agent_process/scripts/beads-lifecycle.sh start my_scope
bash .agent_process/scripts/beads-lifecycle.sh task-create my_scope WU-001 "Schema migration"
bash .agent_process/scripts/beads-lifecycle.sh status my_scope

# ❌ Wrong — fails inside containers, no credential scoping
bd epic create my_scope
bd task update my_scope WU-001 --label in-progress
```

The raw `bd` commands shown below are for **conceptual illustration** and **human CLI use** only. Agents must use `beads-lifecycle.sh`.

### Epic Lifecycle

Each AP scope maps to a BEADS epic. Conceptually:

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

Each project's `.agent_process/quality-config.json` controls BEADS independently. This is how you route personal projects to local Dolt and company projects to a shared server.

### Local Dolt (personal projects)

```json
{
  "beads": {
    "enabled": true,
    "auto_install": true
  }
}
```

Requires Dolt installed locally (`brew install dolt`). `bd` connects to `127.0.0.1:3307`.

### Remote Dolt (company/shared projects)

```json
{
  "beads": {
    "enabled": true,
    "auto_install": true,
    "server": {
      "host": "34.x.x.x",
      "port": 3307,
      "user": "beads"
    }
  }
}
```

Local Dolt installation is NOT required — `bd` connects directly to the remote server.

### Credentials

Passwords are stored in `~/.config/beads/credentials` (INI-style, keyed by host:port):

```ini
# ~/.config/beads/credentials
[127.0.0.1:3307]
password=localDevPassword

[beads.company.com:3307]
password=companyPassword
```

This file is:
- **Created automatically** when Docker install generates a password during `install.sh`
- **Shared across all projects** — one file, all servers
- **Read natively by `bd`** — no wrapper scripts needed
- **Overridable** via `BEADS_CREDENTIALS_FILE` env var (for non-default locations)
- **Permissions:** `chmod 600` (set automatically by installer, `bd` warns if too open)

In Docker containers, mount `~/.config/beads` read-only and set `BEADS_DOLT_SERVER_HOST=host.docker.internal` in the container environment.

### Command-Line Usage

`bd` reads credentials natively. Just use it directly:

```bash
bd list
bd prime
bd dolt test
bd doctor
```

Server config (host/port/user) is stored per-project in `.beads/` via `bd dolt set`. Credentials are resolved by matching the configured `[host:port]` against the credentials file.

### Disabled (no BEADS)

```json
{
  "beads": {
    "enabled": false
  }
}
```

### Config Fields

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Master switch. `false` = BEADS fully ignored even if `bd` is on PATH |
| `auto_install` | `true` | Whether to attempt installing `bd` CLI if not found |
| `server.host` | — | Remote Dolt hostname/IP. Omit for local Dolt |
| `server.port` | `3307` | Remote Dolt port |
| `server.user` | `"root"` | Remote Dolt user |

### Deploying a Shared Server

See `deploy/beads-server/` for scripts that create a GCE e2-micro VM (~$7/month) running Dolt. The setup script outputs the exact `quality-config.json` snippet for your projects.

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
| `ap_exec` Step 0.5 | Detects BEADS, auto-installs if enabled, loads credentials, creates/resumes epic |
| `ap_exec` Step 1.3 | Creates BEADS tasks for each work unit |
| `ap_exec` execution loop | Updates task labels (in-progress, complete, blocked) |
| `install.sh` | Prompts user, installs CLI, seeds credentials, configures `bd dolt set` |
| `quality-config.json` | `beads` section controls enabled state, server routing, and auto-install |
| `~/.config/beads/credentials` | INI-style credentials file, keyed by host:port, read natively by `bd` |
| results.md | BEADS epic status included in Work Unit Summary when available |
