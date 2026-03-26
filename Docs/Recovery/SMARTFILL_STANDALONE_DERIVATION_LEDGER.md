# SmartFill Standalone Derivation Ledger

Date: 2026-03-26
Flagship Repo: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
Shipped Reference: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only)
Standalone Engine Source: `/Users/kevinbarrett/Dev/iTFactorSmartfill`

## Purpose
This ledger records, at every flagship SmartFill integration stage, how the same seam will later become a standalone SmartFill utility app. The flagship app remains the primary product. The standalone app is a later derivative that should feel simpler, smaller, and clearly less expansive than the flagship shell.

## Standing Rules
1. Flagship itFactor keeps visible `project -> session -> take -> SmartFill`.
2. Standalone utility hides project/session vocabulary behind one internal static session.
3. Shared SmartFill engine logic should live behind bridge/coordinator seams, not inside a one-off shell UI.
4. Standalone derivation notes must be updated whenever flagship SmartFill architecture changes.

## Current Derivation Decisions
| Flagship Seam | Flagship Purpose | Standalone Derivation |
| --- | --- | --- |
| `ProjectsRepository` + SQLite SmartFill methods | Persist project/session/take lineage and SmartFill variants | Replace with a lightweight local utility store that persists one implicit working session and history ledger |
| `ProjectDetailView` / `SwipeableVideoPlayerView` launch path | Gives users stable context before entering SmartFill | Replace with a single import/open clip entry point that internally creates or reuses the implicit session |
| `SmartFillSessionContext` | Carries project/session/take launch truth | Becomes the standalone utility’s hidden static session context |
| `SmartFillTakeBridge` | Maps flagship take/session models into SmartFill requests | Maps utility local clip/import metadata into the same SmartFill request model |
| `SmartFillResultBridge` | Writes output back into project/session/take review | Writes output into lightweight utility history and destination records |
| `SmartFillWorkspaceView` + `SmartFillWorkspaceCoordinator` | Hosts the real SmartFill workspace launched from take review | Reused as the standalone utility editor scene, but launched from a hidden static-session import flow instead of project/session/take review |

## What Must Stay Flagship-Only
- project lists
- session lists
- take review/player shell
- explicit project/session persistence vocabulary
- review-routing return destinations

## What Must Become Shared
- SmartFill request model
- SmartFill settings snapshot logic
- output preset/background mode/save destination policy
- preview/render/export lifecycle coordination
- result adoption contract

## What The Standalone Utility Should Look Like Later
1. User opens the app.
2. User imports one clip.
3. App creates or reuses one hidden static SmartFill session.
4. User edits SmartFill in the same workspace model used by flagship itFactor.
5. User exports/saves/shares.
6. App keeps lightweight local history, but never exposes project/session vocabulary.

## Current Phase Note
The flagship rebuild now has one shared SmartFill entry seam across both launch origins:
- `ProjectDetailView` bypasses the legacy `SmartFillSettingsModal` on the review/player sheet path.
- `LightweightEditorViewController+ModularWiring` now launches the same rebuild workspace from the editor-side SmartFill affordance.
- `EditorCoordinator` routes `.smartFillRequested` back through the shared rebuild workspace entry instead of the legacy controller-owned path.
- The legacy editor-only SmartFill files (`SmartFillSettingsModal`, `SmartFillRealPreviewSectionHandoff`, `SmartFillController`) are now deleted from the writable rebuild repo because no live launch path still uses them.
- `SmartFillTakeBridge` now resolves canonical/original take truth for both review and editor launches and preserves variant settings when refining an existing SmartFill take.
- `SmartFillResultBridge` now adopts SmartFill output through repository truth and creates or refreshes one authoritative standalone SmartFill variant take.
- `SmartFillProcessingManager` completion notifications now preserve the queued take ID for review listeners while also carrying the adopted SmartFill take ID for reopen routing.
- The dormant settings-side SmartFill shells (`SmartFillSettingsView`, `SmartFillMigrationDashboard`, `SmartFillBatchProcessingView`) are now deleted; the only reusable settings surface that remains is the shared `SmartFillAdvancedSettingsView` housed under `Features/SmartFill/Rebuild`.
- One intentional flagship defaults surface now exists again at `Features/SmartFill/Rebuild/SmartFillDefaultsView.swift`, reached from `SettingsView`, so the future standalone utility can derive a lighter defaults screen from the rebuild namespace without reviving dashboard wrappers.
- The rebuild workspace now renders `SmartFillPreviewPlayer` against the current preview URL and drives refreshes with a shared `forceUpdateToken`, so the future standalone utility can reuse the same preview seam instead of building a separate utility-only preview layer.
- The rebuild workspace now exposes four explicit product decision lanes that the standalone utility can copy directly:
  - background look
  - subject framing
  - output
  - save/export behavior
