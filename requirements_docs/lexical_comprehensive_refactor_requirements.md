# Requirements: Lexical Comprehensive Refactor

**Date:** 2025-10-14
**Author:** Sam Wachtel
**Priority:** HIGH

---

## Objective

Comprehensively refactor the Lexical editor implementation to eliminate all documented anti-patterns, move all prosody rendering into the editor tree, externalize async operations into a coordinator service, clean up plugin lifecycle issues, and align all styling with best practices.

## Background

The current Lexical editor implementation has accumulated multiple architectural issues that violate Lexical.js best practices. These include external overlay rendering, async mutations from node lifecycle hooks, portal-based decorators, DOM listener leaks, and global CSS pollution. A comprehensive technical audit has identified critical violations across stress rendering, plugin lifecycle management, async coordination, and styling.

**Related documentation:**
- Complete audit: `.agent_process_legacy_2025-10-13/work/lexical_cleanup/lexical_code_review.md`
- Lexical best practices: `docs/technology/lexical-best-practices.md`
- Product specifications: `docs/design/specifications.md:10-236`

---

## Technical Requirements

### Phase 1: Stress Rendering Containment
1. Remove external stress overlay renderer from `StressMarkDecoratorPlugin`
2. Move stress mark rendering into `StressedTextNode.updateStressMarkupDOM`
3. Wire Lexical commands for stress pattern overrides
4. Fix stress override persistence (node state, not DOM attributes)
5. Delete overlay-specific CSS classes

### Phase 2: Async Stress Analysis Coordinator
6. Extract network calls from `StressedTextNode` (remove `fetch` to `http://localhost:8001`)
7. Create `StressCoordinatorService` to handle stress analysis requests
8. Implement `APPLY_STRESS_PATTERN_COMMAND` for synchronous node updates
9. Add retry/backoff handling for network requests
10. Remove `setTimeout` callbacks from node lifecycle hooks
11. Mock coordinator for testing environments

### Phase 3: Plugin Lifecycle Cleanup
12. Refactor `AutoStressDetectionPlugin` to use `editor.registerCommand` instead of manual `keydown` listeners
13. Replace `setTimeout` recursion with debounced command handlers
14. Fix async update chains in auto-detection plugin
15. Clean up `StableTextToStressedPlugin` permanent cache (fix `convertedNodeKeys` leak)
16. Replace timer-based scheduling with `editor.registerUpdateListener` and `requestAnimationFrame`
17. Gate debug logging behind feature flag or remove entirely
18. Add unit tests for plugin lifecycle

### Phase 4: Portal and Decorator Removal
19. Remove `createPortal` usage from `ComprehensiveStressPlugin`
20. Remove `createPortal` usage from `SyllableCountDecoratorPlugin`
21. Convert decorator logic to Lexical decorator nodes or inline elements
22. Move syllable count UI to side panel (eliminate DOM portal to `document.body`)
23. Eliminate layout thrash from repeated DOM measurements

### Phase 5: Section Detection and Value Sync
24. Refactor `SectionDetectionPlugin` to collect matches in read phase, mutate in single `editor.update`
25. Fix `LexicalLyricsEditor` value sync to use `editor.getEditorState().read` for reads
26. Eliminate unnecessary history entries from read-only updates

### Phase 6: CSS Cleanup and Scoping
27. Scope all prosody styling to `.rich-text-lyrics-editor` wrapper class
28. Remove global `body > *` selectors from prosody.css
29. Replace `:has`-based grouping with data attributes (Firefox compatibility)
30. Remove unnecessary `!important` rules
31. Delete overlay-specific CSS (`.stress-overlay-container`, hover states)
32. Consolidate syllable styling rules

### Phase 7: Shared Utilities and Consolidation
33. Extract `isWordStressed` heuristic into shared `frontend/src/components/lexical/utils/prosodyHelpers.ts`
34. Consolidate duplicated stress analysis logic
35. Create shared syllable detection utilities
36. Add JSDoc documentation for all shared helpers

### Phase 8: Testing and Verification
37. Add unit tests for `StressedTextNode` in-node rendering
38. Add unit tests for stress coordinator service
39. Add integration tests for stress override persistence
40. Verify serialization compatibility with existing songs
41. Add visual regression tests for stress mark appearance
42. Run full Playwright prosody test suite
43. Document any breaking changes or migration notes

---

## Success Criteria

