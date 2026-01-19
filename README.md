# AI Agent Process Template

A structured workflow template for AI-powered development with Claude Code, featuring two-level iteration model, frozen-within-iteration criteria, and scoped validation.

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.

---

## Quick Links

- **Full Documentation:** See the main [README](README.md) file in the project root (this file)
- **Orchestration Guide:** `orchestration/00_base_context.md` for quick onboarding
- **Validation Playbook:** `process/validation-playbook.md` for testing patterns
- **Slash Commands:** `/ap_exec <scope> <iteration>` to execute iterations

---

## What This Template Provides

### Core Workflow
- **Two-Level Iterations:** Major iterations (01, 02, 03) for criteria changes; sub-iterations (_a, _b, _c) for fixes
- **Frozen-Within-Iteration Criteria:** Criteria locked during iteration, changeable between iterations via PIVOT
- **Scoped Validation:** Only test files in scope, not entire codebase
- **4-Choice Framework:** APPROVE/ITERATE/BLOCK/PIVOT decisions

### Directory Structure
```
├── claude/           # Slash commands for Claude Code
├── orchestration/    # Planning and review prompts
├── process/          # Validation and testing patterns
├── templates/        # Iteration plan templates
├── scripts/          # Validation scripts
├── requirements_docs/ # Project requirements
└── work/             # Active iteration work
```

### Key Components
- **Planning Tools:** Orchestration prompts for scope definition
- **Execution Tools:** Slash commands for implementation
- **Review Tools:** Iteration feedback templates
- **Validation Tools:** Scoped testing scripts

---

## Getting Started

### 1. Define Requirements
Create a requirements document in `requirements_docs/<scope>_requirements.md` with:
- Clear objectives
- Acceptance criteria
- Files expected to change
- Success metrics

### 2. Plan Iteration
Use `orchestration/01_plan_scope_prompt.md` to:
- Create iteration plan with frozen criteria
- Set up scoped validation scripts
- Define iteration budget

### 3. Execute Work
Run `/ap_exec <scope> <iteration>` to:
- Implement against frozen criteria
- Validate only in-scope files
- Generate results artifacts

### 4. Review Results
Use `orchestration/02_review_iteration_prompt.md` to:
- Review against current criteria version
- Make APPROVE/ITERATE/BLOCK/PIVOT decision
- PIVOT when criteria need changing (creates iteration_02, etc.)

---

## Core Principles

### Two-Level Iteration Model
```
Major iterations (criteria changes via PIVOT):
  iteration_01  → Initial criteria (v1)
  iteration_02  → Revised criteria (v2) after PIVOT
  iteration_03  → Further revision (v3) if needed

Sub-iterations (fixes within same criteria via ITERATE):
  iteration_01_a/b/c  → Fix attempts for v1 criteria
  iteration_02_a/b/c  → Fix attempts for v2 criteria

Example progression:
  01 → 01_a → 01_b → PIVOT → 02 → 02_a → APPROVE
```

**PIVOT** creates new major iteration (learning-driven, not failure-driven)
**ITERATE** creates sub-iteration (same criteria, specific fixes)
**Max 3 sub-iterations** per major iteration before PIVOT or BLOCK

### Scoped Validation
Only validate files you changed, not the entire codebase:
```bash
# Good: Scoped validation
npx eslint "path/to/changed-file.tsx"
npm test -- --testPathPattern="TestsForScope"

# Bad: Full codebase validation
npm run typecheck  # Fails on 89 unrelated errors
npm test           # Fails on 10 unrelated tests
```

### Frozen-Within-Iteration Criteria
- Acceptance criteria locked within each major iteration
- No new requirements during execution (use backlog)
- PIVOT allows criteria revision between major iterations
- Document pre-existing issues once in iteration plan
- Focus on objectives, not perfection

---

## Success Metrics

**Healthy Process:**
- 1-3 major iterations per scope (PIVOTs indicate learning, not failure)
- 0-2 sub-iterations per major iteration
- >80% scope completion rate
- 1-3 week completion time

**Warning Signs:**
- >3 sub-iterations on same criteria (should PIVOT or BLOCK)
- PIVOTs without clear criteria changes (misusing the mechanism)
- <20% scope completion rate
- Indefinite completion time

---

## Documentation

- **Process Evaluation:** `.local_docs/process/agent-process-evaluation.md`
- **Scope Sizing Guide:** `.local_docs/process/scope-sizing-quick-reference.md`
- **Orchestration Instructions:** `orchestration/01_plan_scope_instructions.md`, `orchestration/02_review_iteration_instructions.md`
- **Validation Patterns:** `process/validation-playbook.md`

---

## Installation

This template is designed to be copied into your project:

1. Copy this directory structure to your project
2. Customize `requirements_docs/` for your project
3. Update `scripts/after_edit/` with your validation scripts
4. Start planning your first scope!

---

## Contributing

This is a personal template. Feel free to fork and customize for your needs!

---

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.
