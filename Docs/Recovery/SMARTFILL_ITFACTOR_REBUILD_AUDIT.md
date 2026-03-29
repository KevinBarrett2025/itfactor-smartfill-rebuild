# SmartFill itFactor Rebuild Audit

Date: 2026-03-29
Repo: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only)

## Purpose
This audit defines which SmartFill seams in `itFactor_1.23.26_git` remain authoritative, which are legacy surfaces to replace, and which are only useful as archaeology while the flagship SmartFill rebuild moves into the project/session/review shell used by the shipped app.

The flagship intent is:
- keep project/session/take ownership in the itFactor shell
- launch SmartFill from take review or player context
- preserve SmartFill lineage and repository truth
- replace overlapping or duplicate SmartFill UI surfaces with one bounded workspace

## Classification Matrix
| Area | Path | Classification | Reason | Next Action |
| --- | --- | --- | --- | --- |
| SmartFill processing core | `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/*` | `KEEP` | The rebuild workspace now depends on the real SmartFill preview/render/export engine, including `SmartFillPreviewPlayer`, `SmartFillPreviewView`, deterministic frame-step timing in `SmartFillManager`, and preview-at-rest poster-frame rendering in the rebuild workspace, so these seams are active shared engine truth even though they do not define product shell structure. | Keep and evolve only as shared SmartFill engine seams; do not treat them as standalone product-shell authority. |
| Legacy SmartFill controller | `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift` | `DELETE_AFTER_CUTOVER` | Review/player and editor-origin SmartFill entry now route through the rebuild workspace and repository adoption bridge instead of this controller-owned launch path. | Deleted in the Phase 5 GM slice; keep absent unless shipped archaeology proves a missing dependency. |
| Legacy SmartFill settings modal | `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift` | `DELETE_AFTER_CUTOVER` | Old modal-level UI no longer matches the bounded rebuild workspace target and both live launch surfaces now bypass it. | Deleted in the Phase 5 GM slice; rebuild workspace is now the only live editor-entry surface. |
| Legacy real preview handoff | `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift` | `DELETE_AFTER_CUTOVER` | Preview orchestration was tied only to the removed modal-level editor path. | Deleted in the Phase 5 GM slice; later preview work should stay inside the rebuild workspace only. |
| Legacy still preview view model | `STSiPhone/STSiPhone/Features/Editing/SmartFillStillPreviewViewModel.swift` | `REFERENCE_ONLY` | Useful to understand earlier preview state handling, but not a durable flagship seam. | Read for behavior notes only. |
| Legacy global SmartFill settings screen | `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift` | `DELETE_AFTER_CUTOVER` | The live app no longer had a reachable trigger for this screen, and its remaining reusable advanced-settings sheet now lives under the rebuild workspace instead of a duplicate settings shell. | Deleted in the Phase 6 GM slice; reintroduce global defaults only through an intentional flagship settings design later if needed. |
| Legacy migration dashboard | `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift` | `DELETE_AFTER_CUTOVER` | Migration and dashboard status UI competed with the rebuild workspace and only wrapped the deleted settings screen. | Deleted in the Phase 6 GM slice; future data recovery should be redesigned intentionally, not preserved as dormant dashboard UI. |
| Batch processing view | `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift` | `DELETE_AFTER_CUTOVER` | The batch/recovery surface had no live callers, opened the deleted settings screen, and its recovery actions were already unsupported for the current SQLite repository. | Deleted in the Phase 6 GM slice; recover or redesign bulk SmartFill processing later only if product scope requires it. |
| Repository SmartFill upsert helper | `STSiPhone/STSiPhone/Shared/Repositories/SmartFillRepository+Upsert.swift` | `KEEP` | This is a useful repository seam for preserving SmartFill take lineage and standalone SmartFill take creation. | Keep and adapt to new result bridge. |
| Path migrator | `STSiPhone/STSiPhone/Shared/Services/SmartFillPathMigrator.swift` | `KEEP` | Protects shipped data/path continuity. | Keep until all existing SmartFill paths are migrated and verified. |
| Take-level SmartFill persistence | `STSiPhone/STSiPhone/Shared/Models/ProjectModels.swift` | `KEEP` | Carries shipped lineage fields: `overrideSmartFill`, `smartFilledFilePath`, `smartFillSettings`, orientation, and SmartFill variant helpers. | Preserve and extend through bridge/result mapping only. |
| Unified take mirror fields | `STSiPhone/STSiPhone/Shared/Models/UnifiedModels.swift` | `KEEP` | Mirrors take-level SmartFill state into unified review/editor surfaces. | Preserve until unified model parity is explicitly retired. |
| Repository contract | `STSiPhone/STSiPhone/Shared/Repositories/ProjectsRepository.swift` | `KEEP` | Owns SmartFill persistence/update semantics in the flagship shell. | Keep as the persistence authority for result adoption. |
| SQLite repository implementation | `STSiPhone/STSiPhone/Shared/Repositories/SQLite/SQLiteProjectsRepository.swift` | `KEEP` | Implements SmartFill status, variant take creation, path normalization, and clear/reset behavior for persisted data. | Keep and route new result bridge through it. |