- [ ] All overlay renderers removed (no `document.querySelector`, no external containers)
- [ ] All stress marks render within editor tree (no portals)
- [ ] Global listeners removed from all plugins
- [ ] Network calls externalized to coordinator service
- [ ] Async mutations eliminated from node lifecycle hooks
- [ ] All plugins use command-based patterns (no manual DOM listeners)
- [ ] Permanent caches cleaned up (no memory leaks)
- [ ] Portal-based decorators converted to in-tree rendering
- [ ] Section detection uses proper read/update separation
- [ ] Value sync uses `read` for reads, `update` for mutations
- [ ] CSS scoped to editor wrapper (no global pollution)
- [ ] Firefox-compatible styling (no `:has` dependency)
- [ ] Shared prosody utilities consolidated
- [ ] All unit tests pass (271 existing + new tests)
- [ ] All Playwright tests pass
- [ ] Zero TypeScript errors in modified files
- [ ] Zero ESLint errors in modified files
- [ ] Serialization backward compatible
- [ ] No visual regressions

---

## Files Expected to Change

**Nodes:**
- `frontend/src/components/lexical/nodes/StressedTextNode.tsx`

**Plugins:**
- `frontend/src/components/lexical/plugins/StressMarkDecoratorPlugin.tsx`
- `frontend/src/components/lexical/plugins/AutoStressDetectionPlugin.tsx`
- `frontend/src/components/lexical/plugins/StableTextToStressedPlugin.tsx`
- `frontend/src/components/lexical/plugins/ComprehensiveStressPlugin.tsx`
- `frontend/src/components/lexical/plugins/SyllableCountDecoratorPlugin.tsx`
- `frontend/src/components/lexical/plugins/SectionDetectionPlugin.tsx`

**Components:**
- `frontend/src/components/LexicalLyricsEditor.tsx`
- `frontend/src/components/CleanSongEditor.tsx` (may need coordinator wiring)

**Services (new):**
- `frontend/src/services/stressCoordinatorService.ts`

**Utils (new):**
- `frontend/src/components/lexical/utils/prosodyHelpers.ts`

**Commands (new):**
- `frontend/src/components/lexical/commands/StressCommands.ts`

**Styling:**
- `frontend/src/styles/prosody.css`
- `frontend/src/index.css`

**Tests (new and modified):**
- `frontend/tests/unit/components/lexical/StressedTextNode.test.tsx`
- `frontend/tests/unit/components/lexical/StressMarkDecoratorPlugin.test.tsx`
- `frontend/tests/unit/components/lexical/AutoStressDetectionPlugin.test.tsx`
- `frontend/tests/unit/components/lexical/StableTextToStressedPlugin.test.tsx`
- `frontend/tests/unit/services/stressCoordinatorService.test.tsx`
- `frontend/tests/integration/lexical/StressOverridePersistence.test.tsx`
- `tests/e2e/features/prosody-visual-regression.spec.ts`

**Estimated:** 25+ files (EXCEEDS recommended maximum of 10)

---

## Out of Scope

- Performance optimization beyond removing known bottlenecks
- New prosody features (rhyme detection, meter analysis)
- Backend stress analysis API changes
- UI/UX redesign for prosody controls

---

## Known Risks

**Risk 1: Scope too large**
- 8 phases with 43 technical requirements across 25+ files
- **Mitigation:** Should be split into 5-8 smaller scopes, each completable in 1-2 weeks

**Risk 2: Breaking changes**
- Major architectural changes may break existing functionality
- **Mitigation:** Comprehensive testing and backward compatibility verification required

**Risk 3: Dependency conflicts**
- Changes across plugins may have hidden dependencies
- **Mitigation:** Careful sequencing and integration testing between phases

**Risk 4: Timeline unrealistic**
- Estimated 2-3 months of work bundled into single scope
- **Mitigation:** MUST split into smaller, independently shippable scopes

---

## References

- **Complete audit:** `.agent_process_legacy_2025-10-13/work/lexical_cleanup/lexical_code_review.md`
- **Best practices:** `docs/technology/lexical-best-practices.md`
- **Product specs:** `docs/design/specifications.md`

---

## Estimated Size

- **Duration:** 2-3 months (EXCEEDS 1-2 week target)
- **Iterations:** 15-20 estimated (EXCEEDS max 5 per scope)
- **Complexity:** VERY HIGH
  - Too many interconnected changes
  - Multiple architectural shifts
  - High risk of scope creep

---

## Notes

⚠️ **WARNING: This scope is intentionally oversized for testing purposes.**

This requirements document bundles what should be 5-8 separate scopes into a single mega-scope. It is designed to test whether Codex correctly identifies scope sizing issues and recommends splitting.

**Expected Codex response:**
- Identify this scope as too large
- Suggest splitting into individual scopes:
  1. Stress rendering containment
  2. Async stress coordinator
  3. Plugin lifecycle cleanup
  4. Portal/decorator removal
  5. Section detection refactoring
  6. CSS cleanup
  7. Shared utilities consolidation
  8. Testing and verification
- Provide guidance on which scope to tackle first
- Request clarification before creating any work structure
