# Documentation Checklist

Per CLAUDE.md "Zero Documentation Drift" rule: **Update documentation in the same commit as code changes.**

## Understanding Your Audience

Documentation serves two distinct user types, and both matter equally:

### End Users (Application Users)
- People using your application/product
- Need to understand **how to accomplish tasks**
- Documentation types: User guides, tutorials, feature docs, UI workflows
- Question they ask: *"How do I do X with this application?"*

### Developer Users (Technical Users)
- People using your code, API, or contributing to the project
- Need to understand **how to integrate, extend, or maintain**
- Documentation types: API reference, architecture docs, integration guides, contribution guidelines
- Question they ask: *"How do I integrate with/extend/modify this system?"*

**Critical for open source projects**: Your primary users might be developers integrating your library, not end users of an application. API documentation and architectural explanations are user-facing documentation for this audience.

---

## Fast-Track Assessment (< 30 seconds)

Answer these questions to determine if documentation updates are needed:

### For End Users
1. Does this change affect **visible behavior** (UI, features, workflows)? → User docs likely needed
2. Does this change affect **how users accomplish tasks**? → User docs likely needed

### For Developer Users
1. Does this change affect **public API** (endpoints, functions, interfaces)? → API docs required
2. Does this change affect **integration points** (config, environment, dependencies)? → Integration docs required
3. Does this change introduce **architectural decisions** or patterns? → Explanation docs required

**All "no"?** → Add note to results.md: *"Internal implementation change, no external impact for end users or developers"*

**Any "yes"?** → Proceed to full documentation impact analysis below.

---

## Quick Check: Does This Iteration Require Doc Updates?

| Change Type | End User Docs | Developer Docs | Documentation Location |
|-------------|---------------|----------------|------------------------|
| New UI feature | ✅ Yes | ⚠️ Maybe | `docs/how-to/`, `docs/tutorials/` |
| Modified UI workflow | ✅ Yes | ❌ No | `docs/how-to/` |
| New API endpoint | ❌ No* | ✅ Yes | `docs/reference/api/` |
| Modified API | ❌ No* | ✅ Yes | `docs/reference/api/` |
| New public function/class | ❌ No* | ✅ Yes | `docs/reference/`, inline docs |
| Architecture decision | ❌ No | ✅ Yes | `docs/explanation/architecture/` |
| System replacement | ⚠️ Maybe | ✅ Yes | Migration guide in `docs/how-to/` |
| Config option change | ⚠️ Maybe | ✅ Yes | `docs/reference/configuration.md` |
| Deployment change | ❌ No | ✅ Yes | `docs/how-to/deployment.md` |
| Bug fix (no behavior change) | ❌ No | ❌ No | Changelog only |
| Internal refactor | ❌ No | ❌ No | None (unless affects contributors) |
| New dependency | ❌ No | ✅ Yes | `docs/reference/dependencies.md`, `README.md` |
| Breaking change | ⚠️ Maybe | ✅ Yes | Migration guide + CHANGELOG |
| Performance optimization | ❌ No | ⚠️ Maybe** | `docs/explanation/` if architectural |

*Unless the API/function is directly exposed to end users (e.g., embedded SDK, user-facing scripting)
**Document if the optimization changes recommended usage patterns or has configuration implications

---

## Diátaxis Framework for Both Audiences

Organize documentation updates by type and audience:

### 📚 Tutorials (Learning-oriented)
- **End Users**: "Getting Started with [Feature]", "Your First [Workflow]"
- **Developers**: "Building Your First Plugin", "Quick Start: Integrating the API"
- **Location**: `docs/tutorials/`
- **Update when**: Adding major new features or capabilities

### 🛠️ How-To Guides (Task-oriented)
- **End Users**: "How to Export Data", "How to Customize Settings"
- **Developers**: "How to Add a New Endpoint", "How to Write a Custom Validator"
- **Location**: `docs/how-to/`
- **Update when**: Workflows, procedures, or integration steps change

### 📖 Reference (Information-oriented)
- **End Users**: Feature lists, keyboard shortcuts, supported formats
- **Developers**: API docs, configuration options, function signatures, type definitions
- **Location**: `docs/reference/`
- **Update when**: APIs, configs, or technical specifications change

### 💡 Explanation (Understanding-oriented)
- **End Users**: "Why We Designed [Feature] This Way" (rare, usually for power users)
- **Developers**: Architecture decisions, design patterns, "Why We Use [Pattern]"
- **Location**: `docs/explanation/`
- **Update when**: Making architectural decisions or introducing new patterns

---

## Search Commands for Impact Analysis

Find documentation that might need updating:

