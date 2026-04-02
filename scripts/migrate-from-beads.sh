#!/usr/bin/env bash
# migrate-from-beads.sh — Discover and migrate BEADS artifacts to the new system
#
# Interactive, per-step permission. Discovers what exists, presents findings,
# asks before each action. Never deletes source artifacts — cleanup is manual.
#
# Usage:
#   bash scripts/migrate-from-beads.sh [target_dir]
#
# If target_dir is omitted, operates on the current directory.

set -uo pipefail

# -- Colors (because staring at monochrome migration output is depressing) --
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_DIR="${1:-.}"
AP_DIR="$TARGET_DIR/.agent_process"

if [[ ! -d "$AP_DIR" ]]; then
  echo -e "${RED}Error: .agent_process/ not found in $TARGET_DIR${NC}"
  echo "Run install.sh first, then migrate."
  exit 1
fi

KNOWLEDGE_DIR="$AP_DIR/knowledge"
mkdir -p "$KNOWLEDGE_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  BEADS → GitHub Issues Migration                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Discovering BEADS artifacts..."
echo ""

# -- Discovery --
found_knowledge=0
found_bd_remember=0
found_beads_state=0
found_iteration_conf=0
found_quality_beads=0
found_work_unit_conf=0

knowledge_files=()
beads_state_files=()
iteration_conf_files=()
work_unit_conf_files=()

