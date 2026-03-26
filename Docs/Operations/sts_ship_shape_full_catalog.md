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
- `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspacePresentation` — authoritative user-facing copy seam for workspace launch, look, framing, inline treatment messaging, stage-aware save messaging, and real return-target language

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
1. Commit and push the workspace treatment-controls and return-flow slice.
2. Choose the next intentional flagship SmartFill workspace/product phase now that `SF-REBUILD-009`, `SF-REBUILD-010`, `SF-REBUILD-011`, `SF-REBUILD-012`, and `SF-REBUILD-013` give the rebuild defaults, real preview, explicit product lanes, real launch/return messaging, and inline treatment control.
3. Keep standalone derivation synchronized in every phase.
