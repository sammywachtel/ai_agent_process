# Step 1.25: Assess Work Unit Decomposition

**Model tier:** capable
**Tools needed:** Read
**Input:** scope, iteration, context output (`.run/execution/01-context.md`)
**Output:** `.run/execution/0125-decomposition.md`

---

## Your Task

Determine if this scope benefits from structured work unit decomposition. This adds coordination overhead, so it's only triggered when the overhead pays for itself.

## Gate: Check Config

Read `quality-config.json`. If `work_unit_decomposition.enabled` is `false`, write "skip" to output and stop.

## Gate: Sub-iterations Skip

If this is a sub-iteration (`_a`, `_b`, `_c`), write "skip — sub-iterations execute directly against specific fixes" and stop.

## Trigger Conditions (ALL must be true)

1. Scope touches **N+ implementation files** where N = `trigger_threshold_files` (default: 3). Count only source code, configs, and tests — exclude process artifacts.
2. Files span **M+ system layers** where M = `trigger_threshold_layers` (default: 2)

**Layer detection:**

| Pattern | Layer |
|---------|-------|
| `migrations/`, `.sql`, schema | Database |
| Backend API, routes, services | Backend |
| Frontend components, `.tsx` | Frontend |
| Test files (`__tests__/`, `.test.`) | Tests |
| Config, Docker, CI/CD | Infrastructure |
| Documentation (`docs/`, `*.md`) | Docs |

## Output Format

Write to `.run/execution/0125-decomposition.md`:

**If skip:**
```markdown
# Work Unit Decomposition

DECOMPOSE: skip
**Reason:** {config disabled / sub-iteration / below threshold}
```

**If triggered:**
```markdown
# Work Unit Decomposition

DECOMPOSE: yes
**Files:** {count}
**Layers:** {list}

## Work Units

### WU-001: {Description}
- **Files:** `path/to/file1`, `path/to/file2`
- **Layer:** {layer}
- **Dependencies:** None
- **Criteria addressed:** AC1, AC2
- **Agent:** {suggested agent type}

### WU-002: {Description}
- **Files:** `path/to/component.tsx`
- **Layer:** Frontend
- **Dependencies:** None (parallel with WU-001)
- **Criteria addressed:** AC3
- **Agent:** {suggested agent type}

### Execution Order
WU-001 ──┐
          ├──→ WU-003
WU-002 ──┘
```

**Rules:**
- Soft cap: 3-6 work units (more suggests the scope should have been split)
- Each unit must be independently validatable
- No cycles in the DAG
- Every criterion addressed by at least one unit
