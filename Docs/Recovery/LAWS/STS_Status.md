# STS Status — SmartFill Rebuild Source of Truth

_Last updated:_ 2026-03-26  
_Authority branch:_ `authority/main`  
_Current rebuild working baseline:_ `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

---

## RULE OF LAW

- `/Users/kevinbarrett/Dev/SelfTapeStudio` is the shipped reference app and is read-only.
- `/Users/kevinbarrett/Dev/itFactor_1.23.26_git` is the writable flagship SmartFill rebuild repo.
- `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git` is the remote rebuild repo.
- `authority/main` is the canonical baseline branch for this rebuild repo.
- The standalone SmartFill utility is a future derivative of the flagship architecture, not the shell authority.
- Status changes must be synced with:
  - `Docs/Recovery/CODEX_THREAD_CONTINUITY.md`
  - `Docs/Operations/sts_ship_mode_nx_board.md`
  - `Docs/Operations/sts_ship_shape_full_catalog.md`

---

## CURRENT SYSTEM HEALTH

- SmartFill legacy audit: ACTIVE
- SmartFill bridge-layer bootstrap: COMPLETE (LOCAL-GATED)
- Project/session/take launch integration: COMPLETE (LOCAL-GATED)
- SmartFill bounded workspace replacement: COMPLETE (LOCAL-GATED)
- Result adoption + repository writeback: COMPLETE (LOCAL-GATED)
- Editor-origin SmartFill entry unification: COMPLETE (LOCAL-GATED)
- Legacy editor SmartFill seam retirement: COMPLETE (LOCAL-GATED)
- Settings-side SmartFill duplication retirement: COMPLETE (LOCAL-GATED)
- Intentional SmartFill defaults entry: COMPLETE (LOCAL-GATED)
- Real SmartFill preview in rebuild workspace: COMPLETE (LOCAL-GATED)
- Explicit workspace controls and save flow: COMPLETE (LOCAL-GATED)
- Workspace return context and save states: COMPLETE (LOCAL-GATED)
- Workspace treatment controls and return flow: COMPLETE (LOCAL-GATED)
- Workspace save progress and return control: COMPLETE (LOCAL-GATED)
- Workspace dirty-save truth after completion: COMPLETE (LOCAL-GATED)
- Standalone derivation ledger: ACTIVE

If anything above is not true, it must be reflected here.

---

## SMARTFILL REBUILD TRACKING

- `SF-REBUILD-001` — legacy audit + standalone derivation ledger + bridge/coordinator scaffold — `COMPLETE (LOCAL-GATED 2026-03-25)`
  - Gate A PASS: `/tmp/itfactor_smartfill_rebuild_gateA_final.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_rebuild_tests_final2.log`
  - xcresult: `/tmp/itfactor_smartfill_rebuild_tests_final2/Logs/Test/Test-STSiPhone-2026.03.25_19-50-58--0400.xcresult`
- `SF-REBUILD-002` — repo bootstrap truth (`origin` + `authority/main` + promotion path) — `COMPLETE`
- `SF-REBUILD-003` — review/player launch into SmartFill session context — `COMPLETE (LOCAL-GATED 2026-03-25)`
  - Gate A PASS: `/tmp/itfactor_smartfill_phase2_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase2_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase2_tests/Logs/Test/Test-STSiPhone-2026.03.25_21-16-50--0400.xcresult`
- `SF-REBUILD-004` — bounded SmartFill workspace in flagship itFactor shell — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - Review/player and editor-origin entry now both route through `SmartFillWorkspaceView` and `SmartFillTakeBridge` canonical launch seeding.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase4_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase4_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase4_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-06-16--0400.xcresult`
- `SF-REBUILD-005` — result adoption bridge into repository/session/take truth — `COMPLETE (LOCAL-GATED 2026-03-25)`
  - Gate A PASS: `/tmp/itfactor_smartfill_phase3_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase3_tests_final.log`
  - xcresult: `/tmp/itfactor_smartfill_phase3_tests_final/Logs/Test/Test-STSiPhone-2026.03.25_22-46-56--0400.xcresult`
- `SF-REBUILD-006` — legacy SmartFill UI cutover cleanup (`DELETE_AFTER_CUTOVER`) — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - Phase 5 GM slice retired the editor-only legacy seams:
    - `SmartFillSettingsModal.swift`
    - `SmartFillRealPreviewSectionHandoff.swift`
    - `SmartFillController.swift`
  - Phase 6 GM slice retires the dormant settings-side duplicates:
    - `SmartFillSettingsView.swift`
    - `SmartFillMigrationDashboard.swift`
    - `SmartFillBatchProcessingView.swift`
  - Shared `SmartFillAdvancedSettingsView` now lives under `Features/SmartFill/Rebuild`.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase6_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase6_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase6_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-53-26--0400.xcresult`
- `SF-REBUILD-009` — intentional SmartFill defaults entry under rebuild namespace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SettingsView` now exposes one reachable `SmartFill Defaults` entry instead of reviving deleted settings-side wrappers.
  - `SmartFillDefaultsView` persists shared `SmartFillSettings` defaults, reuses `SmartFillAdvancedSettingsView`, and seeds future rebuild workspace sessions.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase7_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase7_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase7_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-11-10--0400.xcresult`
- `SF-REBUILD-010` — real SmartFill preview in rebuild workspace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now renders `SmartFillPreviewPlayer` against the workspace preview URL instead of a raw source player fallback.
  - Preview reload now keys off URL, full settings, and an explicit refresh token so workspace changes refresh deterministically.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase8_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase8_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase8_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-29-03--0400.xcresult`
