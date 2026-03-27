# STS Status — SmartFill Rebuild Source of Truth

_Last updated:_ 2026-03-27  
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
- Workspace real saved-take outcome messaging: COMPLETE (LOCAL-GATED)
- Workspace post-save actions point at the real saved take: COMPLETE (LOCAL-GATED)
- Workspace saved-take primary action now performs real reopen handoff: COMPLETE (LOCAL-GATED)
- Workspace auto-return now reopens the saved take too: COMPLETE (LOCAL-GATED)
- Reopened destinations now surface explicit saved-result context: COMPLETE (LOCAL-GATED)
- Reopened destinations now offer direct source-take comparison actions: COMPLETE (LOCAL-GATED)
- Workspace chrome now uses a fixed preview, contextual tray, and bottom mode rail: COMPLETE (LOCAL-GATED)
- Workspace preview now owns the active tool focus deck: COMPLETE (LOCAL-GATED)
- Workspace preview now exposes live play/pause and scrubbing transport: COMPLETE (LOCAL-GATED)
- Workspace preview now exposes original-source comparison in a dedicated live sheet: COMPLETE (LOCAL-GATED)
- Workspace preview now supports inline result-vs-original switching with a stronger live source viewer: COMPLETE (LOCAL-GATED)
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
- `SF-REBUILD-017` — treatment finish presets and explicit post-save stay mode — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now offers one-tap `Soft`, `Balanced`, and `Bold` treatment-finish presets plus an explicit `After save behavior` choice so users can decide whether SmartFill should return automatically or stay open for preview comparison.
  - `SmartFillWorkspacePresentation` now differentiates processing, completion, and deferred-return wording when the user chooses to stay in the workspace after save.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase17_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase17_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase17_tests/Logs/Test/Test-STSiPhone-2026.03.26_14-13-06--0400.xcresult`
- `SF-REBUILD-018` — align save affordances with chosen finish behavior — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspacePresentation` now makes save/update action titles, save-lane copy, and footnotes obey the user's explicit `Return` versus `Stay` choice instead of defaulting to return-oriented wording.
  - `SmartFillWorkspaceView` now shows a completed-state `Saved and staying here` comparison panel when the user saves and intentionally remains in the workspace.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase18_gateA_rerun.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase18_tests_rerun.log`
  - xcresult: `/tmp/itfactor_smartfill_phase18_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_15-00-06--0400.xcresult`
- `SF-REBUILD-019` — surface real saved take outcomes in rebuild workspace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillResultBridgeRecord` now carries the concrete adopted SmartFill take label from repository adoption and notification-backed reopen paths.
  - `SmartFillWorkspaceView` now uses that exact saved take label in save outcome summaries, latest saved-result details, and completed-state stay/return guidance.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase19_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase19_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase19_tests/Logs/Test/Test-STSiPhone-2026.03.26_17-17-41--0400.xcresult`
- `SF-REBUILD-020` — tighten post-save actions around real saved take — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspacePresentation` now turns clean completed-state primary actions into `Open <saved take>` when repository truth already knows the adopted SmartFill take label.
  - Save outcome titles/messages and deferred-return guidance now point at that same saved take instead of generic destination wording.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase20_gateA_rerun.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase20_tests_rerun.log`
  - xcresult: `/tmp/itfactor_smartfill_phase20_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_17-52-38--0400.xcresult`
- `SF-REBUILD-021` — reopen saved SmartFill take from completed workspace — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceView` now routes its completed-state primary action through a saved-result callback instead of a generic close.
  - `ProjectDetailView` now resolves and reopens the adopted SmartFill take in the correct player/review flow, while editor-origin launch now swaps directly onto that saved take after workspace dismissal.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase21_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase21_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase21_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-35-50--0400.xcresult`
- `SF-REBUILD-022` — route auto-return through saved-result reopen seam — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillWorkspaceCompletionFollowUpAction` now centralizes manual-versus-auto completed-state follow-up behavior.
  - `SmartFillWorkspaceView` now routes automatic `Return` through the same saved-result reopen seam used by manual `Open <saved take>` actions instead of dismissing generically.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase22_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase22_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase22_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-55-45--0400.xcresult`
- `SF-REBUILD-023` — surface saved-result context in reopened destinations — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillReopenDestinationContext` now carries user-facing saved-result identity into player/review and editor reopen destinations.
  - `ProjectDetailView` + `SwipeableVideoPlayerView` now explicitly identify the reopened adopted SmartFill take instead of silently landing on it, and editor reopen now shows the same saved-result context after the take swap.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase23_gateA_rerun3.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase23_tests_rerun3.log`
  - xcresult: `/tmp/itfactor_smartfill_phase23_tests_rerun3/Logs/Test/Test-STSiPhone-2026.03.26_19-56-52--0400.xcresult`
- `SF-REBUILD-024` — add source-take compare actions to reopened destinations — `COMPLETE (LOCAL-GATED 2026-03-26)`
  - `SmartFillReopenDestinationContext` now also carries original/source take identity and compare/open-source action titles alongside the saved-result context.
  - `SwipeableVideoPlayerView` now exposes a direct compare action that jumps from the reopened SmartFill result back to the original source take, and editor reopen now offers the same source-take jump through its completion alert.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase24_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase24_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase24_tests/Logs/Test/Test-STSiPhone-2026.03.26_20-21-40--0400.xcresult`
