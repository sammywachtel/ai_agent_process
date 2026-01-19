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

# Install process files (excluding central sync config - configured separately below)
echo ""
echo -e "${BLUE}▸${NC} Installing process files..."

for process_file in "$SOURCE_DIR"/process/*; do
  filename="$(basename "$process_file")"
  # Skip the central sync config - it's configured with user prompts below
  if [[ "$filename" != "ap_release_central_sync.md" ]]; then
    cp "$process_file" "$AGENT_PROCESS_DIR/process/"
  fi
done
echo -e "${GREEN}  ✓${NC} Installed process files"

# Install scripts
echo ""
echo -e "${BLUE}▸${NC} Installing scripts..."

cp -r "$SOURCE_DIR"/scripts/* "$AGENT_PROCESS_DIR/scripts/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/scripts" -type f | wc -l | tr -d ' ') script files"

# Make hook scripts executable
chmod +x "$AGENT_PROCESS_DIR/scripts"/*.sh 2>/dev/null || true
chmod +x "$AGENT_PROCESS_DIR/scripts/after_edit"/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} Made hook scripts executable"

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
