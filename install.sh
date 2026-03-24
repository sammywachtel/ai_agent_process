#!/usr/bin/env bash
#
# AI Agent Process Template - Installation Script
#
# Usage:
#   ./install.sh <target>              # Install from source to target
#   cd <target>; <source>/install.sh   # Install to current directory
#   cd <target>; <source>/install.sh . # Install to current directory (explicit)
#
# This script:
# - Updates .claude/commands/ with command scripts
# - Installs/updates .agent_process/ template files
# - Preserves existing .agent_process/work/ directory
# - Makes hook scripts executable

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Determine source directory (where this script lives)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine target directory
if [[ $# -eq 0 ]]; then
  # No arguments - target is current directory
  TARGET_DIR="$(pwd)"
elif [[ "$1" == "." ]]; then
  # Explicit current directory
  TARGET_DIR="$(pwd)"
else
  # Target directory specified
  TARGET_DIR="$(cd "$1" && pwd)"
fi

# Validate that we're not installing to the source directory
if [[ "$SOURCE_DIR" == "$TARGET_DIR" ]]; then
  echo -e "${RED}Error: Cannot install to the source directory itself${NC}"
  echo "Source: $SOURCE_DIR"
  echo "Target: $TARGET_DIR"
  exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  AI Agent Process Template - Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Source: ${GREEN}$SOURCE_DIR${NC}"
echo -e "  Target: ${GREEN}$TARGET_DIR${NC}"

# Check if .agent_process is a symlink
AGENT_PROCESS_DIR="$TARGET_DIR/.agent_process"
AGENT_PROCESS_IS_SYMLINK=false

if [[ -L "$AGENT_PROCESS_DIR" ]]; then
  AGENT_PROCESS_IS_SYMLINK=true
  SYMLINK_TARGET="$(readlink "$AGENT_PROCESS_DIR")"
  echo -e "  ${YELLOW}Note:${NC} .agent_process is a symlink → ${GREEN}$SYMLINK_TARGET${NC}"
fi
echo ""

# Verify source directory has required structure
if [[ ! -d "$SOURCE_DIR/claude/commands" ]]; then
  echo -e "${RED}Error: Source directory missing claude/commands/${NC}"
  echo "Are you running this from the AI Agent Process template directory?"
  exit 1
fi

# Create target directories
echo -e "${BLUE}▸${NC} Creating directory structure..."

mkdir -p "$TARGET_DIR/.claude/commands"

# Handle .agent_process directory creation (respecting symlinks)
if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
  echo -e "${YELLOW}  ⊙${NC} Using existing symlink for .agent_process/"
  # Ensure subdirectories exist within the symlink target
  mkdir -p "$AGENT_PROCESS_DIR/orchestration"
  mkdir -p "$AGENT_PROCESS_DIR/process"
  mkdir -p "$AGENT_PROCESS_DIR/scripts/after_edit"
  mkdir -p "$AGENT_PROCESS_DIR/templates"
  mkdir -p "$AGENT_PROCESS_DIR/requirements_docs"
  mkdir -p "$AGENT_PROCESS_DIR/claude/commands"
else
  mkdir -p "$AGENT_PROCESS_DIR/orchestration"
  mkdir -p "$AGENT_PROCESS_DIR/process"
  mkdir -p "$AGENT_PROCESS_DIR/scripts/after_edit"
  mkdir -p "$AGENT_PROCESS_DIR/templates"
  mkdir -p "$AGENT_PROCESS_DIR/requirements_docs"
  mkdir -p "$AGENT_PROCESS_DIR/claude/commands"
fi

# Only create work/ if it doesn't exist (preserve existing work)
if [[ ! -d "$AGENT_PROCESS_DIR/work" ]]; then
  mkdir -p "$AGENT_PROCESS_DIR/work"
  echo -e "${GREEN}  ✓${NC} Created .agent_process/work/ directory"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .agent_process/work/ directory"
fi

# Knowledge base directory — .beads/knowledge/ when BEADS enabled, .agent_process/knowledge/ as fallback
# Both are created; the orchestrator/agents pick the right one at runtime
KB_FILES="patterns gotchas decisions anti-patterns"
KB_FILES_EXTENDED="codebase-facts api-behaviors"  # metaswarm-compatible extras

# Always ensure .agent_process/knowledge/ exists (fallback when BEADS disabled)
if [[ ! -d "$AGENT_PROCESS_DIR/knowledge" ]]; then
  mkdir -p "$AGENT_PROCESS_DIR/knowledge"
  for kb_file in $KB_FILES; do
    if [[ ! -f "$AGENT_PROCESS_DIR/knowledge/${kb_file}.jsonl" ]]; then
      echo "# Schema: ${kb_file}.jsonl — see process/knowledge-base.md for format" > "$AGENT_PROCESS_DIR/knowledge/${kb_file}.jsonl"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Created .agent_process/knowledge/ (fallback)"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .agent_process/knowledge/"
fi

# Create .beads/knowledge/ for BEADS-managed knowledge (metaswarm-compatible)
if [[ ! -d "$TARGET_DIR/.beads/knowledge" ]]; then
  mkdir -p "$TARGET_DIR/.beads/knowledge"
  for kb_file in $KB_FILES $KB_FILES_EXTENDED; do
    if [[ ! -f "$TARGET_DIR/.beads/knowledge/${kb_file}.jsonl" ]]; then
      echo "# Schema: ${kb_file}.jsonl — metaswarm-compatible. See process/knowledge-base.md" > "$TARGET_DIR/.beads/knowledge/${kb_file}.jsonl"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Created .beads/knowledge/ (primary, metaswarm-compatible)"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .beads/knowledge/"
fi

# Migrate legacy .agent_process/knowledge/ entries → .beads/knowledge/ (idempotent)
# Uses scripts/migrate-knowledge.py — same script users can run manually
if [[ -d "$AGENT_PROCESS_DIR/knowledge" && -d "$TARGET_DIR/.beads/knowledge" ]]; then
  MIGRATED=$(python3 "$SOURCE_DIR/scripts/migrate-knowledge.py" --src "$AGENT_PROCESS_DIR/knowledge" --dst "$TARGET_DIR/.beads/knowledge" -q 2>/dev/null || echo "0")
  if [[ "$MIGRATED" -gt 0 ]]; then
    echo -e "${GREEN}  ✓${NC} Migrated ${MIGRATED} knowledge entries from .agent_process/knowledge/ → .beads/knowledge/"
  fi
fi

# Ensure quality-config.json exists (seed from template if missing)
QUALITY_CONFIG_FRESH=false
if [[ ! -f "$AGENT_PROCESS_DIR/quality-config.json" ]]; then
  cp "$SOURCE_DIR/quality-config.json" "$AGENT_PROCESS_DIR/quality-config.json"
  QUALITY_CONFIG_FRESH=true
fi

# ─── Feature Selection ───────────────────────────────────────────────
# Always prompt — lets users review and change settings on every install.
# Default is enabled (Enter = yes) for all features.
echo ""
echo -e "${BLUE}▸${NC} Feature configuration..."
echo -e "  Configure which quality gates are active. Press Enter to accept the default."
echo ""

# Read current values from config (or use defaults)
read_feature() {
  local feature="$1" default="$2"
  python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    parts = '$feature'.split('.')
    val = cfg
    for p in parts:
        val = val.get(p, {})
    if isinstance(val, bool):
        print('yes' if val else 'no')
    else:
        print('$default')
except:
    print('$default')
" 2>/dev/null || echo "$default"
}

prompt_feature() {
  local label="$1" desc="$2" feature="$3" default="$4"
  local current
  current=$(read_feature "$feature" "$default")
  local hint="Y/n"
  [[ "$current" == "no" ]] && hint="y/N"
  read -p "  $label ($desc) [$hint]: " -n 1 -r
  echo "" >&2
  if [[ -z "$REPLY" ]]; then
    # Enter pressed — keep current/default
    echo "$current"
  elif [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

FEAT_PREFLIGHT=$(prompt_feature "Pre-flight checks" "session recovery, branch check, git context" "pre_flight.enabled" "yes")
FEAT_KNOWLEDGE=$(prompt_feature "Knowledge base" "patterns, gotchas, decisions across iterations" "knowledge_base.enabled" "yes")
FEAT_ADVERSARIAL=$(prompt_feature "Adversarial review" "fresh-agent criterion verification" "adversarial_review.enabled" "yes")
FEAT_DECOMPOSITION=$(prompt_feature "Work unit decomposition" "DAG-based parallel execution for multi-domain scopes" "work_unit_decomposition.enabled" "yes")
FEAT_DESIGN_REVIEW=$(prompt_feature "Design review gate" "multi-reviewer plan assessment for complex scopes" "design_review.enabled" "no")
FEAT_BEADS=$(prompt_feature "BEADS" "git-native durable state tracking via Dolt" "beads.enabled" "yes")
FEAT_PR_SHEPHERD=$(prompt_feature "PR shepherd" "post-PR agent monitoring CI and reviews" "pr_shepherd.enabled" "yes")
FEAT_METASWARM=$(prompt_feature "Metaswarm integration" "brainstorming, design review, knowledge priming" "metaswarm.enabled" "no")

# Write all selections to quality-config.json
python3 -c "
import json
path = '$AGENT_PROCESS_DIR/quality-config.json'
try:
    cfg = json.load(open(path))
except:
    cfg = {}

def to_bool(s): return s == 'yes'

cfg.setdefault('pre_flight', {})['enabled'] = to_bool('$FEAT_PREFLIGHT')
cfg.setdefault('knowledge_base', {})['enabled'] = to_bool('$FEAT_KNOWLEDGE')
cfg.setdefault('adversarial_review', {})['enabled'] = to_bool('$FEAT_ADVERSARIAL')
cfg.setdefault('work_unit_decomposition', {})['enabled'] = to_bool('$FEAT_DECOMPOSITION')
cfg.setdefault('design_review', {})['enabled'] = to_bool('$FEAT_DESIGN_REVIEW')
cfg.setdefault('beads', {})['enabled'] = to_bool('$FEAT_BEADS')
cfg['beads']['_user_configured'] = True
cfg.setdefault('pr_shepherd', {})['enabled'] = to_bool('$FEAT_PR_SHEPHERD')
cfg.setdefault('metaswarm', {})['enabled'] = to_bool('$FEAT_METASWARM')
cfg['metaswarm']['_user_configured'] = True

json.dump(cfg, open(path, 'w'), indent=2)
print('OK')
" 2>/dev/null

echo ""
echo -e "${GREEN}  ✓${NC} Feature configuration saved to quality-config.json"

# ─── BEADS Setup (if enabled) ────────────────────────────────────────
if [[ "$FEAT_BEADS" == "yes" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} BEADS durable state tracking..."

  # Check Dolt prerequisites — local binary or remote server
  DOLT_AVAILABLE=false
  if command -v dolt &>/dev/null; then
    DOLT_AVAILABLE=true
    echo -e "${GREEN}  ✓${NC} Dolt installed locally"
  else
    # Check if a remote server is configured and reachable
    REMOTE_HOST=$(python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    print(cfg.get('beads', {}).get('server', {}).get('host', ''))
except:
    print('')
" 2>/dev/null)
    REMOTE_PORT=$(python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    print(cfg.get('beads', {}).get('server', {}).get('port', '3307'))
except:
    print('3307')
" 2>/dev/null)
    if [[ -n "$REMOTE_HOST" ]] && nc -z "$REMOTE_HOST" "$REMOTE_PORT" 2>/dev/null; then
      DOLT_AVAILABLE=true
      echo -e "${GREEN}  ✓${NC} Dolt server reachable at ${REMOTE_HOST}:${REMOTE_PORT}"
    fi
  fi

  if [[ "$DOLT_AVAILABLE" == false ]]; then
    echo -e "${YELLOW}  ⚠ Dolt is not reachable.${NC} BEADS needs Dolt as its database backend."
    echo -e "  Options:"
    echo -e "    1) Start Dolt via Docker now"
    echo -e "    2) Enter remote server connection details"
    echo -e "    3) I'll install Dolt manually and re-run"
    echo -e "    4) Skip BEADS for now (use file-based state)"
    read -p "  Choose [1/2/3/4]: " -n 1 -r
    echo ""
    if [[ "$REPLY" == "1" ]]; then
      if ! command -v docker &>/dev/null; then
        echo -e "${RED}  Docker not found.${NC} Continuing without BEADS."
      else
        DOLT_DATA_DIR="${HOME}/.dolt-server/data"
        DOLT_CFG_DIR="${HOME}/.dolt-server/config"
        mkdir -p "$DOLT_DATA_DIR" "$DOLT_CFG_DIR"
        DOLT_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 16)
        echo -e "  Starting Dolt SQL server via Docker..."
        docker run -d \
          --name beads-dolt-server \
          --restart unless-stopped \
          -e DOLT_ROOT_HOST='%' \
          -e DOLT_ROOT_PASSWORD="$DOLT_PASS" \
          -p 3307:3306 \
          -v "$DOLT_DATA_DIR":/var/lib/dolt \
          -v "$DOLT_CFG_DIR":/etc/dolt/servercfg.d \
          dolthub/dolt-sql-server:latest \
          2>/dev/null
        if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}  ✓${NC} Dolt server running in Docker (port 3307)"
          DOLT_AVAILABLE=true
          python3 -c "
import json
path = '$AGENT_PROCESS_DIR/quality-config.json'
try:
    cfg = json.load(open(path))
    cfg.setdefault('beads', {})['server'] = {'host': '127.0.0.1', 'port': 3307, 'user': 'root'}
    json.dump(cfg, open(path, 'w'), indent=2)
except:
    pass
" 2>/dev/null
          mkdir -p "${HOME}/.claude"
          python3 -c "
import configparser, os
path = os.path.expanduser('~/.claude/.beads-credentials')
cp = configparser.ConfigParser()
if os.path.exists(path):
    cp.read(path)
section = '127.0.0.1:3307'
if not cp.has_section(section):
    cp.add_section(section)
cp.set(section, 'password', '$DOLT_PASS')
with open(path, 'w') as f:
    cp.write(f)
os.chmod(path, 0o600)
" 2>/dev/null
          echo -e "${GREEN}  ✓${NC} Credentials saved to ~/.claude/.beads-credentials"
        else
          echo -e "${YELLOW}  ⊙${NC} Docker failed. Continuing without BEADS."
        fi
      fi
    elif [[ "$REPLY" == "2" ]]; then
      read -p "  Dolt server host: " REMOTE_INPUT_HOST
      read -p "  Dolt server port [3307]: " REMOTE_INPUT_PORT
      REMOTE_INPUT_PORT="${REMOTE_INPUT_PORT:-3307}"
      read -p "  Dolt user [root]: " REMOTE_INPUT_USER
      REMOTE_INPUT_USER="${REMOTE_INPUT_USER:-root}"
      if nc -z "$REMOTE_INPUT_HOST" "$REMOTE_INPUT_PORT" 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} Connected to ${REMOTE_INPUT_HOST}:${REMOTE_INPUT_PORT}"
        DOLT_AVAILABLE=true
        python3 -c "
import json
path = '$AGENT_PROCESS_DIR/quality-config.json'
try:
    cfg = json.load(open(path))
    cfg.setdefault('beads', {})['server'] = {
        'host': '$REMOTE_INPUT_HOST',
        'port': int('$REMOTE_INPUT_PORT'),
        'user': '$REMOTE_INPUT_USER'
    }
    json.dump(cfg, open(path, 'w'), indent=2)
except:
    pass
" 2>/dev/null
      else
        echo -e "${RED}  Cannot reach ${REMOTE_INPUT_HOST}:${REMOTE_INPUT_PORT}${NC}"
      fi
    elif [[ "$REPLY" == "3" ]]; then
      echo -e "${YELLOW}  Installation paused.${NC} Install Dolt, then re-run:"
      echo -e "    ${GREEN}brew install dolt && $0${NC}"
      exit 0
    fi
    # Option 4 or failed options — continue without BEADS
  fi

  # Install BEADS CLI (bd) if Dolt is available but bd is not
  if [[ "$DOLT_AVAILABLE" == true ]] && ! command -v bd &>/dev/null; then
    echo -e "  Installing BEADS CLI (bd)..."
    BEADS_INSTALLED=false
    if command -v npm &>/dev/null && npm install -g @beads/bd 2>/dev/null; then
      BEADS_INSTALLED=true
      echo -e "${GREEN}  ✓${NC} Installed BEADS CLI via npm"
    elif command -v brew &>/dev/null && brew install beads 2>/dev/null; then
      BEADS_INSTALLED=true
      echo -e "${GREEN}  ✓${NC} Installed BEADS CLI via Homebrew"
    elif command -v curl &>/dev/null && curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash 2>/dev/null; then
      BEADS_INSTALLED=true
      echo -e "${GREEN}  ✓${NC} Installed BEADS CLI via installer script"
    fi
    if [[ "$BEADS_INSTALLED" == false ]]; then
      echo -e "${YELLOW}  ⊙${NC} BEADS CLI install failed — install bd manually"
    fi
  elif [[ "$DOLT_AVAILABLE" == true ]]; then
    echo -e "${GREEN}  ✓${NC} BEADS ready (Dolt + bd available)"
  fi
fi


# Initialize BEADS database if bd is available, enabled, and .beads/ doesn't exist.
# Works with both local Dolt (command -v dolt) and remote/Docker Dolt (beads.server in config).
if command -v bd &>/dev/null && [[ ! -d "${TARGET_DIR}/.beads" ]]; then
  # Read config to check enabled + get server connection
  BEADS_INIT_INFO=$(python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    b = cfg.get('beads', {})
    if not b.get('enabled', False):
        print('disabled')
    else:
        server = b.get('server', {})
        host = server.get('host', '')
        port = server.get('port', '')
        user = server.get('user', '')
        has_local_dolt = True  # will be checked in shell
        print(f'enabled|{host}|{port}|{user}')
except:
    print('disabled')
" 2>/dev/null)

  if [[ "$BEADS_INIT_INFO" != "disabled" ]]; then
    # Parse server config
    IFS='|' read -r _ BHOST BPORT BUSER <<< "$BEADS_INIT_INFO"

    # Export env vars so bd init can connect to the right server
    [[ -n "$BHOST" ]] && export BEADS_DOLT_SERVER_HOST="$BHOST"
    [[ -n "$BPORT" ]] && export BEADS_DOLT_SERVER_PORT="$BPORT"
    [[ -n "$BUSER" ]] && export BEADS_DOLT_SERVER_USER="$BUSER"

    # Load password from credentials file
    CREDS_FILE="${HOME}/.claude/.beads-credentials"
    if [[ -f "$CREDS_FILE" && -n "$BHOST" ]]; then
      BPASS=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.claude/.beads-credentials'))
key = '${BHOST}:${BPORT:-3307}'
if cp.has_section(key) and cp.has_option(key, 'password'):
    print(cp.get(key, 'password'))
" 2>/dev/null) || true
      [[ -n "${BPASS:-}" ]] && export BEADS_DOLT_PASSWORD="$BPASS"
    fi

    # Check we can reach Dolt somehow (local binary OR remote server)
    DOLT_REACHABLE=false
    if [[ -n "$BHOST" ]]; then
      # Remote server configured — check TCP connectivity
      nc -z "$BHOST" "${BPORT:-3307}" 2>/dev/null && DOLT_REACHABLE=true
    elif command -v dolt &>/dev/null; then
      # Local Dolt binary
      DOLT_REACHABLE=true
    fi

    if [[ "$DOLT_REACHABLE" == true ]]; then
      (cd "$TARGET_DIR" && bd init 2>/dev/null) && \
        echo -e "${GREEN}  ✓${NC} Initialized BEADS database (.beads/)" || \
        echo -e "${YELLOW}  ⊙${NC} BEADS database initialization failed (will retry at runtime)"
    fi
  fi
fi

# ─── Metaswarm Setup (if enabled) ─────────────────────────────────────
if [[ "$FEAT_METASWARM" == "yes" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} Metaswarm integration..."
  if ls ~/.claude/commands/brainstorm.md &>/dev/null 2>&1 || ls .claude/commands/brainstorm.md &>/dev/null 2>&1; then
    echo -e "${GREEN}  ✓${NC} Metaswarm commands detected"
  else
    echo -e "  Installing metaswarm..."
    if command -v claude &>/dev/null; then
      # Add marketplace source first, then install the plugin
      claude plugin marketplace add dsifry/metaswarm-marketplace 2>/dev/null
      if claude plugin install metaswarm 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} Metaswarm installed"
      else
        echo -e "${YELLOW}  ⊙${NC} Auto-install failed. Install manually:"
        echo -e "    ${GREEN}claude plugin marketplace add dsifry/metaswarm-marketplace${NC}"
        echo -e "    ${GREEN}claude plugin install metaswarm${NC}"
      fi
    else
      echo -e "${YELLOW}  ⊙${NC} Claude CLI not found. Install metaswarm manually:"
      echo -e "    ${GREEN}claude plugin marketplace add dsifry/metaswarm-marketplace${NC}"
      echo -e "    ${GREEN}claude plugin install metaswarm${NC}"
    fi
  fi
fi


# Install .claude/commands/ (Claude Code command scripts)
echo ""
echo -e "${BLUE}▸${NC} Installing Claude Code commands..."

# Copy actual command files to .claude/commands/ (where Claude Code looks)
for cmd_file in "$SOURCE_DIR"/claude/commands/*.md; do
  if [[ -f "$cmd_file" ]]; then
    filename="$(basename "$cmd_file")"
    # Skip README.md - it's a placeholder for .agent_process/claude/commands/
    if [[ "$filename" != "README.md" ]]; then
      cp "$cmd_file" "$TARGET_DIR/.claude/commands/$filename"
      echo -e "${GREEN}  ✓${NC} Installed command: $filename"
    fi
  fi
done

# Clean up old command files from .agent_process/claude/commands/ (from previous installs)
# These should only be in .claude/commands/ now
if [[ -d "$AGENT_PROCESS_DIR/claude/commands" ]]; then
  REMOVED_COUNT=0
  for old_cmd in "$AGENT_PROCESS_DIR"/claude/commands/ap_*.md; do
    if [[ -f "$old_cmd" ]]; then
      rm -f "$old_cmd"
      REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
  done
  if [[ $REMOVED_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}  ⊙${NC} Removed $REMOVED_COUNT duplicate command files from .agent_process/claude/commands/"
  fi
fi

# Copy placeholder README to .agent_process/claude/commands/
if [[ -f "$SOURCE_DIR/claude/commands/README.md" ]]; then
  cp "$SOURCE_DIR/claude/commands/README.md" "$AGENT_PROCESS_DIR/claude/commands/"
  echo -e "${GREEN}  ✓${NC} Installed command reference in .agent_process/claude/commands/"
fi

# Copy documentation files to .agent_process/claude/
for doc_file in "$SOURCE_DIR"/claude/*.md; do
  if [[ -f "$doc_file" ]]; then
    cp "$doc_file" "$AGENT_PROCESS_DIR/claude/"
  fi
done

# Install orchestration files
echo ""
echo -e "${BLUE}▸${NC} Installing orchestration files..."

cp -r "$SOURCE_DIR"/orchestration/* "$AGENT_PROCESS_DIR/orchestration/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/orchestration" -type f | wc -l | tr -d ' ') orchestration files"

# Install process files (with special handling for user-configurable files)
echo ""
echo -e "${BLUE}▸${NC} Installing process files..."

for process_file in "$SOURCE_DIR"/process/*; do
  filename="$(basename "$process_file")"
  target_file="$AGENT_PROCESS_DIR/process/$filename"

  # Skip central sync config - it's configured with user prompts below
  if [[ "$filename" == "ap_release_central_sync.md" ]]; then
    continue
  fi

  # Install local_environment_instructions.md only if it doesn't exist (preserve user config)
  if [[ "$filename" == "local_environment_instructions.md" ]]; then
    if [[ ! -f "$target_file" ]]; then
      cp "$process_file" "$target_file"
      echo -e "${GREEN}  ✓${NC} Installed local environment instructions template"
    else
      echo -e "${YELLOW}  ⊙${NC} Preserving existing local environment instructions"
    fi
    continue
  fi

  # Install all other process files normally
  cp "$process_file" "$target_file"
done
echo -e "${GREEN}  ✓${NC} Installed process files"

# Install scripts
echo ""
echo -e "${BLUE}▸${NC} Installing scripts..."

cp -r "$SOURCE_DIR"/scripts/* "$AGENT_PROCESS_DIR/scripts/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/scripts" -type f | wc -l | tr -d ' ') script files"

# Install contract validators (used by evaluate-scope.sh)
if [[ -d "$SOURCE_DIR/test/contract" ]]; then
  for validator in "$SOURCE_DIR"/test/contract/validate-*.sh; do
    if [[ -f "$validator" ]]; then
      cp "$validator" "$AGENT_PROCESS_DIR/scripts/"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Installed contract validators"
fi

# Make hook scripts executable
chmod +x "$AGENT_PROCESS_DIR/scripts"/*.sh 2>/dev/null || true
chmod +x "$AGENT_PROCESS_DIR/scripts/after_edit"/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} Made scripts executable"

# Install templates
echo ""
echo -e "${BLUE}▸${NC} Installing templates..."

cp -r "$SOURCE_DIR"/templates/* "$AGENT_PROCESS_DIR/templates/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/templates" -type f | wc -l | tr -d ' ') template files"

# Install requirements_docs (template only - never overwrite user requirements)
echo ""
echo -e "${BLUE}▸${NC} Installing requirements documentation..."

# Check for existing user requirements files
EXISTING_REQS=$(find "$AGENT_PROCESS_DIR/requirements_docs" -type f -name "*.md" ! -name "_TEMPLATE_requirements.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$EXISTING_REQS" -gt 0 ]]; then
  echo -e "${YELLOW}  ⊙${NC} Preserving $EXISTING_REQS existing requirements file(s)"
fi

# Only copy the template file (never overwrite user's requirements)
cp "$SOURCE_DIR/requirements_docs/_TEMPLATE_requirements.md" "$AGENT_PROCESS_DIR/requirements_docs/"
echo -e "${GREEN}  ✓${NC} Installed/updated requirements template"

# Only copy work/ template files if work/ was just created
if [[ ! -f "$AGENT_PROCESS_DIR/work/current_iteration.conf.template" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} Installing work/ templates..."

  cp "$SOURCE_DIR/work/current_iteration.conf.template" "$AGENT_PROCESS_DIR/work/"
  echo -e "${GREEN}  ✓${NC} Installed iteration config template"

  # Copy master_requirements.md if it exists in source
  if [[ -f "$SOURCE_DIR/work/master_requirements.md" ]]; then
    cp "$SOURCE_DIR/work/master_requirements.md" "$AGENT_PROCESS_DIR/work/"
    echo -e "${GREEN}  ✓${NC} Installed master requirements template"
  fi
fi

# Documentation files are already installed above (commands.md, hooks.md, README.md)
echo ""
echo -e "${BLUE}▸${NC} Installing documentation..."
echo -e "${GREEN}  ✓${NC} Installed documentation files"

# Copy main README to .agent_process/
if [[ -f "$SOURCE_DIR/README.md" ]]; then
  cp "$SOURCE_DIR/README.md" "$AGENT_PROCESS_DIR/"
  echo -e "${GREEN}  ✓${NC} Installed README.md"
fi

# Central Repo Sync Configuration
echo ""
echo -e "${BLUE}▸${NC} Central repository sync configuration..."

# Check if config already exists
EXISTING_ENABLED=""
EXISTING_CENTRAL_REPO_PATH=""
EXISTING_PROJECT_FOLDER=""

if [[ -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" ]]; then
  # Extract existing values (only look in first 20 lines to avoid matching docs)
  EXISTING_ENABLED=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^ENABLED:" | sed 's/ENABLED: *//' | tr -d ' ') || true
  EXISTING_CENTRAL_REPO_PATH=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^CENTRAL_REPO_PATH:" | sed 's/CENTRAL_REPO_PATH: *//' | tr -d ' ') || true
  EXISTING_PROJECT_FOLDER=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^PROJECT_FOLDER:" | sed 's/PROJECT_FOLDER: *//' | tr -d ' ') || true

  # Check if this is the old format (no ENABLED field but has real paths)
  if [[ -z "$EXISTING_ENABLED" && -n "$EXISTING_CENTRAL_REPO_PATH" && "$EXISTING_CENTRAL_REPO_PATH" != "<CENTRAL_REPO_PATH>" && "$EXISTING_CENTRAL_REPO_PATH" != "<not_configured>" ]]; then
    echo "" >&2
    echo -e "${RED}  ✗ ERROR: Old central sync config format detected${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}  Missing ENABLED: field in:${NC}" >&2
    echo -e "  $AGENT_PROCESS_DIR/process/ap_release_central_sync.md" >&2
    echo "" >&2
    echo -e "${YELLOW}  To fix, add this line after '## Configuration' section:${NC}" >&2
    echo -e "  ${GREEN}ENABLED: true${NC}" >&2
    echo "" >&2
    echo -e "  Current format:" >&2
    echo -e "  ${YELLOW}CENTRAL_REPO_PATH: $EXISTING_CENTRAL_REPO_PATH${NC}" >&2
    echo -e "  ${YELLOW}PROJECT_FOLDER: $EXISTING_PROJECT_FOLDER${NC}" >&2
    echo "" >&2
    echo -e "  Should be:" >&2
    echo -e "  ${GREEN}ENABLED: true${NC}" >&2
    echo -e "  ${GREEN}CENTRAL_REPO_PATH: $EXISTING_CENTRAL_REPO_PATH${NC}" >&2
    echo -e "  ${GREEN}PROJECT_FOLDER: $EXISTING_PROJECT_FOLDER${NC}" >&2
    echo "" >&2
    echo -e "  Then run install.sh again." >&2
    echo "" >&2
    exit 1
  elif [[ "$EXISTING_ENABLED" == "true" && -n "$EXISTING_CENTRAL_REPO_PATH" && "$EXISTING_CENTRAL_REPO_PATH" != "<CENTRAL_REPO_PATH>" && "$EXISTING_CENTRAL_REPO_PATH" != "<not_configured>" ]]; then
    # New format with enabled config - update template
    echo -e "${YELLOW}  ⊙${NC} Updating template, preserving enabled config"
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|ENABLED:.*|ENABLED: true|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|CENTRAL_REPO_PATH:.*|CENTRAL_REPO_PATH: $EXISTING_CENTRAL_REPO_PATH|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|PROJECT_FOLDER:.*|PROJECT_FOLDER: $EXISTING_PROJECT_FOLDER|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"
    echo -e "${GREEN}  ✓${NC} Updated central sync config (enabled: $EXISTING_PROJECT_FOLDER)"
    EXISTING_ENABLED="true"  # Keep this set so we don't prompt below
  elif [[ "$EXISTING_ENABLED" == "false" ]]; then
    # Already has disabled config - update template but keep disabled
    echo -e "${YELLOW}  ⊙${NC} Updating template, keeping disabled state"
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|ENABLED:.*|ENABLED: false|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|CENTRAL_REPO_PATH:.*|CENTRAL_REPO_PATH: <not_configured>|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|PROJECT_FOLDER:.*|PROJECT_FOLDER: <not_configured>|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"
    echo -e "${GREEN}  ✓${NC} Updated central sync config (disabled)"
    EXISTING_ENABLED="false"  # Set so we don't prompt below
  else
    # Has file but no real values - treat as new install
    EXISTING_ENABLED=""
  fi
fi

# If no existing enabled config, prompt user
if [[ -z "$EXISTING_ENABLED" ]]; then
  echo ""
  echo -e "${YELLOW}  Optional: Configure central repository sync for agent process files.${NC}"
  echo -e "  This is useful if you track .agent_process files in a separate central repo."
  echo ""
  read -p "  Configure central repo sync? [y/N] " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""

    # Prompt for central repo path (required)
    while [[ -z "$CENTRAL_REPO_PATH" ]]; do
      read -p "  Central repo path (e.g., ~/PycharmProjects/agent-process-central): " CENTRAL_REPO_PATH
      if [[ -z "$CENTRAL_REPO_PATH" ]]; then
        echo -e "  ${RED}Error: Central repo path is required${NC}"
      fi
    done

    # Get project folder name - default to target directory name
    DEFAULT_PROJECT_FOLDER="$(basename "$TARGET_DIR")"
    read -p "  Project folder name in central repo [$DEFAULT_PROJECT_FOLDER]: " PROJECT_FOLDER
    PROJECT_FOLDER="${PROJECT_FOLDER:-$DEFAULT_PROJECT_FOLDER}"

    # Expand tilde in path (store as-is with tilde for portability)
    # Note: We keep the tilde in the config for portability across machines

    # Copy template and substitute values - ENABLED: true
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|ENABLED:.*|ENABLED: true|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|CENTRAL_REPO_PATH:.*|CENTRAL_REPO_PATH: $CENTRAL_REPO_PATH|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|PROJECT_FOLDER:.*|PROJECT_FOLDER: $PROJECT_FOLDER|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"

    echo -e "${GREEN}  ✓${NC} Created central sync config (enabled)"
  else
    # Copy template and set ENABLED: false - no path configuration needed
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|ENABLED:.*|ENABLED: false|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|CENTRAL_REPO_PATH:.*|CENTRAL_REPO_PATH: <not_configured>|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|PROJECT_FOLDER:.*|PROJECT_FOLDER: <not_configured>|g" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"

    echo -e "${GREEN}  ✓${NC} Created central sync config (disabled)"
  fi
fi

# Install bds wrapper (BEADS scoped CLI)
if [[ -f "$SOURCE_DIR/bin/bds" ]]; then
  # Install to ~/.local/bin (user-local, no sudo needed)
  INSTALL_BIN="${HOME}/.local/bin"
  mkdir -p "$INSTALL_BIN"
  cp "$SOURCE_DIR/bin/bds" "$INSTALL_BIN/bds"
  chmod +x "$INSTALL_BIN/bds"
  if echo "$PATH" | grep -q "$INSTALL_BIN"; then
    echo -e "${GREEN}  ✓${NC} Installed bds wrapper to $INSTALL_BIN/bds"
  else
    echo -e "${GREEN}  ✓${NC} Installed bds wrapper to $INSTALL_BIN/bds"
    echo -e "${YELLOW}  Note:${NC} Add to PATH if not already: export PATH=\"$INSTALL_BIN:\$PATH\""
  fi
fi

# Installation complete
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Installation Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Review the installed files in:"
echo -e "     ${GREEN}$TARGET_DIR/.claude/commands/${NC}"
echo -e "     ${GREEN}$AGENT_PROCESS_DIR/${NC}"
if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
  echo -e "     ${YELLOW}(symlink to $SYMLINK_TARGET)${NC}"
fi
echo ""
echo "  2. Restart Claude Code to load new commands:"
echo -e "     ${BLUE}/clear${NC} or restart the session"
echo ""
echo "  3. Verify commands are available:"
echo -e "     ${BLUE}/ap_exec${NC}, ${BLUE}/ap_iteration_results${NC}, ${BLUE}/ap_release${NC}, ${BLUE}/ap_changelog_init${NC}"
echo ""
echo "  4. Create your first scope:"
echo -e "     • Create ${GREEN}requirements_docs/my_feature_requirements.md${NC}"
echo -e "     • Plan with ${BLUE}orchestration/01_plan_scope_prompt.md${NC}"
echo -e "     • Execute with ${BLUE}/ap_exec my_feature iteration_01${NC}"
echo ""
echo "  5. Set up scope-specific validation:"
echo -e "     • Copy ${GREEN}scripts/after_edit/validate-scope.sh.template${NC}"
echo -e "     • Create ${GREEN}scripts/after_edit/validate-my_feature.sh${NC}"
echo -e "     • Make executable: ${BLUE}chmod +x scripts/after_edit/validate-my_feature.sh${NC}"
echo ""
if [[ -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" ]]; then
  # Check if central sync is enabled (only look in first 20 lines to avoid matching docs)
  SYNC_ENABLED=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^ENABLED:" | sed 's/ENABLED: *//' | tr -d ' ')

  if [[ "$SYNC_ENABLED" == "true" ]]; then
    echo -e "  ${GREEN}✓${NC} Central repo sync: ${GREEN}enabled${NC}"
    echo -e "     Config: ${GREEN}$AGENT_PROCESS_DIR/process/ap_release_central_sync.md${NC}"

    # Check if .agent_process is a symlink (central repo setup)
    if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
      # Read central repo path from config (only look in first 20 lines)
      CENTRAL_PATH=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^CENTRAL_REPO_PATH:" | sed 's/CENTRAL_REPO_PATH: *//' | tr -d ' ')
      PROJECT_FOLDER=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^PROJECT_FOLDER:" | sed 's/PROJECT_FOLDER: *//' | tr -d ' ')

      if [[ -n "$CENTRAL_PATH" && "$CENTRAL_PATH" != "<CENTRAL_REPO_PATH>" && "$CENTRAL_PATH" != "<not_configured>" ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠ ACTION REQUIRED:${NC} Central repo may have uncommitted changes"
        echo -e "     Run these commands to sync the central repo:"
        echo ""
        echo -e "     ${BLUE}cd $CENTRAL_PATH${NC}"
        echo -e "     ${BLUE}git add $PROJECT_FOLDER/${NC}"
        echo -e "     ${BLUE}git commit -m \"chore($PROJECT_FOLDER): update to ai_agent_process v$(cat "$SOURCE_DIR/VERSION")\"${NC}"
        echo -e "     ${BLUE}git push origin main${NC}"
        echo -e "     ${BLUE}cd -${NC}"
        echo ""
      fi
    fi
  else
    echo -e "  ${YELLOW}⊙${NC} Central repo sync: ${YELLOW}disabled${NC}"
    echo -e "     This project manages .agent_process/ locally"
  fi
  echo ""
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📖 Documentation: ${GREEN}$AGENT_PROCESS_DIR/claude/commands.md${NC}"
echo -e "🔧 Hooks guide: ${GREEN}$AGENT_PROCESS_DIR/claude/hooks.md${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Scroll up to review feature configuration and check for any warnings or errors."
echo ""