# 1. .beads/knowledge/*.jsonl
if ls "$TARGET_DIR/.beads/knowledge/"*.jsonl 2>/dev/null | head -1 >/dev/null 2>&1; then
  knowledge_count=$(cat "$TARGET_DIR/.beads/knowledge/"*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  knowledge_file_count=$(ls "$TARGET_DIR/.beads/knowledge/"*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  mapfile -t knowledge_files < <(ls "$TARGET_DIR/.beads/knowledge/"*.jsonl 2>/dev/null)
  found_knowledge=1
  echo -e "  ${GREEN}✓${NC} .beads/knowledge/ — $knowledge_count entries across $knowledge_file_count files"
else
  echo -e "  ${RED}✗${NC} No .beads/knowledge/ JSONL files found"
fi

# 2. bd remember data
if command -v bd &>/dev/null; then
  bd_memories=$(bd remember list 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$bd_memories" -gt 0 ]]; then
    found_bd_remember=1
    echo -e "  ${GREEN}✓${NC} bd remember — $bd_memories stored memories"
  else
    echo -e "  ${RED}✗${NC} bd remember — no stored memories"
  fi
else
  echo -e "  ${RED}✗${NC} bd CLI not installed (skipping bd remember)"
fi

# 3. .beads-state files
mapfile -t beads_state_files < <(find "$TARGET_DIR" -name '.beads-state' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)
if [[ ${#beads_state_files[@]} -gt 0 ]]; then
  found_beads_state=1
  echo -e "  ${GREEN}✓${NC} ${#beads_state_files[@]} .beads-state files"
else
  echo -e "  ${RED}✗${NC} No .beads-state files found"
fi

# 4. current_iteration.conf files
mapfile -t iteration_conf_files < <(find "$TARGET_DIR" -name 'current_iteration.conf' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)
if [[ ${#iteration_conf_files[@]} -gt 0 ]]; then
  found_iteration_conf=1
  echo -e "  ${GREEN}✓${NC} ${#iteration_conf_files[@]} current_iteration.conf files"
else
  echo -e "  ${RED}✗${NC} No current_iteration.conf files found"
fi

# 5. quality-config.json beads section
if python3 -c "import json; c=json.load(open('$AP_DIR/quality-config.json')); assert 'beads' in c" 2>/dev/null; then
  found_quality_beads=1
  echo -e "  ${GREEN}✓${NC} quality-config.json has beads section"
else
  echo -e "  ${RED}✗${NC} quality-config.json has no beads section"
fi

# 6. current_work_unit.conf files
mapfile -t work_unit_conf_files < <(find "$TARGET_DIR" -name 'current_work_unit.conf' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)
if [[ ${#work_unit_conf_files[@]} -gt 0 ]]; then
  found_work_unit_conf=1
  echo -e "  ${GREEN}✓${NC} ${#work_unit_conf_files[@]} current_work_unit.conf files (noted, no auto-conversion)"
else
  echo -e "  ${RED}✗${NC} No current_work_unit.conf files found"
fi

echo ""

# -- Check if there's anything to do --
total_found=$((found_knowledge + found_bd_remember + found_beads_state + found_iteration_conf + found_quality_beads))
if [[ $total_found -eq 0 ]]; then
  echo -e "${GREEN}Nothing to migrate. You're already clean.${NC}"
  exit 0
fi

# -- Helper: ask Y/n --
ask_yn() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [Y/n] " answer
  [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# -- Migration Steps --

# 1. Knowledge files
if [[ $found_knowledge -eq 1 ]]; then
  echo ""
  if ask_yn "Migrate .beads/knowledge/ → .agent_process/knowledge/?"; then
    migrated=0
    skipped=0
    for src_file in "${knowledge_files[@]}"; do
      filename=$(basename "$src_file")
      dst_file="$KNOWLEDGE_DIR/$filename"

      if [[ -f "$dst_file" ]]; then
        # Merge: skip entries with duplicate IDs
        while IFS= read -r line; do
          entry_id=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('id',''))" 2>/dev/null)
          if [[ -n "$entry_id" ]] && grep -q "\"id\":\"$entry_id\"" "$dst_file" 2>/dev/null; then
            ((skipped++))
          else
            echo "$line" >> "$dst_file"
            ((migrated++))
          fi
        done < "$src_file"
      else
        cp "$src_file" "$dst_file"
        migrated=$((migrated + $(wc -l < "$src_file" | tr -d ' ')))
      fi
    done
    echo -e "  ${GREEN}Copied $migrated entries ($skipped duplicates skipped)${NC}"
  else
    echo "  Skipped."
  fi
fi

# 2. bd remember export
if [[ $found_bd_remember -eq 1 ]]; then
  echo ""
  if ask_yn "Export bd remember data → .agent_process/knowledge/decisions.jsonl?"; then
    dst_file="$KNOWLEDGE_DIR/decisions.jsonl"
    exported=0
    # bd remember list outputs one memory per line — convert to JSONL
    while IFS= read -r memory; do
      [[ -z "$memory" ]] && continue
      # Wrap in metaswarm-compatible schema
      python3 -c "
import json, hashlib, datetime
mem = '''$memory'''
entry = {
    'id': hashlib.sha256(mem.encode()).hexdigest()[:12],
    'type': 'decision',
    'fact': mem,
    'recommendation': '',
    'confidence': 0.7,
    'provenance': 'bd-remember-migration',
    'tags': ['migrated'],
    'affectedFiles': []
}
print(json.dumps(entry))
" >> "$dst_file"
      ((exported++))
    done < <(bd remember list 2>/dev/null)
    echo -e "  ${GREEN}Exported $exported entries to decisions.jsonl${NC}"
  else
    echo "  Skipped."
  fi
fi

# 3. .beads-state → scope-events.log
if [[ $found_beads_state -eq 1 ]]; then
  echo ""
  if ask_yn "Convert .beads-state → scope-events.log?"; then
    converted=0
    for state_file in "${beads_state_files[@]}"; do
      # Determine scope from path
      scope_dir=$(dirname "$state_file")
      scope_name=$(basename "$(dirname "$scope_dir")" 2>/dev/null || basename "$scope_dir")

      events_log="$AP_DIR/work/scope-events.log"
      mkdir -p "$(dirname "$events_log")"

      # Convert each breadcrumb line to scope-events format
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Best-effort conversion: BEADS breadcrumbs → scope events
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "$timestamp|$scope_name|MIGRATED|$line" >> "$events_log"
      done < "$state_file"
      ((converted++))
    done
    echo -e "  ${GREEN}Converted $converted files${NC}"
  else
    echo "  Skipped."
  fi
fi

# 4. current_iteration.conf → scope-tracker.jsonl
if [[ $found_iteration_conf -eq 1 ]]; then
  echo ""
  if ask_yn "Convert current_iteration.conf → scope-tracker.jsonl entries?"; then
    tracker_file="$AP_DIR/work/scope-tracker.jsonl"
    mkdir -p "$(dirname "$tracker_file")"
    converted=0
    for conf_file in "${iteration_conf_files[@]}"; do
      scope_dir=$(dirname "$conf_file")
      scope_name=$(basename "$scope_dir")
      iteration=$(cat "$conf_file" 2>/dev/null | tr -d '[:space:]')
      [[ -z "$iteration" ]] && iteration="unknown"

      # Check if scope already in tracker
      if [[ -f "$tracker_file" ]] && grep -q "\"scope\":\"$scope_name\"" "$tracker_file" 2>/dev/null; then
        echo "  Scope '$scope_name' already in tracker, skipping"
        continue
      fi

      python3 -c "
import json, datetime
entry = {
    'scope': '$scope_name',
    'iteration': '$iteration',
    'status': 'migrated',
    'updated': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
}
print(json.dumps(entry))
" >> "$tracker_file"
      ((converted++))
    done
    echo -e "  ${GREEN}Converted $converted entries to scope-tracker.jsonl${NC}"
  else
    echo "  Skipped."
  fi
fi

# 5. Remove beads section from quality-config.json
if [[ $found_quality_beads -eq 1 ]]; then
  echo ""
  if ask_yn "Remove beads section from quality-config.json?"; then
    python3 -c "
import json
with open('$AP_DIR/quality-config.json') as f:
    cfg = json.load(f)
cfg.pop('beads', None)
with open('$AP_DIR/quality-config.json', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"
    echo -e "  ${GREEN}Done${NC}"
  else
    echo "  Skipped."
  fi
fi

# -- Summary --
echo ""
echo -e "${GREEN}Migration complete.${NC}"
echo ""
echo -e "${YELLOW}⚠ CLEANUP REMINDERS:${NC}"
echo -e "  - Delete .beads/ directory:       ${BLUE}rm -rf $TARGET_DIR/.beads/${NC}"
echo -e "  - Delete credentials file:        ${BLUE}rm ~/.config/beads/credentials${NC}"
echo -e "  - Uninstall Dolt (optional):      ${BLUE}brew uninstall dolt${NC}"
echo -e "  - Uninstall bd CLI (optional):    ${BLUE}npm uninstall -g beads${NC}"
echo -e "  - Tear down Dolt server (if any): Check your infrastructure docs"
echo ""
echo "These cleanups are manual — this script never deletes source artifacts."
