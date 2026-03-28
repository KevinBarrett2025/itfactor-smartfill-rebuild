# SmartFill Standalone Derivation Ledger

Date: 2026-03-28
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
- Completed-state primary actions, pending auto-return messaging, and deferred-return guidance now also point at that exact saved result name when it exists, which later gives the utility app a direct `Open saved result` seam instead of a generic `Return` affordance after save.
- Completed-state primary actions now really reopen the adopted SmartFill result through an explicit follow-up route instead of only dismissing the workspace, which later gives the utility app a direct hidden-session `Open saved result` seam instead of a fake close-and-manually-find-it flow.
- Automatic `Return` now uses that same follow-up seam instead of dismissing generically, which later lets the utility app reuse one shared post-save auto-open rule instead of maintaining a separate hidden-session auto-close path.
- Reopened player/review and editor destinations now explicitly identify that reopened take as the SmartFill result the user just saved through `SmartFillReopenDestinationContext`, which later lets the utility app show the same `you are viewing the result you just saved` context after hidden-session reopen without inventing a separate success screen.
- Reopened player/review and editor destinations now also expose direct compare/open-source actions back to the original take through `SmartFillReopenDestinationContext`, which later lets the utility app offer one-tap `compare with original` behavior after hidden-session save instead of inventing a utility-only comparison controller or burying the original clip behind history navigation.
- The rebuild workspace now uses a fixed preview plus contextual tray/rail shell instead of a long vertical settings document, which later gives the utility app a scalable editing chrome for more SmartFill tools without reviving the old wordy card-stack shell.
- The rebuilt tray now uses compact tool groups and one-at-a-time fine tuning instead of leaving every slider open at once, which later lets the utility app keep more SmartFill controls on one screen without collapsing back into a wordy scrolling settings page.
- The rebuilt workspace now pushes denser controls into explicit secondary sheets while leaving quick chips inline, which later gives the utility app a cleaner “main tool rail plus drill-in sheets” model instead of a cramped all-in-one tray.
- The rebuilt workspace now also defines which controls truly earn inline persistence versus sheet-only drill-in, which later lets the utility app keep a simple editor chrome without guessing which advanced controls belong on the main surface.
- The rebuilt workspace preview now owns an active-tool focus deck with one context-aware drill-in action, which later lets the utility app keep the editor feeling immediate without reviving a separate status strip or explanatory chrome row.
- The rebuilt workspace preview now also uses `SmartFillPreviewView` for live play/pause and scrub transport, which later lets the utility app inherit a professional live-preview surface without building a separate utility-only playback shell.
- The rebuilt workspace preview now also exposes an `Original` compare affordance plus a dedicated scrubbable source-preview sheet, which later lets the utility app offer one-tap compare-with-original behavior inside the same editor scene instead of forcing a separate history/reopen path.
- The rebuilt workspace preview now also switches inline between `Current` and `Source` states directly from the preview chips, and the larger original viewer reuses the same stronger live transport model, which later lets the utility app keep one consistent preview/compare language instead of a mixed inline preview plus weaker modal player.
- The rebuilt workspace preview now also keeps source and result playback synchronized through one shared preview-state seam, which later lets the utility app preserve scrub position and play/pause intent when users toggle between original and SmartFill result instead of resetting compare every time.
- The HomeScreen portrait-player SmartFill chip now also routes through the same rebuild request/edit seam as project detail, which later lets the utility app treat every visible SmartFill chip as a real workspace launch path instead of a placeholder affordance with no handler behind it.
- The rebuilt workspace preview now also embeds its playback transport directly into the preview canvas with tap-to-play/pause, a centered paused-state affordance, and resume-after-scrub behavior, which later lets the utility app inherit a more professional canvas-first playback feel without adding another layer of chrome under the player.
- The rebuilt workspace preview now also supports momentary hold-to-compare directly on the canvas, which later lets the utility app offer fast original-vs-result peeking without adding another persistent compare row or separate compare controller.
- The rebuilt workspace preview transport now also supports deterministic frame-step nudging derived from real track timing when available and a 30 fps fallback otherwise, which later lets the utility app offer precise preview inspection in the same compact canvas transport instead of inventing a second utility-only trim or seek row.
- The rebuilt workspace preview now also supports bounded horizontal precision scrubbing directly on the canvas with a temporary HUD and preserved play/resume intent, which later lets the utility app offer more professional direct-seek behavior without expanding the chrome or adding a second playback strip.
- The rebuilt workspace compare sheet now also behaves like a true source-versus-current viewer at the same shared playhead, while the inline preview goes inactive underneath it, which later lets the utility app reuse one coherent compare system instead of shipping a disconnected source-only drill-in player.
- The rebuilt workspace compare sheet now also supports a temporary split-wipe gesture with one ephemeral divider, which later lets the utility app offer fast A/B judgment inside the larger compare viewer without adding a permanent compare bar or a utility-only extra mode row.
- The rebuilt workspace compare sheet now also uses one compact explicit `Source` / `Current` / `Wipe` toolbar with a pinned wipe mode and dominant-side reference pills, which later lets the utility app keep one professional permanent compare control when needed without regressing into oversized chips, verbose compare copy, or a separate compare dashboard.
- The rebuilt workspace compare sheet now also remembers the user's last compare mode and pinned wipe divider position within the active workspace session, which later lets the utility app reopen comparison where the user left it without inventing a second compare-history layer or a separate modal state machine.
- The rebuilt workspace preview focus deck now also exposes one compact `Compare` launcher chip that mirrors the remembered dominant compare mode and opens the larger compare viewer directly from the pinned preview, which later gives the utility app one permanent compare entry point without adding another compare row or a utility-only compare toolbar.
- The rebuilt workspace preview now also groups `Source`, `Current`, and large-viewer compare entry into one compact compare control, which later gives the utility app a tighter preview-side compare toolbar seam instead of three separate compare pills competing for the same chrome.

