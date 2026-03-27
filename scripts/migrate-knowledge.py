#!/usr/bin/env python3
"""
migrate-knowledge.py — Migrate legacy AP knowledge entries to .beads/knowledge/

Converts entries from .agent_process/knowledge/ (legacy AP schema) to
.beads/knowledge/ (metaswarm-compatible schema). Idempotent — skips
entries whose id already exists in the destination.

Usage:
  python3 scripts/migrate-knowledge.py                          # auto-detect in current dir
  python3 scripts/migrate-knowledge.py /path/to/project         # specify project root
  python3 scripts/migrate-knowledge.py --src /a/knowledge --dst /b/knowledge  # explicit paths

Called by install.sh automatically, but can be run manually anytime.
"""

import json
import os
import sys
import glob
import argparse


def find_project_root(start="."):
    """Walk up to find .agent_process/ directory."""
    d = os.path.abspath(start)
    while d != "/":
        if os.path.isdir(os.path.join(d, ".agent_process")):
            return d
        d = os.path.dirname(d)
    return None


def migrate(src, dst, verbose=True):
    """Migrate entries from src → dst, returns count of migrated entries."""
    if not os.path.isdir(src):
        if verbose:
            print(f"Source not found: {src}")
        return 0
    if not os.path.isdir(dst):
        if verbose:
            print(f"Destination not found: {dst}")
            print(f"Create it first: mkdir -p {dst}")
        return 0

    # Build set of existing ids in destination to avoid duplicates
    existing_ids = set()
    for f in glob.glob(f"{dst}/*.jsonl"):
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or line.startswith('{"_schema"'):
                    continue
                try:
                    existing_ids.add(json.loads(line).get("id", ""))
                except Exception:
                    pass

    # Type mapping from filename to entry type
    type_map = {
        "patterns": "pattern",
        "gotchas": "gotcha",
        "decisions": "decision",
        "anti-patterns": "anti_pattern",
    }

    migrated = 0
    skipped = 0

    for f in glob.glob(f"{src}/*.jsonl"):
        basename = os.path.basename(f)
        stem = basename.replace(".jsonl", "")
        entry_type = type_map.get(stem, stem)
        dst_file = os.path.join(dst, basename)

        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith('{"_schema"') or line.startswith("#"):
                    continue
                try:
                    entry = json.loads(line)
                except Exception:
                    continue

                eid = entry.get("id", "")
                if not eid:
                    continue
                if eid in existing_ids:
                    skipped += 1
                    if verbose:
                        print(f"  skip: {eid} (already in destination)")
                    continue

                # Already metaswarm format? Pass through as-is
                if "fact" in entry and "recommendation" in entry:
                    new_entry = entry
                else:
                    # Convert legacy AP schema → metaswarm-compatible
                    date = entry.get("date", "")
                    new_entry = {
                        "id": eid,
                        "type": entry_type,
                        "fact": entry.get("summary", entry.get("content", "")),
                        "recommendation": entry.get("detail", ""),
                        "confidence": entry.get("confidence", "medium"),
                        "provenance": [{
                            "source": "agent",
                            "reference": entry.get("source_iteration", ""),
                            "date": date,
                        }],
                        "tags": [entry.get("scope", "general")],
                        "affectedFiles": [],
                        "createdAt": f"{date}T00:00:00Z" if date else "",
                        "updatedAt": f"{date}T00:00:00Z" if date else "",
                    }

                with open(dst_file, "a") as out:
                    out.write(json.dumps(new_entry) + "\n")
                existing_ids.add(eid)
                migrated += 1
                if verbose:
                    print(f"  migrated: {eid} → {basename}")

    if verbose:
        print(f"\nMigrated: {migrated}, Skipped: {skipped} (already existed)")

    return migrated


def main():
    parser = argparse.ArgumentParser(description="Migrate AP knowledge to BEADS format")
    parser.add_argument("project", nargs="?", default=".", help="Project root (default: current dir)")
    parser.add_argument("--src", help="Source knowledge dir (default: .agent_process/knowledge/)")
    parser.add_argument("--dst", help="Destination knowledge dir (default: .beads/knowledge/)")
    parser.add_argument("-q", "--quiet", action="store_true", help="Only print the count")
    args = parser.parse_args()

    root = find_project_root(args.project)
    if not root and not (args.src and args.dst):
        print("Error: Not in an AP project (no .agent_process/ found). Specify --src and --dst explicitly.")
        sys.exit(1)

    src = args.src or os.path.join(root, ".agent_process", "knowledge")
    dst = args.dst or os.path.join(root, ".beads", "knowledge")

    verbose = not args.quiet
    if verbose:
        print(f"Source: {src}")
        print(f"Destination: {dst}")
        print()

    count = migrate(src, dst, verbose=verbose)

    if args.quiet:
        print(count)

    sys.exit(0 if count >= 0 else 1)


if __name__ == "__main__":
    main()