```bash
# Search for references to changed component (both user and dev docs)
grep -r "ComponentName" docs/
grep -r "FunctionName" docs/

# Search for API endpoint references (developer docs)
grep -r "/api/endpoint" docs/
grep -r "api.methodName" docs/

# Search for feature mentions (user docs)
grep -r "Feature Name" docs/tutorials/ docs/how-to/

# Search README files (critical for developers)
grep -r "featureName" */README.md
grep -r "import.*ModuleName" docs/

# Search for configuration references (both audiences)
grep -r "config.optionName" docs/
grep -r "ENVIRONMENT_VAR" docs/

# Search for architecture/pattern mentions (developer docs)
grep -r "design pattern" docs/explanation/
grep -r "architecture decision" docs/explanation/
```

---

## In Iteration Plan

Add to **"Files in Scope"** section:

```markdown
## Documentation in Scope

### End User Documentation
- `docs/how-to/using-feature-x.md` (workflow changes)
- `docs/tutorials/getting-started.md` (if affects onboarding)

### Developer Documentation
- `docs/reference/api/endpoints.md` (API changes)
- `docs/explanation/architecture/data-flow.md` (architectural decision)
- `README.md` (if affects installation/setup)
```

Add to **"Acceptance Criteria"**:

```markdown
- [ ] End user documentation updated (or N/A - explain why)
- [ ] Developer documentation updated (or N/A - explain why)
- [ ] Documentation follows Diátaxis framework organization
```

---

## How to Know Documentation is Good Enough

### For End Users
- [ ] A new user could accomplish the task from docs alone
- [ ] Screenshots/examples show the actual current UI (if applicable)
- [ ] The "why" is explained, not just the "what" (when helpful)
- [ ] Common pitfalls or gotchas are called out
- [ ] Related features are cross-referenced

### For Developer Users
- [ ] A new contributor/integrator could use the API from docs alone
- [ ] Code examples compile/run with current version
- [ ] The "why" behind architectural decisions is documented
- [ ] Breaking changes clearly marked with migration path
- [ ] Type signatures/contracts are accurate
- [ ] Integration requirements (dependencies, config) are explicit

### For Both Audiences
- [ ] Cross-references to related docs are updated/added
- [ ] Deprecated features marked with migration guidance
- [ ] Version/date information included for "added in" or "changed in"
- [ ] Examples reflect actual current behavior, not old versions

---

## Common Documentation Gaps (Watch For These!)

### End User Documentation Gaps
- Added UI feature but no user guide for how to use it
- Changed workflow but tutorial still shows old steps
- Added configuration option but no user-facing explanation of what it does

### Developer Documentation Gaps
- Added API endpoint but no reference documentation
- Made architecture decision but no explanation of trade-offs
- Changed config schema but no migration guide for existing configs
- Added dependency but didn't update installation docs
- Refactored internal API that contributors use but didn't update contribution guide

### Cross-Audience Gaps
- Created migration guide for developers but didn't warn end users about breaking changes
- Updated API docs but didn't update integration tutorial
- Changed behavior that affects both UI and API but only updated one set of docs

---

## Special Cases

### Open Source Projects
Developer documentation IS user-facing documentation. Prioritize:
- **README.md**: Installation, quick start, basic usage
- **CONTRIBUTING.md**: How to contribute, build instructions, code standards
- **API Reference**: Public interfaces, functions, classes
- **Architecture Docs**: Design decisions, patterns, system overview
- **Examples**: Working code samples for common use cases

### Internal Tools
End users might be fellow engineers:
- Document **why** decisions were made (future team will thank you)
- Include runbooks and operational guides
- Document non-obvious gotchas and edge cases
- Link to related systems and dependencies

### Libraries/SDKs
Your "users" are developers writing code against your library:
- Comprehensive API reference is mandatory
- Migration guides for breaking changes
- Integration examples for common frameworks
- Architecture explanations for extension points

---

## Documentation Debt

Sometimes documentation updates are blocked or too large for current iteration. Handle this explicitly:

```markdown
## Documentation Debt (in results.md)

**What needs documenting**:
- Architecture explanation for new caching layer (complex, needs diagrams)

**Why not in this iteration**:
- Requires architectural diagram creation (1-2 hours)
- Core functionality works, can document in follow-up

**Tracking**:
- [ ] Created issue #123: "Document caching architecture"
```

**Important**: Documentation debt is still debt. Track it, prioritize it, pay it down. Don't let it accumulate.

---

## Quick Reference: When in Doubt

**Ask yourself**:
1. If I left the company tomorrow, could someone understand this change from the docs?
2. If this were open source, would contributors know how to work with this?
3. If this broke, would the on-call engineer know why it was built this way?

If any answer is "no" → **documentation is needed**.

**Remember**: Documentation that diverges from reality is worse than no documentation. Update it now, in the same commit. Future you will be grateful.