- `SF-REBUILD-011` — explicit workspace controls and save flow — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now exposes intentional look, framing, output, and save lanes instead of relying on generic preset/export sections.
  - `SmartFillWorkspacePresentation` centralizes human-readable workspace copy for header, action, save destination, framing, and output descriptions.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase11_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase11_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase11_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-04-50--0400.xcresult`
- `SF-REBUILD-012` — workspace return context and save-state tightening — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `ProjectDetailView` and editor-origin launch now seed real `launchSource` and `returnTarget` truth into `SmartFillSettingsContext`.
  - `SmartFillWorkspaceView` and `SmartFillWorkspacePresentation` now use stage-aware action/copy plus explicit background-look modes that still map onto shared `SmartFillSettings`.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase12_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase12_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase12_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-27-31--0400.xcresult`
- `SF-REBUILD-013` — workspace treatment controls and return-flow tightening — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now exposes inline blur, darken, and background-fill controls plus clearer completed-stage return actions without leaving the rebuild workspace.
  - Completed-state copy now describes the active return path while the workspace schedules a more visible auto-return back into review/player/editor flow.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase13_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase13_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase13_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-57-39--0400.xcresult`
- `SF-REBUILD-014` — workspace save progress and return-control tightening — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillProcessingManager` progress notifications now carry take/session/project identity so the rebuild workspace can consume real progress safely.
  - `SmartFillWorkspaceView` now shows live save progress, exposes a `Stay Here` completion affordance, and keeps explicit `Return to ...` control after save.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase14_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase14_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase14_tests/Logs/Test/Test-STSiPhone-2026.03.26_12-32-18--0400.xcresult`
- `SF-REBUILD-015` — restore dirty-save truth in rebuild workspace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now compares current settings to the last saved result snapshot, surfaces the saved-result summary inline, and restores save/update actions whenever the user changes settings after a completed save.
  - Auto-return now cancels when the current workspace state diverges from the last saved output, so completion and return affordances stay honest.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase15_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase15_tests_rerun.log`
  - xcresult: `/tmp/itfactor_smartfill_phase15_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_13-00-56--0400.xcresult`
- `SF-REBUILD-016` — strengthen background fill and save outcome affordances — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now exposes shipped-style quick background fill presets alongside the fill slider and explains what save will do to the source clip, SmartFill result, and return path before the user commits a render.
  - Save copy now differentiates first-save, save-in-progress, pending auto-return, clean completion, and dirty-after-save states without reviving any legacy wrapper surfaces.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase16_gateA_rerun.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase16_tests_rerun2.log`
  - xcresult: `/tmp/itfactor_smartfill_phase16_tests_rerun2/Logs/Test/Test-STSiPhone-2026.03.26_13-34-53--0400.xcresult`
- `SF-REBUILD-008` — editor-origin SmartFill entry unification on rebuild workspace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - Gate A PASS: `/tmp/itfactor_smartfill_phase4_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase4_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase4_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-06-16--0400.xcresult`
- `SF-REBUILD-007` — standalone extraction package from flagship architecture — `OPEN`

---

## KNOWN FOLLOW-UPS

- Repository SmartFill persistence seams must survive cleanup:
  - `ProjectTake.overrideSmartFill`
  - `ProjectTake.smartFilledFilePath`
  - `ProjectTake.smartFillSettings`
  - `ProjectTake.smartFillOriginalID`
  - `ProjectsRepository.createStandaloneSmartFillTake`
  - `ProjectsRepository.updateTakeWithSmartFillPath`
- Global SmartFill defaults now live in `Features/SmartFill/Rebuild/SmartFillDefaultsView.swift` and must evolve there instead of reviving deleted settings/dashboard shells.

---

## NEXT ACTION

1. Decide the next intentional flagship SmartFill workspace evolution now that the rebuild owns entry, preview, defaults, quick fill choices, explicit save-outcome truth, live save-state feedback, and honest post-save dirty-state handling.
2. Implement that next slice on `gm/smartfill-itfactor-rebuild` with Gate A and focused SmartFill parity before any promotion discussion.
3. Keep the standalone derivation ledger updated in every phase.