## Authoritative Seams To Preserve
These seams are the correct architectural anchors for the rebuild:

- `STSiPhone/STSiPhone/Shared/Repositories/ProjectsRepository.swift`
- `STSiPhone/STSiPhone/Shared/Repositories/SQLite/SQLiteProjectsRepository.swift`
- `STSiPhone/STSiPhone/Shared/Models/ProjectModels.swift`
- `STSiPhone/STSiPhone/Shared/Models/UnifiedModels.swift`
- `STSiPhone/STSiPhone/Features/Projects/Views/ProjectDetailView.swift`
- `STSiPhone/STSiPhone/Features/Projects/Views/SwipeableVideoPlayerView.swift`
- `STSiPhone/STSiPhone/Shared/Flow/FlowHostView.swift`
- `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillPreviewPlayer.swift`
- `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillPreviewView.swift`
- `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillProcessingManager.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillSessionContext.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillTakeBridge.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillResultBridge.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceCoordinator.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceView.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceFollowUpRoute.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillReopenDestinationContext.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePresentation` (declared in `SmartFillWorkspaceView.swift`)
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceBackgroundDetail` / inline background, subject, and output expander state (declared in `SmartFillWorkspaceView.swift`)
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/compactMenuPicker` / explicit inline `Background` and `Foreground` picker ownership (declared in `SmartFillWorkspaceView.swift`)
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePreviewCompareGroupState` / inline pinned-preview compare state (declared in `SmartFillWorkspaceView.swift`)
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePreviewPlaybackState.syncingObservedTime(...)` / shared preview-state sync seam that preserves parent play intent while child preview wrappers publish observed current time (declared in `SmartFillWorkspaceView.swift`)
- `STSiPhone/STSiPhone/Features/Editing/LightweightEditorViewController+ModularWiring.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillDefaultsView.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillAdvancedSettingsView.swift`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePreviewPosterPolicy` / `SmartFillWorkspacePreviewPosterRenderer` (declared in `SmartFillWorkspaceView.swift`)

## Retired Legacy UI Seams
- `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
- `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift`
- `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift`
- `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift`
- `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
- `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift`

The editor-only seams were deleted in the Phase 5 GM slice after review/player and editor-origin entry both moved onto the rebuild workspace. The dead settings-side wrapper screens were deleted in the Phase 6 GM slice after the reusable advanced-settings component moved under `Features/SmartFill/Rebuild`.

## Duplicate Or Obsolete UI Surfaces Still Pending Removal
None for `SF-REBUILD-006`. The remaining SmartFill work should focus on intentional flagship workspace evolution, including explicit look/framing/output/save controls inside the rebuild workspace, defaults/workspace refinement, or later standalone derivation, not dormant duplicate screens.

## Persistence Seams That Must Survive
These fields and APIs carry shipped SmartFill truth and must not be deleted during cleanup:

- `ProjectTake.capturedOrientation`
- `ProjectTake.overrideSmartFill`
- `ProjectTake.smartFilledFilePath`
- `ProjectTake.smartFillSettings`
- `ProjectTake.isSmartFillVariant`
- `ProjectTake.smartFillOriginalID`
- `ProjectSession.primaryOrientation`
- `ProjectSession.smartFillEnabled`
- `ProjectsRepository.updateTakeWithSmartFillPath`
- `ProjectsRepository.createStandaloneSmartFillTake`
- `ProjectsRepository.createSmartFillTake`
- `ProjectsRepository.loadSmartFillTakes`
- `ProjectsRepository.smartFillExists`
- `ProjectsRepository.clearSmartFill`

## Rebuild Laws
1. The shipped `SelfTapeStudio` app is read-only reference truth for shell fit and user workflow.
2. `itFactor_1.23.26_git` is the writable flagship SmartFill rebuild repo.
3. The current standalone SmartFill UI is not the product shell to preserve.
4. SmartFill processing, settings, preview, export, and result adoption must converge into one bounded editor workspace launched from project/session/take review.
5. Review/player and editor-origin SmartFill entry must share the same rebuild workspace seam before any delete-after-cutover legacy UI is removed.
6. Launch source and return target must stay explicit in flagship SmartFill context so workspace copy and completion behavior do not fall back to take-review-only assumptions.
7. Common treatment tuning must live in the shared rebuild workspace itself; do not reintroduce separate SmartFill tuning shells for the flagship flow.
8. Live SmartFill save progress must flow through shared engine notifications carrying take/session/project identity; do not push flagship save-state truth back into shell-specific banners or duplicate wrapper surfaces.
9. Workspace completion truth must be anchored to the latest saved SmartFill result snapshot; if settings change after save, the rebuild workspace must return to a save-needed state instead of pretending the session is still complete.
10. Quick background fill choices and save-outcome explanation must stay inside `SmartFillWorkspaceView` / `SmartFillWorkspacePresentation`; do not reintroduce separate treatment or save-explanation shells.
11. Treatment-finish presets and pre-save stay-versus-return choice must stay inside the shared rebuild workspace so flagship and future standalone flows use the same finish-state model instead of spawning new wrapper screens.
12. Save/update action titles, save-lane explanation, and completed-state guidance must obey the chosen finish behavior; never tell the user `Return` when the active SmartFill session is configured to `Stay`.
13. Saved-result summaries and completion guidance must carry the real adopted SmartFill take label from `SmartFillResultBridge`; never fall back to generic `SmartFill take` wording when repository truth already knows which session take was created or updated.
14. Completed-state primary actions and post-save handoff messaging must point at the real saved SmartFill take whenever repository truth already knows its label; never hide a concrete saved-result identity behind generic `Return to ...` wording.
15. Completed-state primary actions and automatic return behavior must reopen the adopted SmartFill take through an explicit follow-up route for project review/player, editor, or standalone fallback flows; never collapse a concrete saved-result handoff back into a generic close action.
16. Reopened review/player and editor destinations must explicitly identify that reopened take as the just-saved SmartFill result through `SmartFillReopenDestinationContext`; never silently land on the adopted take with no saved-result context.
17. Reopened review/player and editor destinations must surface a direct compare/open-source action whenever original-take lineage exists; never make the user hunt manually for the source take after SmartFill save completion when repository truth already knows the relationship.
18. The primary SmartFill editor surface must not be a long vertical settings document. `SmartFillWorkspaceView` should keep the preview pinned and expose tools through a contextual tray plus a persistent bottom mode rail so the same chrome can scale to more tools without reintroducing overlapping panels or explanatory paragraphs.
19. The tray-and-rail editor chrome must favor compact quick groups plus progressive disclosure. Common choices should stay visible as chips or pills, but raw sliders and secondary controls should appear only for the active adjustment instead of stacking every control in one scrolling tray.
20. When the tray starts carrying too many advanced controls, the flagship workspace must split them into dedicated secondary sheets instead of expanding the tray back into a tall settings surface. Quick choices stay inline; deeper tuning belongs behind explicit per-tool drill-ins.
21. Inline control ownership must stay intentional. Only the highest-frequency editing decisions should persist in the tray; lower-frequency controls such as detailed fill tuning, precision scale, output speed, and verbose save outcome review must remain sheet-only unless product evidence proves they deserve inline promotion.
22. Preview-adjacent chrome must stay tool-specific. The preview should show the active tool’s current values and one relevant drill-in path instead of a generic status row that repeats unrelated editor state.
23. The pinned preview must behave like a real editor surface. When the shared SmartFill preview engine already supports play/pause and scrubbing, the rebuild workspace should surface that live transport in-place instead of regressing to a passive preview wrapper or a separate player screen.
24. When SmartFill media is available but paused at rest, the workspace must still visibly present it. Do not let portrait SmartFill output read as a black empty player just because playback has not started yet; preserve a poster-frame seam that keeps the media visibly present without adding another preview shell.
25. Original-state comparison belongs beside the preview, not buried in save copy or delayed until reopen flow. When SmartFill users need to judge the result, the workspace should expose one direct path to scrub the untouched source clip without re-expanding the tray into another settings document.
26. Source-vs-result comparison should stay inside the same preview language. If both states are available, the main preview should switch between them inline and the larger source viewer should reuse the same stronger transport model instead of introducing a weaker secondary player.
27. Once source and result comparison both exist, they should share playback truth. Toggling between preview states must preserve scrub position and play/pause intent through one shared state seam instead of resetting the compare experience every time the user switches views.
28. Every SmartFill entry affordance that remains visible in review/player UI must wire into a real rebuild-workspace route. If the player can resolve a SmartFill request or edit intent, the surrounding HomeScreen/project-detail handoff must also provide the matching handler instead of leaving a dead chip path that logs `no handler is wired`.
29. Live playback transport should feel attached to the preview canvas itself. When the workspace already has a pinned preview, play/pause, scrubbing, and paused-state affordances should stay embedded in that canvas instead of appearing as a disconnected slab beneath it.
30. Preview comparison should stay low-chrome and gesture-friendly. When source and result previews already share one playback seam, the workspace should support momentary hold-to-compare on the canvas instead of growing another persistent compare row.
31. Shared SmartFill preview wrappers must preserve the original unified `AVPlayer` when one already exists. Never extract an `AVPlayerItem` from a live preview player and attach that same item to a second `AVPlayer`, because device runtime will terminate with `An AVPlayerItem cannot be associated with more than one instance of AVPlayer`.
32. Once the preview already owns live transport, the next seek refinement should also stay on the canvas. Precision scrubbing belongs to direct preview gestures with temporary HUD feedback and preserved play/resume intent, not another permanent transport row or a detached timing panel.
33. When the workspace opens a larger compare surface, it must still behave like one compare system. The larger viewer should switch between source and result at the same shared playhead and temporarily deactivate the inline preview underneath it instead of opening a disconnected source-only player with its own independent playback state.
34. Compare-specific gesture upgrades must stay temporary and local to the compare viewer. If the larger compare surface gains a wipe or divider gesture, it should disappear on release and must not introduce a new permanent compare bar, slider, or extra mode row in the main workspace chrome.
35. When compare behavior becomes important enough to deserve permanence, it should graduate into one compact grouped toolbar inside the larger compare viewer instead of oversized chips, repeated summary rows, or a second scrolling settings surface. Explicit `Source`, `Current`, and `Wipe` modes are acceptable when they keep the editor fixed-shell and clarify the compare system.
36. If the compare viewer already has an intentional permanent toolbar, it should remember the user's last compare mode inside the active workspace session instead of resetting on every reopen. That memory must stay scoped to the session and should reset cleanly when a new SmartFill workspace starts.
37. Once compare speed deserves a permanent preview-side entry point, that entry should live inside the existing preview focus deck and should mirror the remembered dominant compare mode. Do not solve preview-side compare discoverability by adding another compare row, compare slab, or long settings surface.
38. If preview-side compare affordances start multiplying, collapse them into one grouped control before adding more chrome. Source/result switching and large-viewer compare entry can coexist in the fixed-shell editor, but they should read like one compact toolbar seam instead of separate compare pills.
39. Once both the pinned preview and the larger compare viewer expose the same compare modes, they must share one compare-selection source of truth. Do not reintroduce a second shadow-copy memory object just to hand compare mode or pinned wipe position back and forth on sheet open/close.
40. Once the workspace already has a clear top toolbar, do not duplicate the same primary close/save actions in a second bottom bar. The rebuild workspace must keep one authoritative action owner so save/return intent stays obvious and the future standalone utility can inherit the same fixed-shell action model.
41. When SmartFill moves deeper into a professional editor shell, its chrome must adopt the studio theme library instead of the legacy pop-brand palette. The flagship and future standalone utility should share the darker cinematic shell so preview, transport, and tool chrome feel like one system instead of a marketing surface bolted onto an editor.
42. When background, subject, or output adjustments are small enough to fit inside the fixed tray, they should stay inline as studio expanders instead of reopening repetitive full-screen sheets. Reserve real drill-ins for compare viewing, save details, or controls whose content genuinely needs the extra space.
43. Once simple edits already live inline, the tray should flatten into one denser studio shelf instead of reintroducing a stack of inset mini-cards. Favor one shared compact inset language and smaller control sizing so the shell can scale toward the unified master editor without reading like a settings document.
44. When live preview transport already exists inside the SmartFill canvas, every playback action must first update the shared preview-state seam before mutating the underlying `AVPlayer`. Do not let tap-to-play, frame-step, or scrub completion bypass the authoritative playback owner, because preview rerenders will reapply stale `shouldPlay` state and make device playback look broken even when the preview surface is visible.
