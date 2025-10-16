# AI Agent Process Template

A structured workflow template for AI-powered development with Claude Code, featuring iteration budgets, frozen criteria, and scoped validation.

**Philosophy:** Ship pragmatically, iterate deliberately, converge forcefully.

---

## Quick Links

- **Full Documentation:** See the main [README](README.md) file in the project root (this file)
- **Orchestration Guide:** `orchestration/00_base_context.md` for quick onboarding
- **Validation Playbook:** `process/validation-playbook.md` for testing patterns
- **Slash Commands:** `/ap_exec <scope> <iteration>` to execute iterations

---

## What This Template Provides

### Core Workflow
- **Iteration Budgets:** Max 3 sub-iterations before human escalation
- **Frozen Criteria:** Acceptance criteria locked at iteration start
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
- Review against original criteria
- Make APPROVE/ITERATE/BLOCK/PIVOT decision
- Enforce iteration budget (max 3 sub-iterations)

---

## Core Principles

### Iteration Budget Enforcement
```
iteration_01    → First attempt
iteration_01_a  → First revision
iteration_01_b  → Second revision
iteration_01_c  → Final attempt
                → MUST escalate to human after this
```

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

### Frozen Criteria
- Acceptance criteria locked at iteration start
- No new requirements during execution
- Document pre-existing issues once in iteration plan
- Focus on objectives, not perfection

---

## Success Metrics

**Healthy Process:**
- Average 1-3 iterations per scope
- 0-2 sub-iterations per iteration
- >80% scope completion rate
- 1-2 week completion time

**Broken Process:**
- Infinite sub-iterations (iteration_01_a → iteration_01_z)
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

**Philosophy:** Ship pragmatically, iterate deliberately, converge forcefully.
