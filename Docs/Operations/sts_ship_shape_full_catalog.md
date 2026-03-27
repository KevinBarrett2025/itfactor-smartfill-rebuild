# STS · SmartFill Rebuild Full Catalog

_Last updated:_ 2026-03-26

## Purpose
This file is the canonical detailed catalog for the SmartFill rebuild inside `itFactor_1.23.26_git`.

Rules:
- One rebuild contract maps to one `SF-REBUILD-*` item.
- Status can only be `COMPLETE`, `OPEN`, `PENDING`, `PAUSED`, `DEFERRED`, or `NEEDS_AUDIT`.
- `Docs/Recovery/LAWS/STS_Status.md` and `Docs/Operations/sts_ship_mode_nx_board.md` must stay synchronized with this catalog.

## Cross-Repo Truth
- Shipped shell reference:
  - `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only)
- Writable flagship rebuild repo:
  - `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Standalone SmartFill engine reference:
  - `/Users/kevinbarrett/Dev/iTFactorSmartfill`

## Catalog
| ID | Work Item | Status | Evidence / Notes |
| --- | --- | --- | --- |
| SF-REBUILD-001 | Legacy SmartFill audit + standalone derivation ledger + bridge/coordinator scaffold | COMPLETE | Audit matrix at `Docs/Recovery/SMARTFILL_ITFACTOR_REBUILD_AUDIT.md`; derivation ledger at `Docs/Recovery/SMARTFILL_STANDALONE_DERIVATION_LEDGER.md`; bridge/coordinator seams added under `STSiPhone/STSiPhone/Features/SmartFill/Rebuild`; Gate A PASS `/tmp/itfactor_smartfill_rebuild_gateA_final.log`; focused parity PASS `/tmp/itfactor_smartfill_rebuild_tests_final2.log` |
| SF-REBUILD-002 | Repo bootstrap truth (`origin`, `authority/main`, promotion path) | COMPLETE | Remote `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`; `origin/main` and `origin/authority/main` both point to baseline `94883522cfa9a76c6fd779de8bac2afe5a4bb79b` |
| SF-REBUILD-003 | Review/player launch integration into `SmartFillSessionContext` + `SmartFillWorkspaceCoordinator` | COMPLETE | `ProjectDetailView` now presents `SmartFillWorkspaceView`; settings seed through `SmartFillTakeBridge`; Gate A PASS `/tmp/itfactor_smartfill_phase2_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase2_tests.log` |
| SF-REBUILD-004 | Bounded SmartFill workspace replacement inside itFactor shell | COMPLETE | `SmartFillWorkspaceView` now owns both review/player and editor-origin entry; `SmartFillTakeBridge.editorLaunchSeed` resolves canonical/original take truth for refine vs create flows; Gate A PASS `/tmp/itfactor_smartfill_phase4_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase4_tests.log`; xcresult `/tmp/itfactor_smartfill_phase4_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-06-16--0400.xcresult` |
| SF-REBUILD-005 | SmartFill result adoption bridge into repository/take/session truth | COMPLETE | `SmartFillProcessingManager` now routes completion through `SmartFillResultBridge.adopt`; repository upsert creates or refreshes one authoritative SmartFill variant take; Gate A PASS `/tmp/itfactor_smartfill_phase3_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase3_tests_final.log`; xcresult `/tmp/itfactor_smartfill_phase3_tests_final/Logs/Test/Test-STSiPhone-2026.03.25_22-46-56--0400.xcresult` |
| SF-REBUILD-008 | Editor-origin SmartFill entry unification on rebuild workspace | COMPLETE | `LightweightEditorViewController+ModularWiring` now presents `SmartFillWorkspaceView`; `EditorCoordinator` routes `.smartFillRequested` back through the rebuild workspace; Gate A PASS `/tmp/itfactor_smartfill_phase4_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase4_tests.log`; xcresult `/tmp/itfactor_smartfill_phase4_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-06-16--0400.xcresult` |
| SF-REBUILD-006 | Legacy SmartFill cutover cleanup | COMPLETE | Phase 5 retired the editor-only seams (`SmartFillController.swift`, `SmartFillSettingsModal.swift`, `SmartFillRealPreviewSectionHandoff.swift`) with Gate A PASS `/tmp/itfactor_smartfill_phase5_gateA.log`, focused parity PASS `/tmp/itfactor_smartfill_phase5_tests.log`, xcresult `/tmp/itfactor_smartfill_phase5_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-25-08--0400.xcresult`; Phase 6 retired the dormant settings-side shells (`SmartFillSettingsView.swift`, `SmartFillMigrationDashboard.swift`, `SmartFillBatchProcessingView.swift`) and moved `SmartFillAdvancedSettingsView` under `Features/SmartFill/Rebuild` with Gate A PASS `/tmp/itfactor_smartfill_phase6_gateA.log`, focused parity PASS `/tmp/itfactor_smartfill_phase6_tests.log`, xcresult `/tmp/itfactor_smartfill_phase6_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-53-26--0400.xcresult` |
| SF-REBUILD-009 | Intentional SmartFill defaults entry under rebuild namespace | COMPLETE | `SettingsView` now presents `SmartFillDefaultsView`; defaults persist shared `SmartFillSettings`, reuse `SmartFillAdvancedSettingsView`, and seed rebuild workspace sessions; Gate A PASS `/tmp/itfactor_smartfill_phase7_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase7_tests.log`; xcresult `/tmp/itfactor_smartfill_phase7_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-11-10--0400.xcresult` |
| SF-REBUILD-010 | Real SmartFill preview in rebuild workspace | COMPLETE | `SmartFillWorkspaceView` now renders `SmartFillPreviewPlayer` against the active preview URL instead of a raw source player fallback; preview reload is keyed on URL, settings, and explicit refresh token; Gate A PASS `/tmp/itfactor_smartfill_phase8_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase8_tests.log`; xcresult `/tmp/itfactor_smartfill_phase8_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-29-03--0400.xcresult` |
| SF-REBUILD-011 | Explicit workspace controls and save flow | COMPLETE | `SmartFillWorkspaceView` now exposes background look, subject framing, output, and save-back lanes directly in the rebuild workspace; `SmartFillWorkspacePresentation` centralizes user-facing copy for header/action/save/output decisions; Gate A PASS `/tmp/itfactor_smartfill_phase11_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase11_tests.log`; xcresult `/tmp/itfactor_smartfill_phase11_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-04-50--0400.xcresult` |
| SF-REBUILD-012 | Tighten workspace return context and save states | COMPLETE | `ProjectDetailView` and editor-origin launch now seed explicit `launchSource` / `returnTarget` truth; `SmartFillWorkspaceView` now reflects real return destinations, stage-aware save action text, and explicit background-look modes while preserving the same shared settings engine; Gate A PASS `/tmp/itfactor_smartfill_phase12_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase12_tests.log`; xcresult `/tmp/itfactor_smartfill_phase12_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-27-31--0400.xcresult` |
| SF-REBUILD-013 | Deepen workspace treatment controls and return flow | COMPLETE | `SmartFillWorkspaceView` now keeps blur, darken, and background-fill tuning inline in the main workspace, exposes an explicit completed-stage `Return to ...` action, and slows auto-return enough for the saved state to be visible; Gate A PASS `/tmp/itfactor_smartfill_phase13_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase13_tests.log`; xcresult `/tmp/itfactor_smartfill_phase13_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-57-39--0400.xcresult` |
| SF-REBUILD-014 | Surface live save progress and explicit return control | COMPLETE | `SmartFillProcessingManager` progress notifications now carry take/session/project identity; `SmartFillWorkspaceView` now shows a live save-progress panel, progress-aware processing copy, and a `Stay Here` completion affordance alongside explicit `Return to ...` actions; Gate A PASS `/tmp/itfactor_smartfill_phase14_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase14_tests.log`; xcresult `/tmp/itfactor_smartfill_phase14_tests/Logs/Test/Test-STSiPhone-2026.03.26_12-32-18--0400.xcresult` |
| SF-REBUILD-015 | Restore dirty-save truth in rebuild workspace | COMPLETE | `SmartFillWorkspaceView` now compares live settings against the last saved result snapshot, keeps the latest saved-result summary visible, restores save/update actions after dirty changes, and cancels auto-return until the new changes are saved; Gate A PASS `/tmp/itfactor_smartfill_phase15_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase15_tests_rerun.log`; xcresult `/tmp/itfactor_smartfill_phase15_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_13-00-56--0400.xcresult` |
| SF-REBUILD-016 | Strengthen background fill and save outcome affordances | COMPLETE | `SmartFillWorkspaceView` now offers shipped-style quick background fill presets plus a `What happens on save` panel that explains source-clip truth, SmartFill result adoption, and return behavior before save; `SmartFillWorkspacePresentation` now owns first-save, in-progress, auto-return, clean-completion, and dirty-after-save outcome copy; Gate A PASS `/tmp/itfactor_smartfill_phase16_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase16_tests_rerun2.log`; xcresult `/tmp/itfactor_smartfill_phase16_tests_rerun2/Logs/Test/Test-STSiPhone-2026.03.26_13-34-53--0400.xcresult` |
| SF-REBUILD-017 | Add treatment finish presets and explicit post-save stay mode | COMPLETE | `SmartFillWorkspaceView` now offers one-tap `Soft`, `Balanced`, and `Bold` treatment-finish presets over the shared blur/darken engine, plus an explicit `After save behavior` control for `Return` versus `Stay`; `SmartFillWorkspacePresentation` now tells the truth about processing, completion, and deferred-return copy when the user stays in the workspace after save; Gate A PASS `/tmp/itfactor_smartfill_phase17_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase17_tests.log`; xcresult `/tmp/itfactor_smartfill_phase17_tests/Logs/Test/Test-STSiPhone-2026.03.26_14-13-06--0400.xcresult` |
| SF-REBUILD-018 | Align save affordances with chosen finish behavior | COMPLETE | `SmartFillWorkspacePresentation` now makes save/update action titles, save-lane copy, and footnotes obey the user's explicit `Return` versus `Stay` choice; `SmartFillWorkspaceView` now shows a completed-state `Saved and staying here` comparison panel when the user remains in the workspace after save; Gate A PASS `/tmp/itfactor_smartfill_phase18_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase18_tests_rerun.log`; xcresult `/tmp/itfactor_smartfill_phase18_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_15-00-06--0400.xcresult` |
| SF-REBUILD-019 | Surface real saved take outcomes in rebuild workspace | COMPLETE | `SmartFillResultBridgeRecord` now carries the concrete adopted SmartFill take label from repository-backed and notification-backed adoption; `SmartFillWorkspaceView` now shows that exact saved take name in save outcome summaries, latest saved-result details, and completed-state stay/return guidance; Gate A PASS `/tmp/itfactor_smartfill_phase19_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase19_tests.log`; xcresult `/tmp/itfactor_smartfill_phase19_tests/Logs/Test/Test-STSiPhone-2026.03.26_17-17-41--0400.xcresult` |
| SF-REBUILD-020 | Tighten post-save actions around real saved take | COMPLETE | `SmartFillWorkspacePresentation` now turns clean completed-state primary actions into `Open <saved take>` when repository truth knows the adopted SmartFill take label; save outcome, pending auto-return, and deferred-return copy now point at that same saved take instead of generic destination wording; Gate A PASS `/tmp/itfactor_smartfill_phase20_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase20_tests_rerun.log`; xcresult `/tmp/itfactor_smartfill_phase20_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_17-52-38--0400.xcresult` |
| SF-REBUILD-021 | Reopen saved SmartFill take from completed workspace | COMPLETE | `SmartFillWorkspaceView` now routes completed-state primary actions through `onOpenSavedTake`; `ProjectDetailView` now resolves the adopted SmartFill take from repository truth and reopens it in the correct player/review flow; `LightweightEditorViewController+ModularWiring` now swaps the editor onto the saved SmartFill take after workspace completion; `SmartFillWorkspaceFollowUpRoute` centralizes follow-up routing for editor, player/review, project-detail, and standalone fallback; Gate A PASS `/tmp/itfactor_smartfill_phase21_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase21_tests.log`; xcresult `/tmp/itfactor_smartfill_phase21_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-35-50--0400.xcresult` |
| SF-REBUILD-022 | Route auto-return through saved-result reopen seam | COMPLETE | `SmartFillWorkspaceCompletionFollowUpAction` now centralizes completed-state follow-up behavior; `SmartFillWorkspaceView` now routes automatic `Return` through the same saved-result reopen seam as manual primary actions instead of dismissing generically; Gate A PASS `/tmp/itfactor_smartfill_phase22_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase22_tests.log`; xcresult `/tmp/itfactor_smartfill_phase22_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-55-45--0400.xcresult` |
| SF-REBUILD-023 | Surface saved-result context in reopened destinations | COMPLETE | `SmartFillReopenDestinationContext` now centralizes saved-result reopen presentation; `ProjectDetailView` + `SwipeableVideoPlayerView` now explicitly identify reopened SmartFill results in player/review flow; `LightweightEditorViewController+ModularWiring` now surfaces the same saved-result context after editor reopen; Gate A PASS `/tmp/itfactor_smartfill_phase23_gateA_rerun3.log`; focused parity PASS `/tmp/itfactor_smartfill_phase23_tests_rerun3.log`; xcresult `/tmp/itfactor_smartfill_phase23_tests_rerun3/Logs/Test/Test-STSiPhone-2026.03.26_19-56-52--0400.xcresult` |
| SF-REBUILD-024 | Add source-take compare actions to reopened destinations | COMPLETE | `SmartFillReopenDestinationContext` now carries original/source take identity alongside saved-result context; `ProjectDetailView` + `SwipeableVideoPlayerView` now expose direct compare-back-to-source behavior in the reopened player/review destination; `LightweightEditorViewController+ModularWiring` now offers direct `Open <source take>` comparison from the reopened editor destination; Gate A PASS `/tmp/itfactor_smartfill_phase24_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase24_tests.log`; xcresult `/tmp/itfactor_smartfill_phase24_tests/Logs/Test/Test-STSiPhone-2026.03.26_20-21-40--0400.xcresult` |
| SF-REBUILD-007 | Standalone utility extraction package from flagship architecture | OPEN | Same engine/workspace, hidden static session, reduced shell |

