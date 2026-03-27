# STS · SmartFill Rebuild Board

## Purpose
This board is the canonical operational queue for the SmartFill rebuild inside `itFactor_1.23.26_git`.

Detailed canonical catalog:
- `Docs/Operations/sts_ship_shape_full_catalog.md`

Rules:
- One SmartFill rebuild item exists in one place.
- Status changes must be synced with `Docs/Recovery/LAWS/STS_Status.md`.
- Standalone derivation notes must stay in `Docs/Recovery/SMARTFILL_STANDALONE_DERIVATION_LEDGER.md`.

---

## Board State (2026-03-27)
- Shipped shell truth comes from `/Users/kevinbarrett/Dev/SelfTapeStudio` and is read-only.
- Writable flagship integration truth lives in `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`.
- Remote rebuild truth lives at `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`.
- The first two rebuild slices are locally gated:
  - legacy audit
  - standalone derivation ledger
  - SmartFill bridge/coordinator scaffolding
  - focused parity coverage
- Review/player SmartFill launch now enters the rebuild workspace from `ProjectDetailView`.
- SmartFill completion now adopts output back through repository/session/take truth before notifying review/player listeners.
- Editor-origin SmartFill launch now enters the same rebuild workspace from `LightweightEditorViewController+ModularWiring` and `EditorCoordinator`.
- The dead editor-only SmartFill controller/modal/preview seam has been retired after cutover:
  - `SmartFillController.swift`
  - `SmartFillSettingsModal.swift`
  - `SmartFillRealPreviewSectionHandoff.swift`
- The dead settings-side SmartFill wrapper screens are now retired too:
  - `SmartFillSettingsView.swift`
  - `SmartFillMigrationDashboard.swift`
  - `SmartFillBatchProcessingView.swift`
- Shared advanced SmartFill tuning now lives only in `Features/SmartFill/Rebuild/SmartFillAdvancedSettingsView.swift`.
- One intentional SmartFill defaults surface now exists again under the rebuild namespace:
  - `Features/SmartFill/Rebuild/SmartFillDefaultsView.swift`
  - reachable from `SettingsView` as `SmartFill Defaults`
- The rebuild workspace now renders the actual SmartFill preview pipeline instead of a raw source player fallback, and preview refreshes are keyed on URL, settings, and an explicit refresh token.
- The rebuild workspace now exposes explicit user-facing product lanes for background look, subject framing, output, and save-back behavior instead of relying on generic preset/export copy.
- The rebuild workspace now also uses real launch/return context and stage-aware save copy instead of assuming every flow returns to take review.
- The rebuild workspace now keeps common treatment tuning inline and exposes an explicit `Return to ...` completed state instead of leaving the user in a generic saved/dismissed moment.
- The rebuild workspace now surfaces live save progress from the SmartFill engine and lets the user cancel auto-return with `Stay Here` when they need to linger after save.
- The rebuild workspace now keeps the latest saved result visible and drops back into a save-needed state whenever the user changes settings after a completed save.
- The rebuild workspace now carries the real adopted SmartFill take label through save outcome summaries, completed-state guidance, and latest saved-result details instead of falling back to generic `SmartFill take` wording.
- The rebuild workspace now uses that same saved take label in the completed-state primary action, pending auto-return messaging, and deferred-return guidance so users know exactly what result opens next.
- The rebuild workspace now actually reopens that saved SmartFill take from its completed-state primary action instead of only dismissing the sheet, and the follow-up route now respects whether the launch came from project review/player or editor.
- The rebuild workspace now also routes automatic `Return` through that same saved-result reopen seam instead of dismissing generically after save.
- Reopened project-review/player and editor destinations now explicitly identify that reopened take as the just-saved SmartFill result instead of silently landing on it.
- Reopened project-review/player and editor destinations now also expose direct comparison/open-source actions back to the original source take when SmartFill lineage exists.
- The rebuild workspace chrome now uses a fixed preview, compact status strip, contextual controls tray, and persistent bottom mode rail instead of one long SmartFill settings document.
- `authority/main` now exists remotely and locally at the untouched Jan 23 baseline.

---

