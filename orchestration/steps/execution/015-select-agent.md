# Step 1.5: Select Specialized Agent

**Model tier:** cheap
**Tools needed:** Read
**Input:** scope, context output (`.run/execution/01-context.md`), decomposition output (`.run/execution/0125-decomposition.md`)
**Output:** `.run/execution/015-agent-selection.md`

---

## Your Task

Determine the appropriate agent(s) for this scope's implementation work.

## Selection Process

### 1. Check for Explicit Hint

Look in the iteration plan or requirements for `agent_hint: {agent_name}`. If present and valid, use it.

### 2. Auto-detect from File Patterns

Match files in scope against these patterns:

| Pattern | Agent |
|---------|-------|
| `.sql`, `migrations/`, schema | `dev-accelerator:backend-architect` |
| Backend API, FastAPI routes | `backend-security:backend-expert` |
| React components, `.tsx`/`.ts` | `frontend-excellence:react-specialist` |
| CSS, styling, design system | `frontend-excellence:css-expert` |
| State management, Redux | `frontend-excellence:state-manager` |
| Test files, Jest, Playwright | `dev-accelerator:test-automator` |
| Docker, CI/CD, deployment | `infra-pipeline:infra-architect` |
| GitHub Actions, pipelines | `infra-pipeline:cicd-engineer` |
| Auth, authorization | `backend-security:auth-specialist` |
| Security audits | `backend-security:security-guardian` |
| Refactoring, cleanup | `dev-accelerator:code-reviewer` |
| Bug fixes | `dev-accelerator:debugger` |

### 3. Multi-domain → Multiple Agents

If files span multiple domains and decomposition produced work units, assign one agent per work unit.

### 4. Fallback

No clear match → `general-purpose`

## Output Format

Write to `.run/execution/015-agent-selection.md`:

```markdown
# Agent Selection

**Mode:** single / multi-agent / work-unit-per-agent

## Selected Agent(s)
- {agent_type} — for {file pattern or domain}
- {agent_type_2} — for {file pattern or domain} (if multi-domain)

## Reasoning
{Brief explanation of why this/these agent(s) were chosen}

## Work Unit Mapping (if decomposed)
- WU-001 → {agent_type}
- WU-002 → {agent_type}
```