This means the future standalone utility already has a clearer derivation path:
1. import one clip
2. create or reuse a hidden static `SmartFillSessionContext`
3. open the same `SmartFillWorkspaceView`-style editor scene
4. re-enter the same workspace whether the user starts from import or a later refine/edit affordance
5. use a lightweight defaults screen derived from `SmartFillDefaultsView` to seed hidden-session settings
6. write result history/export data through a utility-local result bridge that mirrors repository adoption without project/session vocabulary
7. route completed-state primary actions through the same follow-up seam so standalone users can reopen the result they just saved without recreating a second post-save controller
8. route automatic finish behavior through that same seam so standalone users get the same result-aware auto-open behavior without a utility-only auto-close branch
9. surface a direct `compare with original` or `open original clip` action in the reopened utility destination whenever hidden-session lineage still knows the source clip

## Current Next Step
Decide the next intentional shared-workspace evolution after duplicate screens are gone, one rebuild-owned defaults entry exists, the workspace shows the real SmartFill preview, the main product decisions are exposed as explicit user-facing lanes, the save/return story reflects the real launch context, the common treatment controls live directly in the workspace, live save progress plus explicit stay-vs-return control are anchored, dirty-after-save truth stays honest, shipped-style quick fill presets are back, save-outcome messaging explains what changes before save, treatment-finish presets plus an explicit pre-save stay/return choice now exist inside the main workspace, save/update affordances now fully match the chosen finish behavior, completed-state guidance now names the actual saved SmartFill take, both the post-save primary action and the automatic return path now reopen that same saved result through a shared follow-up route, the reopened destinations themselves now explicitly identify that result as the saved SmartFill output, the workspace chrome now scales through a fixed preview plus contextual tray/rail shell, the active tray now uses compact quick groups with one-at-a-time fine tuning, denser controls now route through explicit secondary sheets, inline ownership is now explicit for the highest-frequency editing decisions, the preview now carries the active tool’s current values plus one relevant drill-in action, the pinned preview now supports live play/pause and scrub transport, that live transport now also stays embedded directly inside the preview canvas instead of sitting in a disconnected slab, the workspace now exposes an original-source compare sheet directly beside that live preview, the main preview now switches inline between result and original states with the same stronger transport language in both places, that source/result compare now preserves shared playback state instead of resetting on every toggle, the preview now also supports momentary hold-to-compare directly on the canvas, the preview transport now also supports precise frame-step nudging, the preview canvas now also supports bounded horizontal precision scrubbing with a temporary HUD, the larger compare sheet now behaves like a true source-versus-current viewer at the same shared playhead, the larger compare sheet now also supports a temporary split-wipe gesture with one ephemeral divider, the compare sheet now also uses one compact explicit `Source` / `Current` / `Wipe` toolbar, the compare sheet now also remembers the last compare mode and pinned wipe position within the active workspace session, the preview focus deck now also exposes one grouped compare control that mirrors that remembered compare state, and the HomeScreen portrait-player SmartFill chip now enters the same rebuild workspace seam instead of dying at the player boundary. The standalone utility can now derive from the rebuild workspace plus hidden static-session shell without carrying dormant settings/dashboard wrappers, a separate preview shell, utility-only product copy, fake return-target assumptions, a separate treatment-tuning shell, a utility-only save-progress layer, a fake completed state after unsaved changes, a utility-only explanation layer for save outcomes, a separate finish-state chooser, generic fake result naming, a utility-only auto-close path, a generic post-save `Return` action that hides the real saved result identity, a silent reopen destination that gives no saved-result context, a long utility-only settings page that collapses as new SmartFill tools are added, a placeholder SmartFill chip that resolves an intent but has no live launch seam, or a compare flow that loses scrub/play context whenever users switch between original and result. The next shared candidate after this grouped preview-side compare-control slice lands is deciding whether the pinned preview itself needs richer inline compare-state behavior or whether compare speed is now better served by deeper live-state fluency inside the existing preview surface.
