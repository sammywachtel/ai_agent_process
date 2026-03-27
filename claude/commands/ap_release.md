---
description: Update changelog, create PR, and optionally tag a release
argument-hint: [noscope] pr | beta | release [patch|minor|major] [--shepherd|--no-shepherd]
---

## Local Environment Instructions

**BEFORE proceeding, check for local environment instructions:**

```bash
cat .agent_process/process/local_environment_instructions.md 2>/dev/null
```

If this file exists, follow those instructions in addition to the workflow below.

---

## Arguments

**`$1` (context)** - Optional. Use `noscope` to skip scope context and analyze git diff instead.

**`$1` or `$2` (mode)** - Required. One of:
- `pr` - Update changelog under [Unreleased], create PR, no tag
- `beta` - Move [Unreleased] to beta version, create beta tag, create PR
- `release` - Move [Unreleased] to new version, update version files, tag release

**Last arg (version_type)** - Required for `release` mode only:
- `patch` (1.0.0 → 1.0.1) | `minor` (1.0.0 → 1.1.0) | `major` (1.0.0 → 2.0.0)

**`--shepherd` / `--no-shepherd`** - Optional flag (anywhere in args).

**Examples:**
- `/ap_release pr` — PR with changelog update
- `/ap_release pr --shepherd` — PR + shepherd monitoring
- `/ap_release noscope pr` — No-scope mode
- `/ap_release release minor` — Minor release
- `/ap_release beta` — Beta release

---

## Mode Reference

| Mode | Changelog | PR | Build Tag | Release Tag | Version Bump |
|------|-----------|----|-----------|--------------|----|
| `pr` | [Unreleased] | Yes | `build/N` | No | No |
| `beta` | [X.Y.Z-beta.N] | Yes | `build/N` | `vX.Y.Z-beta.N` | No |
| `release` | [X.Y.Z] | Yes | `build/N` | `vX.Y.Z` | Yes |

---

## Your Role

You are the release coordinator. This runs AFTER orchestrator approval — it's the final step before code is merged and optionally released.

---

## Workflow

Read and follow the release coordinator:

```
.agent_process/orchestration/coordinators/release.md
```

This runs:
- **Parallel:** Gather context + detect project structure (2 cheap sub-agents)
- **Step 03:** Get current version, calculate next
- **Step 04:** Classify changes, draft changelog entry
- **Step 05:** Update CHANGELOG.md (and USER_CHANGELOG.md for beta/release)
- **Step 06:** Update version files (release mode only — conditional)
- **Steps 07-09:** Commit → tag → push → PR (MUST BE SEQUENTIAL)
- **Step 095:** PR shepherd (conditional — config/flag)
- **Step 10:** Report completion

All outputs go to `.run/release/`.

---

## Workflow Summary

```
ap_release [noscope] {mode} [{version}] [--shepherd]
  │
  ├── Parallel: Context + Structure (cheap)
  ├── Get version (cheap)
  ├── Classify changes (capable)
  ├── Update changelog (capable)
  ├── Update version files (cheap, release only)
  ├── Commit → Tag → Push → PR (capable, SEQUENTIAL)
  ├── PR Shepherd (capable, conditional)
  └── Report (cheap)
```

---

**Remember:** This runs AFTER approval. It's the final step before merge.