- `SF-REBUILD-026` — replace long-scroll workspace chrome with fixed preview + tray/rail editor shell — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now keeps the preview pinned, adds a compact workspace status strip, and moves editing controls into one contextual tray plus one persistent bottom mode rail.
  - Background, subject, output, and save controls now render as contextual tool surfaces instead of stacked `ScrollView` panels, and the workspace copy is reduced to short labels plus current values.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase26_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase26_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase26_tests/Logs/Test/Test-STSiPhone-2026.03.27_08-13-12--0400.xcresult`
- `SF-REBUILD-027` — densify workspace trays with progressive tool groups — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now condenses the active tray into compact tool groups so common background, subject, output, and save controls stay visible without reviving a long scrolling settings pane.
  - The background lane now exposes quick `Mode`, `Fill`, `Finish`, and `Adjust` chips plus one active fine-tune control at a time, while framing/output controls use denser chips and save summary rows are compressed into status pills.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase27_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase27_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase27_tests/Logs/Test/Test-STSiPhone-2026.03.27_08-34-30--0400.xcresult`
- `SF-REBUILD-028` — move deeper workspace controls into secondary sheets — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now keeps fast chips and current values inline, but routes fine tuning, precision subject scale, processing speed, and save-plan details into explicit secondary sheets instead of growing the main tray back into a form.
  - The tray height is lower, the main rail stays lighter, and save/reopen behavior still uses the same shared rebuild seams.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase28_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase28_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase28_tests/Logs/Test/Test-STSiPhone-2026.03.27_08-54-02--0400.xcresult`
- `SF-REBUILD-029` — clarify inline control ownership in workspace chrome — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now keeps only the highest-value edit choices inline: background mode, treatment finish, subject presets, output resolution, and after-save behavior.
  - Background fill, fine tuning, precision subject scale, output speed, and save-plan detail now live behind consistent drill-in chips and sheets instead of competing with the main editor chrome.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase29_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase29_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase29_tests/Logs/Test/Test-STSiPhone-2026.03.27_09-22-43--0400.xcresult`
- `SF-REBUILD-030` — attach active tool focus to the preview surface — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now replaces the generic status strip with a preview-attached focus deck that reflects the active tool, its current key values, and one context-aware drill-in action.
  - `SmartFillWorkspaceTool` now owns a small focus/drill-in descriptor seam so the preview-adjacent tool summary stays intentional and testable as more SmartFill tools land.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase30_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase30_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase30_tests/Logs/Test/Test-STSiPhone-2026.03.27_09-47-12--0400.xcresult`
- `SF-REBUILD-031` — restore live preview transport in the rebuild workspace — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now uses `SmartFillPreviewView` in the pinned preview surface so the workspace carries real play/pause and scrub transport instead of a passive player wrapper.
  - File/live badges now sit above the preview, leaving transport controls unobstructed while the preview-focus deck stays attached below the player.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase31_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase31_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase31_tests/Logs/Test/Test-STSiPhone-2026.03.27_10-09-37--0400.xcresult`
- `SF-REBUILD-032` — add preview-adjacent original/source comparison — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now exposes an `Original` compare affordance beside the live preview, shows source/result reference chips under the preview, and opens a dedicated scrubbable source-preview sheet without expanding the tray chrome.
  - Focused parity now locks the source-preview presentation copy for both pre-save and post-save result states.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase32_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase32_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase32_tests/Logs/Test/Test-STSiPhone-2026.03.27_10-35-16--0400.xcresult`
- `SF-REBUILD-033` — tighten inline source-result preview compare states — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now lets the pinned preview switch directly between `Result` and `Original` states from the preview-adjacent reference chips while preserving the larger source drill-in viewer.
  - `SmartFillSourcePreviewView` now reuses the stronger live transport style, so the dedicated original viewer matches the professional feel of the main preview surface instead of falling back to a weaker player.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase33_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase33_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase33_tests/Logs/Test/Test-STSiPhone-2026.03.27_11-09-29--0400.xcresult`
- `SF-REBUILD-034` — synchronize source-result live preview states — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `SmartFillWorkspaceView` now keeps both result and source previews mounted with one shared playback-state seam, so toggling the pinned preview between `Result` and `Original` preserves the compare position and play/pause intent instead of resetting the live preview feel.
  - The source drill-in viewer now honors that same shared playback state, and focused parity directly locks the new playback-state replacement/clamping rules.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase34_gateA.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase34_tests.log`
  - xcresult: `/tmp/itfactor_smartfill_phase34_tests/Logs/Test/Test-STSiPhone-2026.03.27_14-13-26--0400.xcresult`
- `SF-REBUILD-035` — route portrait player SmartFill chip to the real target — `COMPLETE (LOCAL-GATED 2026-03-27)`
  - `HomeScreenView` now wires portrait-player SmartFill taps through real request/edit handlers into the rebuild workspace instead of letting the player resolve an intent and then log `no handler is wired`.
  - `SwipeableMediaPlayerView` now carries the needed current-session truth for the HomeScreen handoff, and focused parity now locks the new HomeScreen route helpers alongside the player entry resolver.
  - Gate A PASS: `/tmp/itfactor_smartfill_phase35_gateA_clean.log`
  - Focused parity PASS: `/tmp/itfactor_smartfill_phase35_tests_final3.log`
  - xcresult: `/tmp/itfactor_smartfill_phase35_tests_final3/Logs/Test/Test-STSiPhone-2026.03.27_15-50-28--0400.xcresult`
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

1. Use `SF-REBUILD-035` as the new SmartFill workspace baseline and decide the next real editor-quality upgrade now that the synchronized source/result preview seam is intact and the HomeScreen portrait-player SmartFill chip actually opens the rebuild workspace.
2. Implement that next slice on GM with Gate A and focused SmartFill parity before any promotion discussion.
3. Keep the standalone derivation ledger updated in every phase so the utility app inherits the same fixed preview + tray/rail shell, inline ownership model, preview-focus deck, live transport surface, synchronized source/result compare behavior, working entry routing, and tray-to-sheet split for deeper tools.