## Protected Persistence / Data Seams
These remain authoritative and must survive cleanup:
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

## Delete-After-Cutover Targets
None currently open under `SF-REBUILD-006`.

## Retired Delete-After-Cutover Targets
- `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift` — retired in `SF-REBUILD-006` phase 5
- `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift` — retired in `SF-REBUILD-006` phase 5
- `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift` — retired in `SF-REBUILD-006` phase 5
- `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift` — retired in `SF-REBUILD-006` phase 6
- `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift` — retired in `SF-REBUILD-006` phase 6
- `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift` — retired in `SF-REBUILD-006` phase 6

## Intentional Settings Seams
- `STSiPhone/STSiPhone/Features/Settings/SettingsView.swift` — one reachable SmartFill defaults entry owned by `SF-REBUILD-009`
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillDefaultsView.swift` — authoritative flagship defaults surface for rebuild-owned SmartFill tuning
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillAdvancedSettingsView.swift` — shared advanced defaults/settings sheet used by both defaults and workspace flows
- `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillPreviewPlayer.swift` — authoritative preview seam reused by the rebuild workspace and later standalone utility
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillResultBridge.swift` — authoritative saved-result adoption seam now carrying the concrete adopted SmartFill take label for workspace and later standalone save-result messaging
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceFollowUpRoute.swift` — authoritative follow-up routing seam for saved-result reopen behavior and completed-state manual/automatic follow-up policy across project review/player, editor, and later standalone hidden-session flows
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillReopenDestinationContext.swift` — authoritative saved-result plus source-take comparison destination-context seam for reopened player/review, editor, and later standalone hidden-session result views
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePresentation` — authoritative user-facing copy seam for workspace launch, look, framing, inline treatment messaging, stage-aware save/update wording, live progress messaging, deferred return messaging, dirty-after-save messaging, stay-here completion guidance, real return-target language, and saved-take-aware post-save actions
- `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillProcessingManager.swift` — authoritative SmartFill progress notification seam now carrying take/session/project identity for rebuild workspace progress handling

