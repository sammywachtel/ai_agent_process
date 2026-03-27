# Deck 2: Before & After — The Decomposition

---

## Slide 1: The Problem with Monolithic Prompts

**Real failure:** The orchestrator was given an 890-line planning prompt. It created a 25-file, 8-criteria scope without ever running the 5-second scope check — because the check was buried at line 7 inside 890 lines of other instructions.

```
┌─────────────────────────────────────────────────┐
│  01_plan_scope_instructions.md (890 lines)       │
│                                                  │
│  Line 7:   ← CRITICAL: Scope sizing check       │
│  Line 45:  ← Derive folder name                 │
│  Line 130: ← Clarify the brief                  │
│  Line 255: ← Review actual code                 │  ← Agent attention
│  Line 340: ← Create frozen criteria              │     drops off here
│  Line 480: ← Documentation impact                │
│  Line 650: ← Design review gate                  │
│  Line 835: ← Handoff summary                    │
│                                                  │
│  Agent sees ALL 890 lines. Optimizes for the     │
│  most prominent instructions. Skips the rest.    │
└─────────────────────────────────────────────────┘
```

**The pattern repeated across all workflows:**
- Planning: 890 lines
- Execution: 1,205 lines
- Review: 1,328 lines
- Release: 1,189 lines
- Brainstorm: 352 lines

**Total: ~4,960 lines of monolithic prompts.**

---

## Slide 2: The Solution — Coordinator + Step Files

```
BEFORE                              AFTER
──────                              ─────

┌──────────────────┐          ┌──────────────────┐
│                  │          │  COORDINATOR      │
│  890-1,328 lines │          │  ~80-120 lines    │
│  ONE agent sees  │          │  Routing only     │
│  EVERYTHING      │          └────────┬─────────┘
│                  │                   │
│  Critical checks │          ┌───────┼───────┐
│  buried in noise │          │       │       │
│                  │          ▼       ▼       ▼
│                  │       ┌─────┐┌─────┐┌─────┐
│                  │       │40-90││40-90││40-90│
│                  │       │lines││lines││lines│
│                  │       │     ││     ││     │
│                  │       │ONLY ││ONLY ││ONLY │
│                  │       │its  ││its  ││its  │
│                  │       │task ││task ││task │
│                  │       └─────┘└─────┘└─────┘
└──────────────────┘
                              Sub-agents see ONLY
                              their own instructions
```

**Max agent cognitive load: 1,328 lines → ~100 lines.**

---

## Slide 3: Planning — Before vs After

**Before:** One agent reads 890 lines and tries to do everything.

**After:** Coordinator spawns 12 focused sub-agents:

```
                        BEFORE          AFTER
Step                    Lines seen      Lines seen
─────────────────────   ──────────      ──────────
Scope check (GATE)      890             57
Derive folder           890             54
Knowledge query         890             75
Code review             890             81
Define files            890             53
Frozen criteria         890             61
Doc impact              890             85
Pre-existing issues     890             63
Validation script       890             81
Create plan             890             61
Design review           890             67
Finalize                890             83

Parallel groups:
  A: Knowledge + Code review run simultaneously
  B: Doc impact + Pre-existing + Validation run simultaneously
```

**Scope check is now a HARD GATE.** It's the only thing in the sub-agent's context. The agent literally cannot skip it because there's nothing else to do.

---

## Slide 4: Execution — Before vs After

**Before:** 1,205 lines — session recovery, branch check, context loading, work unit decomposition, agent selection, implementation, validation, adversarial review, documentation, and reporting all in one file.

**After:** Hybrid two-part system:

```
BEFORE: 1 file, 1,205 lines
┌──────────────────────────────────┐
│ Everything from BEADS init to    │
│ final report in one prompt       │
│ Agent decides what to prioritize │
└──────────────────────────────────┘

AFTER: 2 coordinators + 7 step files

Part 1: Preflight (sub-agents)     Part 2: Main (stays in session)
┌────────────────────────┐         ┌────────────────────────┐
│ 007a Branch (FIRST)    │  56 ln  │ Implement with         │
│ 007b Session recovery  │  49 ln  │ selected agent(s)      │
│ 007c Working tree      │  42 ln  │                        │
│ 007d Git context       │  45 ln  │ Validate (hook)        │
│ 01 Load context        │ 109 ln  │                        │
│ 0125 Decomposition     │  80 ln  │ Adversarial review     │
│ 015 Agent selection    │  65 ln  │ (fresh agent)          │
└────────────────────────┘         │                        │
  Preflight: 103 lines coord       │ Document + report      │
                                   └────────────────────────┘
                                     Main: 220 lines
```

**Why hybrid?** Implementation steps need the Agent/Task tool (only in main session). Preflight steps only need Read/Bash (safe for sub-agents).

---

## Slide 5: Review — Before vs After

**Before:** 1,328 lines. 5 verification gates run sequentially. Each gate reads the same 1,328 lines.

**After:** 5 gates run in parallel. Decision uses the best model.