- `SmartFillWorkspacePresentation` now centralizes human-readable copy for launch title, launch message, action title, output description, framing description, and save-lane messaging so the future utility can reuse the same product language while swapping project/session wording for hidden-session utility wording.
- `SmartFillSettingsContext` now preserves explicit `launchSource` and `returnTarget` truth across review/player, project-detail, and editor-origin entry, so the future standalone utility can keep the same context model while swapping those launch/return values to hidden-session utility equivalents.
- `SmartFillWorkspacePresentation` now emits stage-aware action copy (`Save and Return`, `Saving SmartFill...`, `Saved to ...`) and short return-target titles, which gives the future standalone utility a direct copy seam for import -> edit -> save -> share flow without project/session language leaking through.
- The rebuild workspace now groups shared presets into explicit user-facing background-look modes (`Natural`, `Balanced`, `Cinematic`), which the future standalone utility can reuse directly without exposing raw preset internals.
- The rebuild workspace now keeps blur, darken, and background-fill tuning inline in the main editor surface, so the future standalone utility can reuse the same direct-adjustment model instead of forcing a utility-only advanced-settings detour.
- Completed-state workspace actions now explicitly say `Return to ...` while the workspace auto-returns after a short visible success state, which maps directly onto the future utility’s `Save -> Share/History` finish state once project/session wording is removed.
- SmartFill progress notifications now carry take/session/project identity, so the flagship workspace can show live save progress without relying on shell-specific banners; the future standalone utility can reuse that same notification seam against its hidden static session.
- The workspace now lets users cancel auto-return with `Stay Here`, which later maps cleanly onto the utility app’s post-save `Stay in editor` vs `Share/History` decision point.
- The workspace now keeps the latest saved-result summary visible and marks the session dirty again when settings diverge from the last saved snapshot, which later maps directly onto the utility app’s `saved result` vs `unsaved changes` finish-state truth without requiring separate utility-only state machines.
- The rebuild workspace now offers shipped-style quick background fill presets (`Subtle`, `Default`, `Edge-to-edge`) over the same shared `backgroundScale` model, which later maps directly onto the utility app's quick-fill choices without exposing flagship-only shell language.
- The save lane now explains source-clip truth, SmartFill result adoption, and after-save return behavior before the user commits a render, which later becomes the utility app's `save/share/history` guidance once review/editor return targets are swapped for hidden-session destinations.
- The rebuild workspace now offers one-tap treatment-finish presets (`Soft`, `Balanced`, `Bold`) over the shared blur/darken engine, which later maps directly onto the utility app's look-finishing choices without forcing hidden-session users to start on raw sliders.
- The save lane now lets the user choose `Return` versus `Stay` before save, which later maps directly onto the utility app's `Stay in editor` versus `Share/History` finish state once flagship return-target language is replaced by hidden-session outcomes.
- Save/update action titles, save-lane explanation, and clean completed-state comparison guidance now all obey that chosen `Return` versus `Stay` behavior, which later gives the utility app one shared finish-state copy seam instead of separate hidden-session save wording.
- Repository-backed and notification-backed SmartFill result adoption now carry the concrete saved take label into workspace outcome summaries and completed-state guidance, which later gives the utility app one shared seam for naming the actual saved result instead of falling back to generic `SmartFill take` copy.

This means the future standalone utility already has a clearer derivation path:
1. import one clip
2. create or reuse a hidden static `SmartFillSessionContext`
3. open the same `SmartFillWorkspaceView`-style editor scene
4. re-enter the same workspace whether the user starts from import or a later refine/edit affordance
5. use a lightweight defaults screen derived from `SmartFillDefaultsView` to seed hidden-session settings
6. write result history/export data through a utility-local result bridge that mirrors repository adoption without project/session vocabulary

## Current Next Step
Decide the next intentional shared-workspace evolution after duplicate screens are gone, one rebuild-owned defaults entry exists, the workspace shows the real SmartFill preview, the main product decisions are exposed as explicit user-facing lanes, the save/return story reflects the real launch context, the common treatment controls live directly in the workspace, live save progress plus explicit stay-vs-return control are anchored, dirty-after-save truth stays honest, shipped-style quick fill presets are back, save-outcome messaging explains what changes before save, treatment-finish presets plus an explicit pre-save stay/return choice now exist inside the main workspace, save/update affordances now fully match the chosen finish behavior, and completed-state guidance now names the actual saved SmartFill take. The standalone utility can now derive from the rebuild workspace plus hidden static-session shell without carrying dormant settings/dashboard wrappers, a separate preview shell, utility-only product copy, fake return-target assumptions, a separate treatment-tuning shell, a utility-only save-progress layer, a fake completed state after unsaved changes, a utility-only explanation layer for save outcomes, a separate finish-state chooser, or generic fake result naming.