## Shared-vs-Flagship-vs-Standalone Rule
- Flagship-only:
  - project/session/take shell
  - review/player launch context
  - explicit repository lineage
- Shared:
  - SmartFill request/result model
  - workspace coordinator
  - settings snapshot logic
  - preview/render/export lifecycle
- Standalone later:
  - hidden static session
  - no visible project/session vocabulary
  - simplified history/export shell over the same engine

## Next Action
1. Choose the next intentional flagship SmartFill workspace/product phase now that `SF-REBUILD-009`, `SF-REBUILD-010`, `SF-REBUILD-011`, `SF-REBUILD-012`, `SF-REBUILD-013`, `SF-REBUILD-014`, `SF-REBUILD-015`, `SF-REBUILD-016`, `SF-REBUILD-017`, `SF-REBUILD-018`, `SF-REBUILD-019`, `SF-REBUILD-020`, `SF-REBUILD-021`, `SF-REBUILD-022`, `SF-REBUILD-023`, and `SF-REBUILD-024` give the rebuild defaults, real preview, explicit product lanes, real launch/return messaging, inline treatment control, live save-state feedback, honest dirty-after-save truth, shipped-style quick fill choices, one-tap treatment-finish presets, explicit stay-versus-return save behavior, finish-state-aware save affordances, concrete saved-take outcome messaging, saved-take-aware post-save actions, real reopen handoff for the adopted SmartFill take across both manual and automatic finish paths, explicit saved-result context in the reopened destinations themselves, and direct source-take comparison actions once those reopened destinations appear.
2. Implement that next slice on `gm/smartfill-itfactor-rebuild` with Gate A plus focused SmartFill parity before any promotion decision.
3. Keep standalone derivation synchronized in every phase.