```
BEFORE (sequential)                AFTER (5 parallel + synthesis)
────────────────────               ────────────────────────────

1. Eval criteria ─────┐           ┌─ Eval criteria ──────┐
                      │           │                       │
2. Code verify ───────┤           ├─ Code verify ─────────┤
                      │           │                       │
3. Doc verify ────────┤   ALL     ├─ Doc verify ──────────┤  ALL RUN
                      │   RUN     │                       │  AT ONCE
4. Integration ───────┤   ONE     ├─ Integration ─────────┤
                      │   BY      │                       │
5. Adversarial ───────┘   ONE     └─ Adversarial ─────────┘
         │                                    │
         ▼                                    ▼
   Decision (same               ┌─── AGGREGATION ───┐
   1,328-line                   │   cheap            │
   context)                     └────────┬───────────┘
                                         │
                                         ▼
                                ┌─── DECISION ───────┐
                                │   synthesis tier    │
                                │   BEST model        │
                                │   reads ALL evidence│
                                └────────────────────┘
```

**Wall-clock time:** 5 sequential gates → 5 parallel = ~5x faster review phase.

**Decision quality:** The old system made the decision with the same model that read 1,328 lines. Now the synthesis model reads only the aggregated gate results — clean, structured evidence.

---

## Slide 6: Release — Before vs After

**Before:** 1,189 lines of sequential steps.

**After:** Parallel context gathering, conditional steps.

```
BEFORE: Everything sequential, 1,189 lines

  Gather → Detect → Version → Classify → Changelog →
  Version files → Commit → Tag → Push → PR → Shepherd → Report


AFTER: Parallel start, conditional steps, 713 total lines

  ┌── PARALLEL ──┐
  │ Gather  │ 61 │
  │ Detect  │ 48 │
  └────┬────┘
       ▼
  Version    │ 53   (sequential)
  Classify   │ 51
  Changelog  │ 49
  Version*   │ 47   (* conditional: release mode only)
  Commit/Tag │ 90   (MUST be sequential — git ops)
  Shepherd*  │ 58   (* conditional: config/flag)
  Report     │ 44

  Coordinator: 116 lines
  Slash cmd:    96 lines (was 1,189)
```

---

## Slide 7: Brainstorm — Before vs After

**Before:** 352 lines. Already well-structured with 3 parallel agents, but embedded in the slash command.

**After:** Coordinator + 6 step files. Same pattern as the other workflows.

```
BEFORE: 352 lines in slash command

AFTER: 455 total lines (slightly larger due to step file overhead)
  Coordinator:      82 lines
  Config check:     30 lines
  Gather context:   47 lines
  3 agents:         46 lines (they spawn 3 sub-agents)
  Synthesize:       59 lines
  Design review:    47 lines (conditional)
  Transform+write:  92 lines
  Slash command:    52 lines

  Brainstorm was already the smallest and best-structured.
  Decomposition here is about consistency with the other 4 workflows.
```

---

## Slide 8: The Numbers

```
                    BEFORE          AFTER           REDUCTION
                    ──────          ─────           ─────────
Planning            890 lines       838 lines       -6%
Execution           1,205 lines     855 lines       -29%
Review              1,328 lines     838 lines       -37%
Release             1,189 lines     713 lines       -40%
Brainstorm          352 lines       455 lines       +29% *
                    ─────────       ─────────
TOTAL               4,964 lines     3,699 lines     -25%

Max lines any
agent sees:         1,328           ~100            -92%

* Brainstorm grew because step file overhead exceeds
  the 352-line original. The benefit is consistency
  and focused sub-agent context, not line reduction.
```

**The total line count isn't the point.** Some decomposed systems are larger because each step file needs its own header, inputs, outputs, and output format. The point is that **no single agent ever sees more than ~100 lines of instructions.**

---

## Slide 9: New Capabilities (didn't exist before)

| Capability | What it does |
|-----------|-------------|
| **Scope sizing gate** | Hard gate that blocks oversized scopes before planning starts |
| **Configurable thresholds** | `scope-sizing-rules.md` — adjust criteria count, file count, subsystem limits |
| **Scope override** | `scope_override: true` in requirement frontmatter bypasses Fail thresholds |
| **Phase-scoped .run/** | `planning/`, `execution/`, `review/`, `release/` prevent naming collisions |
| **Branch check runs first** | Prevents race condition with git context check |
| **Mandatory test-output.txt** | Even evidence-repair passes must produce validation artifacts |
| **Local env extensions** | Structured sections for polyrepo, validation, release customization |
| **Model tier abstraction** | cheap/capable/synthesis instead of hardcoded model IDs |
| **Native bd credentials** | Go code change — bd reads `~/.config/beads/credentials` without wrappers |

---

## Slide 10: File Organization — Before vs After

```
BEFORE                                  AFTER
──────                                  ─────
orchestration/                          orchestration/
  00_base_context.md                      plan-scope.md         (entry point)
  01_plan_scope_instructions.md  (890)    review-iteration.md   (entry point)
  01_plan_scope_prompt.md                 scope-sizing-rules.md (config)
  02_review_iteration_instr.md  (1328)    context/
  02_review_iteration_prompt.md             base-context.md
                                          coordinators/
claude/commands/                            plan-scope.md       (routing)
  ap_exec.md              (1205)            execute-preflight.md
  ap_release.md            (1189)            execute-main.md
  ap_brainstorm.md          (352)            review-iteration.md
                                             release.md
                                             brainstorm.md
                                          steps/
                                            planning/    (12 files)
                                            execution/   (7 files)
                                            review/      (9 files)
                                            release/     (9 files)
                                            brainstorm/  (6 files)

                                        claude/commands/
                                          ap_exec.md       (105)
                                          ap_release.md     (96)
                                          ap_brainstorm.md  (52)
```

Two clear entry points at the orchestration root. Everything else organized in subdirectories by function.