## Completed Ledger
| Priority | ID | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| 0 | SF-REBUILD-001 | Legacy SmartFill audit + standalone derivation ledger + bridge/coordinator scaffold | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_rebuild_gateA_final.log`; focused parity PASS `/tmp/itfactor_smartfill_rebuild_tests_final2.log` |
| 0A | SF-REBUILD-002 | Repo bootstrap truth (`origin` + `authority/main` + promotion path) | COMPLETE | Remote `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`; `origin/main` and `origin/authority/main` now point to baseline `94883522cfa9a76c6fd779de8bac2afe5a4bb79b` |
| 1 | SF-REBUILD-003 | Review/player launch into `SmartFillSessionContext` + rebuild workspace entry | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase2_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase2_tests.log` |
| 2 | SF-REBUILD-005 | Repository-backed SmartFill result adoption and notification truth | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase3_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase3_tests_final.log` |
| 3 | SF-REBUILD-004 | Bounded SmartFill workspace replacement now shared by review/player and editor entry | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase4_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase4_tests.log` |
| 3A | SF-REBUILD-008 | Editor-origin SmartFill entry unification on rebuild workspace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase4_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase4_tests.log` |
| 4A | SF-REBUILD-009 | Restore one intentional SmartFill defaults entry under rebuild namespace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase7_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase7_tests.log`; `SettingsView` now opens `SmartFillDefaultsView` |
| 4B | SF-REBUILD-010 | Restore real SmartFill preview in rebuild workspace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase8_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase8_tests.log`; workspace now renders `SmartFillPreviewPlayer` with refresh-token reload coverage |
| 4C | SF-REBUILD-011 | Expose explicit workspace controls and save flow | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase11_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase11_tests.log`; workspace now presents explicit look, framing, output, and save lanes backed by `SmartFillWorkspacePresentation` |
| 4D | SF-REBUILD-012 | Tighten workspace return context and save states | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase12_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase12_tests.log`; workspace now reflects real return targets, stage-aware save copy, and explicit background-look modes |
| 4E | SF-REBUILD-013 | Deepen workspace treatment controls and return flow | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase13_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase13_tests.log`; workspace now keeps treatment tuning inline and turns completion into an explicit return action |
| 4F | SF-REBUILD-014 | Surface live save progress and explicit return control | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase14_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase14_tests.log`; workspace now shows live SmartFill save progress and lets the user stay in the editor after save instead of forcing immediate auto-return |
| 4G | SF-REBUILD-015 | Restore dirty-save truth in rebuild workspace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase15_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase15_tests_rerun.log`; workspace now shows the latest saved result and restores save-needed state when settings change after save |
| 4H | SF-REBUILD-016 | Strengthen background fill and save outcome affordances | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase16_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase16_tests_rerun2.log`; workspace now offers shipped-style quick fill presets and explains source-clip/result/return outcomes before save |
| 4I | SF-REBUILD-017 | Add treatment finish presets and explicit post-save stay mode | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase17_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase17_tests.log`; workspace now offers one-tap `Soft`/`Balanced`/`Bold` treatment presets and lets the user choose `Return` versus `Stay` before save |
| 4J | SF-REBUILD-018 | Align save affordances with chosen finish behavior | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase18_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase18_tests_rerun.log`; save/update actions, save-lane copy, and completed-state comparison guidance now match whether the user chose `Return` or `Stay` |
| 4K | SF-REBUILD-019 | Surface real saved take outcomes in rebuild workspace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase19_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase19_tests.log`; repository-backed and notification-backed SmartFill result adoption now feed the exact saved take label into save outcome summaries and completed-state stay/return guidance |
| 4L | SF-REBUILD-020 | Tighten post-save actions around real saved take | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase20_gateA_rerun.log`; focused parity PASS `/tmp/itfactor_smartfill_phase20_tests_rerun.log`; completed-state primary actions, pending auto-return copy, and deferred-return guidance now point at the actual saved SmartFill take instead of generic return wording |
| 4M | SF-REBUILD-021 | Reopen saved SmartFill take from completed workspace | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase21_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase21_tests.log`; completed-state primary actions now reopen the adopted SmartFill take through project-review/player or editor-specific follow-up routes instead of only dismissing the workspace |
| 4N | SF-REBUILD-022 | Route auto-return through saved-result reopen seam | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase22_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase22_tests.log`; queued automatic `Return` now uses the same saved-result follow-up seam as manual `Open <saved take>` actions instead of dismissing generically |
| 4O | SF-REBUILD-023 | Surface saved-result context in reopened destinations | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase23_gateA_rerun3.log`; focused parity PASS `/tmp/itfactor_smartfill_phase23_tests_rerun3.log`; player/review and editor reopen destinations now explicitly identify the just-saved SmartFill result instead of silently landing on it |
| 4P | SF-REBUILD-024 | Add source-take compare actions to reopened destinations | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase24_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase24_tests.log`; reopened player/review now offers one-tap compare-back-to-source and editor reopen now offers `Open <source take>` when original-take lineage exists |
| 4Q | SF-REBUILD-026 | Replace long-scroll workspace chrome with fixed preview + tray/rail editor shell | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase26_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase26_tests.log`; workspace now keeps the preview pinned and moves background/subject/output/save controls into one contextual tray plus one persistent bottom mode rail |
| 4R | SF-REBUILD-027 | Densify workspace trays with progressive tool groups | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase27_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase27_tests.log`; active tool trays now use compact chips, status pills, and one-at-a-time fine tuning so more SmartFill controls fit on-screen without reintroducing wordy scrolling panels |
| 4S | SF-REBUILD-028 | Move deeper workspace controls into secondary sheets | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase28_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase28_tests.log`; fine tuning, precision subject scale, output speed, and save-plan details now live in dedicated sheets while the main tray keeps only quick choices and current values |

---

## Active / Pending Queue
| Priority | ID | Description | Status | Notes |
| --- | --- | --- | --- | --- |
| 4 | SF-REBUILD-006 | Delete or retire duplicate legacy SmartFill UI surfaces after cutover | COMPLETE (LOCAL-GATED) | Editor-only seams retired in Phase 5; settings-side duplicate shells retired in Phase 6; Gate A PASS `/tmp/itfactor_smartfill_phase6_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase6_tests.log` |
| 5 | SF-REBUILD-007 | Standalone utility extraction package from flagship architecture | OPEN | Hidden static session derivation |

---

## Guardrails
- No code changes are allowed in `/Users/kevinbarrett/Dev/SelfTapeStudio`.
- Legacy SmartFill persistence fields are protected and must survive the rebuild.
- The standalone utility must be derived from flagship architecture, not designed as a competing shell.
- No direct promotion to `authority/main` is allowed from GM work. Promotion must follow `gm/* -> promo/* -> authority/main`.

---

## Next Action
1. Choose the next intentional workspace density slice now that the SmartFill editor no longer depends on a long vertical `ScrollView` document.
2. Implement that slice on GM, then rerun Gate A plus focused SmartFill parity before any promotion discussion.
3. Keep the standalone derivation ledger in sync while future shared-workspace chrome and tool-density work lands.
