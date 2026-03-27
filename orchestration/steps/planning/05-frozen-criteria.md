# Step 05: Create Frozen Acceptance Criteria

**Model tier:** capable
**Tools needed:** Read
**Input:** Requirement file, code review output (`.run/planning/03-code-review.md`)
**Output:** `.run/planning/05-frozen-criteria.md`

---

## Your Task

Transform the requirement's success criteria into specific, testable, frozen acceptance criteria. These criteria are LOCKED for the duration of the iteration — no mid-iteration scope creep.

## Criteria Quality Rules

**Good criteria (specific, testable):**
- `StressedTextNode.autoDetectStress method removed`
- `12/12 unit tests pass`
- `API returns 200 with valid payload`
- `CHANGELOG.md updated under [Unreleased]`

**Bad criteria (vague, subjective):**
- ~~Code quality improved~~ (how measured?)
- ~~Editor works better~~ (what does "better" mean?)
- ~~All bugs fixed~~ (which bugs?)
- ~~Refactoring complete~~ (when is refactoring "complete"?)

## Count Target

Aim for **3-7 criteria**. If >10, the scope is likely too large — flag this in the output.

## Documentation Criteria

If the code review identified documentation impact, include doc criteria:
```markdown
- [ ] Developer documentation updated (or N/A — internal change only)
- [ ] End user documentation updated (or N/A — no user-facing changes)
```

## Output Format

Write to `.run/planning/05-frozen-criteria.md`:

```markdown
# Frozen Acceptance Criteria

**Scope:** {scope_name}
**Criteria count:** {N}
**LOCKED — DO NOT MODIFY during iteration**

## Acceptance Criteria

- [ ] {Specific, testable criterion 1}
- [ ] {Specific, testable criterion 2}
- [ ] {Specific, testable criterion 3}
...

## Criteria Notes
{Any context on how criteria were derived from the requirement.
Flag if count exceeds target range.}
```
