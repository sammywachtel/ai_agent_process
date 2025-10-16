# Requirements: Lexical Stress Rendering Containment

**Date:** 2025-10-14
**Author:** Sam Wachtel
**Priority:** HIGH

---

## Objective

Remove the external stress overlay renderer and move all stress mark rendering into `StressedTextNode` to comply with Lexical.js containment best practices.

## Background

The current stress mark implementation violates Lexical.js containment rules by rendering stress marks in an external overlay container appended to the DOM outside the editor tree. This causes bugs including marks floating over toolbars, focus issues, memory leaks from global listeners, and state loss when users attempt to override stress patterns.

The Lexical best practices documentation (`docs/technology/lexical-best-practices.md:7-57`) explicitly forbids this pattern and identifies `StressMarkDecoratorPlugin` as a real-world failure case.

**Related documentation:**
- Product specifications: `docs/design/specifications.md:10-236`
- Lexical best practices: `docs/technology/lexical-best-practices.md:7-117`
- Technical audit: `.agent_process_legacy_2025-10-13/work/lexical_cleanup/lexical_code_review.md`

---

## Technical Requirements

1. **Remove external overlay renderer** from `StressMarkDecoratorPlugin`
   - Delete `.stress-overlay-container` DOM manipulation logic
   - Remove `document.querySelector` usage for external containers
   - Clean up global scroll/resize listeners
   - Delete `currentOverlayContainer` singleton

2. **Move stress mark rendering into StressedTextNode**
   - Implement stress mark rendering in `StressedTextNode.updateStressMarkupDOM`
   - Ensure marks stay within editor tree (no portal escapes)
   - Maintain visual appearance (underlines, primary/secondary styles)

3. **Wire Lexical commands for stress overrides**
   - Create command to update stress patterns: `UPDATE_STRESS_PATTERN_COMMAND`
   - Replace DOM-attribute mutations with node state updates
   - Ensure overrides persist through editor rerenders
   - Implement in `editor.update` blocks (not direct DOM manipulation)

4. **Fix stress override persistence**
   - Replace `updateStressPatternInNode` DOM mutations with command-based approach
   - Store stress pattern data in node state (not DOM attributes)
   - Ensure serialization includes stress overrides

5. **Prune legacy prosody CSS**
   - Remove overlay-specific styles (`.stress-overlay-container`, hover states)
   - Scope remaining prosody styles to `.rich-text-lyrics-editor`
   - Drop global selectors and unnecessary `!important` rules

---

## Success Criteria

**iteration_01 (iteration_01/01_a/01_b - COMPLETE):**
- [x] `StressMarkDecoratorPlugin` no longer creates external overlay containers
- [x] Stress marks render within `StressedTextNode` DOM elements (no portals)
- [x] Global listeners (scroll/resize) removed from plugin
- [x] User stress overrides persist through editor rerenders and history operations
- [x] Stress pattern data stored in node state, not DOM attributes
- [x] Commands introduced: `UPDATE_STRESS_PATTERN_COMMAND` system implemented
- [x] All stress command tests pass (31 tests)
- [x] No visual regression in stress mark appearance

**iteration_01_c (BLOCKED - Iteration budget exhausted):**
- [x] Context menu architecture migrated to portal containment pattern
- [x] All CSS scoped to `.rich-text-lyrics-editor` prefix
- [x] Menu state managed in `StressInteractionPlugin` (Lexical plugin lifecycle)
- [x] Documentation updated with floating menu pattern
- [ ] ❌ Context menu functionality preserved (3 integration bugs broke interactions)

**iteration_02 (PENDING - Bug fixes required):**
- [ ] Outside-click handler works (container class added)
- [ ] Menu commands execute (nodeKey prop passed)
- [ ] Boundary handling prevents overflow
- [ ] Full end-to-end workflow functional
- [ ] Manual QA confirms functionality restored

---

## Files Expected to Change

- `frontend/src/components/lexical/plugins/StressMarkDecoratorPlugin.tsx` (remove overlay renderer)
- `frontend/src/components/lexical/nodes/StressedTextNode.tsx` (add in-node rendering, command handlers)
- `frontend/src/styles/prosody.css` (remove overlay styles)
- `frontend/src/index.css` (scope global prosody rules)
- `frontend/tests/unit/components/lexical/StressedTextNode.test.tsx` (update tests for new rendering)
- `frontend/tests/unit/components/lexical/StressMarkDecoratorPlugin.test.tsx` (update tests for removed overlay)

**Estimated:** 6 files (within target range)

---

## Out of Scope

The following are explicitly NOT included in this scope and should be separate scopes:

- Async stress analysis coordinator (separate scope: extract network calls from nodes)
- AutoStressDetectionPlugin refactoring (separate scope: fix DOM listener leaks and async chains)
- StableTextToStressedPlugin cache cleanup (separate scope: fix permanent key caching)
- Portal-based decorator removal for other plugins (separate scope)
- Section detection plugin refactoring (separate scope)
- Syllable count decorator refactoring (separate scope)
- Value sync read/update separation (separate scope)

---

## Known Risks

**Risk 1: Complex interaction state**
- Stress marks currently support hover/click interactions via overlay
- **Mitigation:** If interactions are required, expose Lexical commands and let a dedicated UI component (inside editor tree) handle them. Document decision if interactions are temporarily removed.

**Risk 2: Visual regression**
- Users expect specific stress mark appearance
- **Mitigation:** Maintain current underline styles (primary/secondary) in node-rendered version. Test visual appearance manually before completion.

**Risk 3: Serialization compatibility**
- Existing songs have stress data serialized with current approach
- **Mitigation:** Verify that node state approach maintains serialization compatibility. Test loading existing songs with stress marks.

---

## References

- **Technical audit:** `.agent_process_legacy_2025-10-13/work/lexical_cleanup/lexical_code_review.md` (Critical Findings section)
- **Best practices:** `docs/technology/lexical-best-practices.md` (Containment rules, Command system patterns)
- **Product specs:** `docs/design/specifications.md` (Visual prosody expectations)
- **Previous iteration attempts:** `.agent_process_legacy_2025-10-13/work/lexical_cleanup/iteration_01/` (lessons learned)

---

## Estimated Size

- **Duration:** 1-2 weeks
- **Iterations:** 2-3 estimated (first attempt + likely 1-2 refinements)
- **Complexity:** MEDIUM-HIGH
  - Complexity factors: Lexical.js node lifecycle, command system integration, CSS refactoring, serialization compatibility
  - Simplifying factors: Clear technical direction, well-documented anti-patterns, existing test coverage

---

## Notes

This is the first scope in a larger effort to align the Lexical editor with documented best practices. The technical audit identified 5 major remediation areas; this scope addresses the most critical issue (external overlay rendering) that directly violates Lexical containment rules.

**Orchestrator guidance:**
- Review files listed in "Files Expected to Change" for current implementation patterns
- Assess whether 6 files is realistic or if hidden dependencies expand scope
- Check test coverage to determine if success criteria are testable
- Consider whether stress override interactions add complexity requiring scope split
