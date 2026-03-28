# CODEX Thread Continuity

## Ticket 050 Restore Portrait Preview Visibility And Clarify Studio Tool Ownership (2026-03-28)
- Thread Status: phase-50 is locally gated on a fresh GM worktree from anchored phase-49; the SmartFill workspace now preserves a visible poster frame for portrait preview at rest, uses clearer `Background` ownership instead of the vaguer `Look` label, and turns the advanced legacy sheet into a smaller studio-themed adjustments surface without regressing back into scroll-heavy settings chrome.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase50`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase50`
- Working Head SHA: `647e0d43f5d7fe1861aa4016641f46988778f948`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
1. make the SmartFill preview surface visibly present portrait media at rest instead of reading as a black player until playback begins
2. clarify the tool architecture so users can immediately understand where background versus subject controls live
3. reduce reliance on the legacy advanced-look sheet by making its studio ownership clearer and smaller
4. keep the workspace canvas-first and fixed-shell instead of growing back into stacked cards or long scrollviews

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase50`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase50`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase50`
  - `git rev-parse HEAD` -> `647e0d43f5d7fe1861aa4016641f46988778f948`
  - `git status --porcelain` -> clean before phase-50 edits
  - `git log -1 --oneline` -> `647e0d4 SF-REBUILD-049: harden SmartFill preview ownership and simplify studio chrome`
- Truth-sync confirmed:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Completed This Pass
- `SmartFillWorkspaceView` now captures and overlays poster frames for both result and source preview surfaces so a portrait take is visibly present before playback begins instead of reading like an empty black player.
- Background tool ownership is now clearer in the fixed-shell chrome: the active tool short title now reads `Background`, the preview focus chip mirrors that ownership, and the drill-in action is now labeled `Adjust` instead of the vaguer `Fine tune`.
- `SmartFillAdvancedSettingsView` now uses the cinematic `studioLobbyV1` shell with compact cards and explicit studio adjustment sections instead of the legacy pop-brand list surface.

### Validation
- Gate A command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase50/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase50_gateA build | tee /tmp/itfactor_smartfill_phase50_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase50_gateA.log`
- Focused parity command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase50/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase50_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test-without-building | tee /tmp/itfactor_smartfill_phase50_tests_twb.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase50_tests_twb.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase50_tests/Logs/Test/Test-STSiPhone-2026.03.28_18-51-43--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Anchor `SF-REBUILD-050` on `gm/smartfill-itfactor-phase50`.
2. Use the anchored phase-50 branch as the next safe device-test baseline because it restores a visible portrait preview-at-rest seam and clarifies background-versus-subject ownership without reopening the long-scroll chrome.
3. After the next device smoke, tighten the studio shell further by reducing the remaining stacked-card feel and promoting compact background/subject controls where product evidence proves they should live inline.

## Ticket 049 Harden SmartFill Preview Ownership And Simplify Studio Chrome (2026-03-28)
- Thread Status: phase-49 is locally gated on a fresh GM worktree from anchored phase-48, the SmartFill preview wrapper now avoids every explicit `AVPlayerItem` handoff when a unified preview `AVPlayer` already exists, duplicate bottom workspace actions are removed, and the rebuild workspace now uses the studio lobby theme instead of the pop-brand shell.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase49`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase49`
- Working Head SHA: `e4abb1eb50566667746cc41c377517777f3f4cd2`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Harden the SmartFill workspace after the second device crash report in `smartfill logs2.md` and clean up the obvious workspace chrome debt:
1. remove the remaining explicit `AVPlayerItem` reuse seam by making `ModernSmartFillPlayer` wrap an existing unified preview `AVPlayer` directly
2. preserve the fresh-item construction path for source-only preview surfaces that intentionally build a new `AVPlayerItem(url:)`
3. remove the duplicate bottom `Cancel` / `Save and Return` bar so the top toolbar is the only primary action owner
4. shift `SmartFillWorkspaceView` from the pop-brand shell to the existing `studioLobbyV1` cinematic theme and shorten the header title so device chrome does not truncate the workspace identity

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase49`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase49`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase49`
  - `git rev-parse HEAD` -> `e4abb1eb50566667746cc41c377517777f3f4cd2`
  - `git status --porcelain` -> clean before phase-49 edits
  - `git log -1 --oneline` -> `e4abb1e SF-REBUILD-048: stop the SmartFill preview AVPlayerItem reuse crash`
- Truth-sync confirmed:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Completed This Pass
- `SmartFillManager.createPreviewPlayer(...)` now returns `ModernSmartFillPlayer(player: avPlayer)` directly, so the unified SmartFill preview player remains authoritative instead of handing its item back into a second player wrapper.
- `ModernSmartFillPlayer` now uses `player.currentItem` for readiness, duration, and end-of-playback observation instead of storing a second `playerItem` copy for wrapped preview sessions.
- `SmartFillWorkspaceView` now removes the duplicate bottom action bar and relies on the top toolbar as the primary close/save seam.
- The workspace now uses `STSThemeLibrary.theme(for: .studioLobbyV1)` for its background, chrome, panel, and accent colors, and `SmartFillWorkspacePresentation.headerTitle(for:)` now shortens long required/fine-tune titles into stable toolbar-safe labels.

### Validation
- Gate A command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase49/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase49_gateA build | tee /tmp/itfactor_smartfill_phase49_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase49_gateA.log`
- Focused parity command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase49/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase49_tests_rerun -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase49_tests_rerun.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase49_tests_rerun.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase49_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.28_18-09-58--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Anchor `SF-REBUILD-049` on `gm/smartfill-itfactor-phase49`.
2. Use the anchored phase-49 branch as the next safe device-test baseline because it hardens preview ownership beyond phase 48 and removes the duplicate bottom action bar while shifting the workspace toward the cinematic studio shell.
3. After the next device smoke, return to tightening the professional live-preview feel only where it improves the canvas-first editor without growing the chrome again.

## Ticket 048 Stop SmartFill Preview AVPlayerItem Reuse Crash (2026-03-28)
- Thread Status: phase-48 is locally gated on a fresh GM worktree from anchored phase-47, the SmartFill preview wrapper no longer tries to create a second `AVPlayer` around an `AVPlayerItem` that already belongs to the unified preview player, and this slice is ready to anchor as `SF-REBUILD-048`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase48`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase48`
- Working Head SHA: `3aff1c90153475b09b61e32a09a7d1527c1bd21d`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Stop the concrete SmartFill device crash reported in `smartfill logs1.md`:
1. fix the preview seam so the unified preview `AVPlayer` stays authoritative instead of re-wrapping its `currentItem` into a second `AVPlayer`
2. preserve the existing local preview-player construction path that creates a fresh `AVPlayerItem(url:)` for standalone source-only preview surfaces
3. add focused test coverage proving the wrapped `ModernSmartFillPlayer` preserves the original `AVPlayer` instance
4. make `SF-REBUILD-048` the next safe device-smoke baseline before returning to further workspace chrome refinement

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase48`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase48`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase48`
  - `git rev-parse HEAD` -> `3aff1c90153475b09b61e32a09a7d1527c1bd21d`
  - `git status --porcelain` -> clean before phase-48 edits
  - `git log -1 --oneline` -> `3aff1c9 SF-REBUILD-047: share compare state across pinned and drill-in preview`
- Truth-sync confirmed:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Completed This Pass
- `SmartFillManager.createPreviewPlayer(...)` now preserves the `AVPlayer` created by `SmartFillUnifiedInterface` instead of extracting its `currentItem` and attaching that item to a second player.
- `ModernSmartFillPlayer` now supports wrapping an already-created `AVPlayer` while still keeping the original `playerItem` for readiness, duration, and end-of-playback observation.
- Focused parity now includes a direct test that the wrapped preview player preserves the supplied `AVPlayer` instance instead of creating a second owner for the same item.

### Validation
- Gate A command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase48/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase48_gateA_rerun build | tee /tmp/itfactor_smartfill_phase48_gateA_rerun.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase48_gateA_rerun.log`
- Focused parity command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase48/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase48_tests_rerun -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase48_tests_rerun.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase48_tests_rerun.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase48_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.28_17-40-49--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Anchor `SF-REBUILD-048` on `gm/smartfill-itfactor-phase48`.
2. Use the anchored phase-48 branch as the next safe device-test baseline because it specifically removes the concrete SmartFill preview crash seen when opening the workspace on device.
3. After that device smoke, decide whether the next workspace slice should return to compare/playback fluency or address the oversize/duplicated chrome shown in the latest screenshot.

## Ticket 047 Shared Compare State Across Pinned And Drill-In Preview (2026-03-28)
- Thread Status: phase-47 is locally gated on a fresh GM worktree from the anchored phase-46 baseline, the pinned preview and larger compare viewer now share one compare-selection seam directly, and this slice is ready to anchor as `SF-REBUILD-047`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase47`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase47`
- Working Head SHA: `cd65028da7ce50fed58cb1b352ffdf271bf4e368`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Stabilize compare/playback ownership between the pinned preview and the larger compare viewer:
1. remove the extra viewer-memory shadow state so both compare surfaces share one compare-selection truth
2. preserve the same dominant compare mode and pinned wipe divider when users move between the pinned preview and the drill-in viewer
3. clear only transient hold-compare state when the drill-in viewer closes instead of copying compare state back after the fact
4. keep the editor canvas-first and avoid adding more bars, trays, or scroll-heavy chrome while improving the next device-test readiness

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase47`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase47`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase47`
  - `git rev-parse HEAD` -> `cd65028da7ce50fed58cb1b352ffdf271bf4e368`
  - `git status --porcelain` -> clean before phase-47 edits
  - `git log -1 --oneline` -> `cd65028 SF-REBUILD-046: add inline pinned-preview wipe compare mode`
- Truth-sync confirmed:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Completed This Pass
- `SmartFillWorkspaceView` no longer shadow-copies compare mode through a separate compare-viewer memory object.
- The pinned preview and the larger compare viewer now bind to the same compare-selection and pinned-divider state directly.
- Closing the larger compare viewer now only clears transient hold-compare state instead of copying mode back after the fact.
- The focused parity suite now reflects the simpler shared-state seam by removing the obsolete compare-viewer-memory tests.

### Validation
- Gate A command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase47/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase47_gateA build | tee /tmp/itfactor_smartfill_phase47_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase47_gateA.log`
- Focused parity command:
  - `xcodebuild -project /tmp/itfactor_smartfill_phase47/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase47_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase47_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase47_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase47_tests/Logs/Test/Test-STSiPhone-2026.03.28_16-11-40--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Anchor `SF-REBUILD-047` on `gm/smartfill-itfactor-phase47`.
2. Use the anchored phase-47 branch as the next safe device-test baseline.
3. Only after that device smoke, decide whether the next preview slice should deepen playback fluency or compare precision.

## Ticket 046 SmartFill Pinned Preview Inline Wipe Compare Mode (2026-03-28)
- Thread Status: phase-46 local patch is restored on a fresh GM worktree after the restart wipe, Gate A and focused parity now pass cleanly again, and the slice is ready to anchor as `SF-REBUILD-046`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase46`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase46`
- Working Head SHA: `07be7e1030e7bad9cd939d590c78dae12b7845b3`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the pinned preview into a more studio-grade compare surface without adding another bar or falling back to a settings document:
1. turn the pinned preview compare group into explicit inline `Source`, `Current`, and `Wipe` modes
2. keep the larger compare viewer as a separate drill-in instead of overloading the inline group
3. let pinned `Wipe` stay active directly on the main preview with a draggable divider
4. keep playback/hold-compare behavior safe by disabling conflicting interactions while pinned wipe is active

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase46`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase46`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase46`
  - `git rev-parse HEAD` -> `07be7e1030e7bad9cd939d590c78dae12b7845b3`
  - `git status --porcelain` -> clean immediately after recreating the wiped worktree
  - `git log -1 --oneline` -> `07be7e1 SF-REBUILD-045: group the pinned preview compare controls into one compact toolbar seam`
- Truth-sync confirmed:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now owns separate inline preview state for the pinned preview, so the main canvas can switch between `Source`, `Current`, and a pinned `Wipe` compare mode without always opening the larger compare viewer.
2. The larger compare viewer remains the drill-in surface, but closing it now synchronizes its remembered mode back to the pinned preview so both compare surfaces stay consistent.
3. Gate A PASS: `/tmp/itfactor_smartfill_phase46_gateA_rerun.log`
4. Focused parity PASS: `/tmp/itfactor_smartfill_phase46_tests_rerun.log`
5. xcresult: `/tmp/itfactor_smartfill_phase46_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.28_15-57-54--0400.xcresult`

## Ticket 045 SmartFill Pinned Preview Grouped Compare Control (2026-03-28)
- Thread Status: phase-45 local patch landed on a fresh GM worktree, Gate A and focused parity both pass cleanly, and the grouped compare-control slice is ready to anchor as `SF-REBUILD-045`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase45`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase45`
- Working Head SHA: `6cb7711f6cb63fa13a5a269fbd5e31ff9d242c07`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Make the pinned preview feel more like a studio-grade grouped toolbar and less like a row of large independent chips:
1. replace the separate `Source`, `Current`, and `Compare` preview-side chips with one compact grouped compare control
2. keep fast inline switching between `Source` and `Current` on the pinned preview
3. preserve a direct launch into the larger compare viewer without adding another toolbar row, tray, or scroll-heavy surface
4. prove the grouped control state mapping in focused parity so future flagship, standalone, and macOS derivation can reuse the same compare-entry seam

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase45`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase45`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase45`
  - `git rev-parse HEAD` -> `6cb7711f6cb63fa13a5a269fbd5e31ff9d242c07`
  - `git status --porcelain` -> clean before phase-45 edits
  - `git log -1 --oneline` -> `6cb7711 SF-REBUILD-044: add a compact compare affordance beside the pinned preview`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase45 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now collapses the pinned-preview compare affordance into one grouped control that owns `Source`, `Current`, and large-viewer compare entry without growing another permanent row of chrome.
2. That grouped control keeps the current fast source/result switching behavior while tightening the preview deck into something closer to a professional editor toolbar.
3. Focused parity now locks the grouped compare-mode mapping directly so the fixed-shell SmartFill workspace stays scalable as more flagship and standalone features arrive.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase45_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase45_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase45_tests/Logs/Test/Test-STSiPhone-2026.03.28_13-40-48--0400.xcresult`

## Ticket 044 SmartFill Pinned Preview Compare Launcher (2026-03-28)
- Thread Status: phase-44 local patch landed on a fresh GM worktree, Gate A and focused parity both pass cleanly, and the slice is ready to anchor as `SF-REBUILD-044`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase44`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase44`
- Working Head SHA: `46577f95ba7c656b5875b47199b9d5c3aed1a9e7`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen compare speed without bloating the fixed-shell editor:
1. add one compact preview-side `Compare` launcher chip beside the pinned preview so users can jump straight into the larger compare viewer from the same focus deck that already surfaces active tool state
2. make that launcher always reflect the remembered compare mode (`Source`, `Current`, or `Wipe`) so the preview tells the truth about the dominant compare state before the sheet opens
3. keep compare entry inside the existing horizontal focus deck instead of introducing another compare bar, tray row, or stacked settings slab
4. prove the remembered compare-control mapping directly in focused parity so future standalone derivation can reuse the same compact permanent compare entry

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase44`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase44`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase44`
  - `git rev-parse HEAD` -> `46577f95ba7c656b5875b47199b9d5c3aed1a9e7`
  - `git status --porcelain` -> two local phase-44 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `46577f9 SF-REBUILD-043: preserve last compare mode across viewer reopen`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase43 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now adds one compact preview-side `Compare` launcher chip inside the existing focus deck, so the pinned preview itself exposes a permanent compare entry without growing a second compare row or reviving a scroll-heavy settings shell.
2. That launcher now reflects the remembered compare mode from `SmartFillWorkspaceCompareViewerMemoryState`, surfacing `Source`, `Current`, or `Wipe` with the matching symbol before the larger compare viewer opens.
3. Focused parity now locks the preview-side compare-control mapping directly, so future flagship and standalone compare-entry work can reuse the same compact permanent launcher seam instead of inventing a second compare toolbar.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase44_gateA_final.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase44_tests_final.log`
6. xcresult: `/tmp/itfactor_smartfill_phase44_tests_final/Logs/Test/Test-STSiPhone-2026.03.28_13-17-36--0400.xcresult`
7. Next best slice after this preview-side compare-entry pass: decide whether the pinned preview itself should gain a more explicit inline compare-state behavior or whether compare speed is now strong enough that the next work should stay on playback fluency and editor feel.

## Ticket 043 SmartFill Compare Viewer Last-Mode Memory (2026-03-28)
- Thread Status: phase-43 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-043`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase43`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase43`
- Working Head SHA: `385d40f3a114617240040d14966d63ef31e2c440`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional compare experience without adding more chrome:
1. keep the larger compare viewer on the user's last chosen compare mode when the sheet closes and reopens
2. preserve the pinned wipe divider position when the user intentionally leaves the compare viewer in `Wipe` mode
3. reset that memory only when a brand-new SmartFill workspace session starts so compare work remains fast inside one editing session
4. prove the remembered compare-state seam directly in focused parity so future standalone derivation can reuse the same behavior

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase43`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase43`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase43`
  - `git rev-parse HEAD` -> `385d40f3a114617240040d14966d63ef31e2c440`
  - `git status --porcelain` -> two local phase-43 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `385d40f SF-REBUILD-042: compact the compare viewer into an explicit mode toolbar`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase42 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now owns one explicit compare-viewer memory seam, so closing and reopening the larger compare sheet restores the user's last `Source`, `Current`, or pinned `Wipe` state instead of snapping back to the default compare mode.
2. The pinned wipe divider position now survives sheet reopen within the same SmartFill workspace session, while a brand-new workspace session still resets the compare memory to a clean default.
3. Focused parity now locks that remembered compare-state seam directly so future workspace and standalone derivation work can reuse it without drifting back into ephemeral sheet-local state.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase43_gateA_rerun.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase43_tests_rerun.log`
6. xcresult: `/tmp/itfactor_smartfill_phase43_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.28_12-49-42--0400.xcresult`
7. Next best slice after this compare-memory pass: decide whether the pinned preview itself needs one equally compact compare affordance or whether compare speed is now better served by richer live-state behavior inside the existing preview surface.

## Ticket 042 SmartFill Compare Viewer Explicit Mode Toolbar (2026-03-28)
- Thread Status: phase-42 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-042`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase42`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase42`
- Working Head SHA: `c30e2982116e6fab9f1eab59d08c84354cbd2f8f`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional compare experience without falling back to oversized chips or extra bars:
1. replace the larger compare viewer's oversized `Source` / `Current` chips with one compact grouped compare toolbar
2. make `Source`, `Current`, and `Wipe` explicit compare modes so advanced compare behavior is visible instead of gesture-only
3. let `Wipe` become a deliberate pinned mode with one draggable divider while preserving the temporary long-press wipe for quick peeks
4. prove the toolbar selection-state rules directly in focused parity so the compare viewer can grow without drifting back into wordy or ambiguous controls

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase42`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase42`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase42`
  - `git rev-parse HEAD` -> `c30e2982116e6fab9f1eab59d08c84354cbd2f8f`
  - `git status --porcelain` -> two local phase-42 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `c30e298 SF-REBUILD-041: add a temporary split-wipe compare gesture inside the larger viewer`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase41 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceCompareViewer` now replaces the oversized compare chips with one compact grouped toolbar that exposes explicit `Source`, `Current`, and `Wipe` modes at the top of the larger compare viewer.
2. `Wipe` can now stay pinned as a deliberate compare mode with one draggable divider, while the temporary long-press wipe still exists for quick momentary comparison without growing the main workspace chrome.
3. Compact reference pills now mirror the dominant compare side, and focused parity locks the toolbar-selection rules so the viewer keeps one studio-grade compare language instead of drifting back into ambiguous chip states.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase42_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase42_tests_rerun.log`
6. xcresult: `/tmp/itfactor_smartfill_phase42_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.28_12-22-13--0400.xcresult`
7. Next best slice after this explicit-mode toolbar pass: decide whether the compare system should remember and reopen on the user's last dominant mode or expose one equally compact compare affordance beside the pinned preview, but only if the fixed-shell chrome stays tight.

## Ticket 041 SmartFill Compare Viewer Split-Wipe Gesture (2026-03-28)
- Thread Status: phase-41 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-041`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase41`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase41`
- Working Head SHA: `c9d8d27fa906fa695149e08d46bd11439090ac4e`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional compare experience without growing the chrome again:
1. let the larger compare viewer support a temporary split-wipe inspection gesture instead of only full-source or full-result switching
2. keep that wipe entirely inside the large compare viewer so the main workspace chrome stays unchanged
3. pause the shared compare playback during the wipe and restore the ordinary compare state as soon as the gesture ends
4. prove the wipe-progress clamp rules directly in focused parity so the gesture remains deterministic as compare work continues

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase41`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase41`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase41`
  - `git rev-parse HEAD` -> `c9d8d27fa906fa695149e08d46bd11439090ac4e`
  - `git status --porcelain` -> two local phase-41 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `c9d8d27 SF-REBUILD-040: turn the larger source sheet into a true compare viewer`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase40 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceCompareViewer` now supports a long-press-and-drag split-wipe gesture inside the larger compare sheet, so users can temporarily reveal `Source` on the left and `Current` on the right without adding any permanent compare chrome.
2. The split-wipe temporarily pauses the shared compare playback state, shows one ephemeral divider plus `Source`/`Current` edge badges, and disappears immediately when the gesture ends.
3. `SmartFillWorkspaceCompareWipeState` now locks wipe-progress clamping and center-default behavior so the compare gesture stays bounded even when the viewer width is invalid or the drag leaves the viewer edges.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase41_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase41_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase41_tests/Logs/Test/Test-STSiPhone-2026.03.28_11-26-57--0400.xcresult`
7. Next best slice after this split-wipe pass: evaluate whether the larger compare viewer should remember and reopen to the user’s last dominant side, but only if that improves compare speed without adding any new permanent controls.

## Ticket 040 SmartFill True Compare Viewer Sheet (2026-03-28)
- Thread Status: phase-40 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-040`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase40`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase40`
- Working Head SHA: `457dab768b2aea99123a44bad4dacd31e575b49f`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional compare experience without growing the chrome again:
1. turn the larger `Original` sheet into a true source-vs-result compare viewer instead of a disconnected source-only player
2. keep source and result on the same shared playhead so A/B inspection feels intentional and editor-grade
3. deactivate the inline pinned preview while the larger compare viewer is open so there is only one active playback surface at a time
4. prove the compare-viewer language and shared-playhead rules directly in focused parity so future compare work does not drift back into duplicate preview behavior

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase40`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase40`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase40`
  - `git rev-parse HEAD` -> `457dab768b2aea99123a44bad4dacd31e575b49f`
  - `git status --porcelain` -> two local phase-40 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `457dab7 SF-REBUILD-039: add precision scrub gestures to the live preview canvas`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase40 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now routes `.sourcePreview` through one `SmartFillWorkspaceCompareViewer`, so the larger compare sheet can switch between `Source` and `Current` while reusing the shared playback state and the existing hold-to-compare behavior.
2. The pinned preview now goes inactive whenever that compare sheet is open, so the larger viewer owns the active playback session instead of competing with the canvas underneath it.
3. `SmartFillWorkspacePresentation.compareViewerMessage(...)` now names the larger compare viewer explicitly and keeps adopted-take naming honest when a saved SmartFill result already exists.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase40_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase40_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase40_tests/Logs/Test/Test-STSiPhone-2026.03.28_09-08-40--0400.xcresult`
7. Next best slice after this compare-viewer pass: evaluate a temporary split-wipe or similarly precise compare-only gesture inside the larger viewer, but only if it improves A/B judgment without adding any permanent chrome to the workspace.

## Ticket 039 SmartFill Canvas Precision Scrubbing (2026-03-27)
- Thread Status: phase-39 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-039`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase39`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase39`
- Working Head SHA: `2736bb79c11ef08d902a2b44940e72bdae626283`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional live-preview feel without growing the chrome again:
1. add horizontal precision scrubbing directly on the pinned preview canvas instead of creating another visible transport row
2. preserve the shared play/pause intent while dragging so the canvas resumes only when the preview had been actively playing
3. keep scrub feedback attached to the preview itself through a temporary HUD instead of adding another permanent compare or transport slab
4. prove the bounded seek-span, clamp, and resume-intent rules directly in focused parity so future live-preview work does not make scrubbing jumpy or unstable

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase39`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase39`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase39`
  - `git rev-parse HEAD` -> `2736bb79c11ef08d902a2b44940e72bdae626283`
  - `git status --porcelain` -> two local phase-39 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `2736bb7 SF-REBUILD-038: add frame-step nudging to the live preview transport`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase39 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now defines one `SmartFillWorkspacePreviewCanvasScrubState` helper so canvas dragging uses a bounded precision seek span, clamps target times inside the clip duration, and preserves resume intent when the preview was already playing.
2. The interactive preview surface now captures horizontal drags directly on the canvas, pauses into a temporary scrub state, seeks continuously while the user drags, and restores playback only when the active session had been playing before the scrub began.
3. The canvas now renders a temporary `Scrub Preview` HUD with a monospaced time readout, so precise scrubbing feedback stays attached to the pinned preview instead of spawning another transport row or expanding the tray chrome.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase39_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase39_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase39_tests/Logs/Test/Test-STSiPhone-2026.03.27_19-36-49--0400.xcresult`
7. Next best slice after this canvas-scrub pass: keep improving professional live-preview feel only where it sharpens preview/compare behavior without re-expanding the chrome.

## Ticket 038 SmartFill Live Preview Frame-Step Nudging (2026-03-27)
- Thread Status: phase-38 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-038`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase38`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase38`
- Working Head SHA: `af3f3413ac4e19a376de29e39db5b17c49268984`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen the professional live-preview feel without growing the chrome again:
1. add frame-step nudging to the existing preview transport capsule instead of creating a second transport row
2. make the nudge controls use the real source/result playback seam so both compare modes feel precise, not static
3. derive frame-step timing from the loaded video track when possible, with a safe 30 fps fallback when frame-rate metadata is missing
4. prove the frame-step math directly in focused parity so the transport stays deterministic as live preview work continues

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase38`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase38`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase38`
  - `git rev-parse HEAD` -> `af3f3413ac4e19a376de29e39db5b17c49268984`
  - `git status --porcelain` -> three local phase-38 edits in `SmartFillManager.swift`, `SmartFillPreviewView.swift`, and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `af3f341 SF-REBUILD-037: add hold-to-compare preview switching`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase38 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `ModernSmartFillPlayer` now derives one `frameStepSeconds` value from the loaded video track when possible and falls back to 30 fps when metadata is missing, so preview nudging is tied to real media timing instead of an arbitrary seek amount.
2. `SmartFillPreviewView` now adds inline frame-back and frame-forward actions inside the existing transport capsule, and both actions cancel active scrubbing state before stepping so the live preview remains coherent.
3. Focused parity now locks the frame-step timing helpers and clamp behavior so preview nudging stays stable as deeper live-preview polish continues.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase38_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase38_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase38_tests/Logs/Test/Test-STSiPhone-2026.03.27_18-56-06--0400.xcresult`
7. Next best slice after this transport pass: keep improving professional live-preview feel only where it sharpens preview/compare behavior without re-expanding the chrome.

## Ticket 037 SmartFill Hold-to-Compare Preview Switching (2026-03-27)
- Thread Status: phase-37 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-037`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase37`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase37`
- Working Head SHA: `37c290f11909e5b99f352d4ef28a1f9e16a5de17`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Sharpen compare behavior on the canvas-first preview without adding any new chrome:
1. let the pinned preview temporarily flip to the alternate source/result state while the user presses and holds on the canvas
2. keep the existing `Current` and `Source` chips as the persistent mode controls instead of adding another compare row
3. make the momentary compare behavior share the same live preview seam and playback-state model already used by the stronger source/result preview work
4. prove the new compare-state rules directly in focused parity instead of hiding the behavior inside view-only gesture code

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase37`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase37`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase37`
  - `git rev-parse HEAD` -> `37c290f11909e5b99f352d4ef28a1f9e16a5de17`
  - `git status --porcelain` -> two local phase-37 edits in `SmartFillWorkspaceView.swift` and `SmartFillRebuildBridgeTests.swift`
  - `git log -1 --oneline` -> `37c290f SF-REBUILD-036: embed live preview transport into the SmartFill canvas`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase37 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now computes one `SmartFillWorkspacePreviewCompareState` so the preview keeps its selected `Current` or `Source` mode when idle but temporarily flips to the alternate state during a press-and-hold compare gesture.
2. The interactive preview surface now emits compare pressing changes directly from the canvas, and both result/source preview branches consume the same callback without adding another chrome row.
3. Focused parity now locks the new compare-state helper so the hold-to-compare rules stay stable as deeper live preview work continues.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase37_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase37_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase37_tests/Logs/Test/Test-STSiPhone-2026.03.27_18-28-57--0400.xcresult`
7. Next best slice after this compare pass: keep improving the professional editor feel only where it sharpens live preview and source/result comparison without re-expanding the chrome.

## Ticket 036 SmartFill Canvas-Embedded Live Preview Transport (2026-03-27)
- Thread Status: phase-36 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-036`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase36`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase36`
- Working Head SHA: `3ed0e31ed75b63fc2b33145b3c5c8180fb987c21`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Make the SmartFill preview feel more like a professional editor surface without growing the chrome again:
1. embed the transport controls into the preview canvas instead of leaving them as a disconnected slab under the player
2. make scrubbing feel more deliberate by pausing on drag, seeking continuously, and resuming playback when appropriate
3. let the preview itself respond to playback intent with tap-to-play/pause and a centered play affordance when paused
4. keep the tray-and-rail architecture intact so this stays a canvas-first playback slice instead of another chrome expansion

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase36`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase36`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase36`
  - `git rev-parse HEAD` -> `3ed0e31ed75b63fc2b33145b3c5c8180fb987c21`
  - `git status --porcelain` -> two local phase-36 edits in `SmartFillPreviewView.swift` and `SmartFillWorkspaceView.swift`
  - `git log -1 --oneline` -> `3ed0e31 SF-REBUILD-035: route portrait player SmartFill chip to the real target`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase36 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillPreviewView` now uses one compact transport capsule with monospaced time labels, continuous seeking, and resume-after-scrub playback behavior instead of the older split transport rows.
2. `SmartFillWorkspaceView` now renders the SmartFill preview through one interactive preview surface that supports tap-to-play/pause, an inline paused-state play affordance, and transport controls pinned inside the preview canvas.
3. Focused parity still locks the shared preview playback-state helpers, so the new canvas-embedded transport behavior stays on the same tested live-preview seam.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase36_gateA.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase36_tests.log`
6. xcresult: `/tmp/itfactor_smartfill_phase36_tests/Logs/Test/Test-STSiPhone-2026.03.27_17-27-43--0400.xcresult`
7. Next best slice after this playback pass: keep improving the professional editor feel only when it sharpens preview/compare behavior without re-expanding the chrome again.

## Ticket 035 SmartFill Portrait-Player Chip Routing (2026-03-27)
- Thread Status: phase-35 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-035`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase35`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase35`
- Working Head SHA: `5796221f3df1c8be61479a08ff6e5026d09fe5af`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Close the dead portrait-player SmartFill chip path in the HomeScreen review/player flow:
1. route portrait-player SmartFill taps through the same rebuild workspace seam used by project detail
2. carry the needed session/project context through the HomeScreen handoff and swipeable player layers
3. make SmartFill request vs edit intent resolution actually land on the right rebuild context instead of logging `no handler is wired`
4. prove the new HomeScreen route helpers directly in focused parity

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase35`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase35`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase35`
  - `git rev-parse HEAD` -> `5796221f3df1c8be61479a08ff6e5026d09fe5af`
  - `git status --porcelain` -> local phase-35 edits only before commit
  - `git log -1 --oneline` -> `5796221 SF-REBUILD-034: synchronize source-result live preview states`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase35 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `HomeScreenView` now passes real `onSmartFillRequest` / `onSmartFillEditRequest` handlers into `SwipeableVideoPlayerView`, so portrait-player SmartFill taps no longer resolve an intent and then stall with `no handler is wired`.
2. `SwipeableMediaPlayerView` now carries the current session through the HomeScreen review/player handoff so SmartFill route building has the same project/session truth as the project-detail launch path.
3. Focused parity now locks the HomeScreen route helpers alongside the player entry resolver.
4. Gate A PASS: `/tmp/itfactor_smartfill_phase35_gateA_clean.log`
5. Focused parity PASS: `/tmp/itfactor_smartfill_phase35_tests_final3.log`
6. xcresult: `/tmp/itfactor_smartfill_phase35_tests_final3/Logs/Test/Test-STSiPhone-2026.03.27_15-50-28--0400.xcresult`
7. Next best slice after this chip-routing fix: keep improving the professional live-preview/editor feel without growing the chrome again, now that HomeScreen review/player can actually enter the rebuild workspace.

## Ticket 033 SmartFill Inline Preview Compare States (2026-03-27)
- Thread Status: phase-33 local patch landed on a fresh GM worktree, Gate A and focused parity both pass, and the slice is ready to anchor as `SF-REBUILD-033`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase33`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase33`
- Working Head SHA: `3c6788d4812f75ee6a988efc93a8e3847dac4ee8`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the compare experience around the pinned preview without adding new tray chrome:
1. let the main preview switch cleanly between the SmartFill result and the untouched original source
2. keep source/result state control adjacent to the preview instead of hiding comparison behind only a secondary sheet
3. preserve the deeper source-preview sheet as a larger drill-in viewer rather than the only way to inspect the original
4. make the original viewer feel more like the live preview transport instead of a weaker fallback player

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase33`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase33`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase33`
  - `git rev-parse HEAD` -> `3c6788d4812f75ee6a988efc93a8e3847dac4ee8`
  - `git status --porcelain` -> clean before local phase-33 edits
  - `git log -1 --oneline` -> `3c6788d SF-REBUILD-032: add preview-adjacent original/source comparison`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase32 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now switches the pinned preview between `Result` and `Original` states directly from the preview-adjacent source/result chips instead of forcing every original inspection through only a secondary sheet.
2. `SmartFillSourcePreviewView` now uses the stronger live-preview transport style so original inspection feels like part of the editor instead of a weaker fallback player.
3. Gate A PASS: `/tmp/itfactor_smartfill_phase33_gateA.log`
4. Focused parity PASS: `/tmp/itfactor_smartfill_phase33_tests.log`
5. xcresult: `/tmp/itfactor_smartfill_phase33_tests/Logs/Test/Test-STSiPhone-2026.03.27_11-09-29--0400.xcresult`
6. Next best slice after this compare pass: deepen live preview behavior only if it sharpens the editor feel without growing the chrome again.

## Ticket 032 SmartFill Workspace Source Compare Preview (2026-03-27)
- Thread Status: preview-adjacent original/source comparison landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is ready to anchor as `SF-REBUILD-032`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase32`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase32`
- Working Head SHA: `d4215ced8901742625362bb8c85aaf20eed4ad85`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the editor feel around the pinned preview without adding more tray chrome:
1. keep the live SmartFill preview as the dominant surface
2. add a preview-adjacent original/source compare affordance instead of forcing comparison to wait until reopen flow
3. keep the tray-and-rail shell intact while moving original-source inspection into one dedicated secondary sheet
4. preserve save/reopen routing so this stays one bounded preview-comparison slice

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase32`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase32`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase32`
  - `git rev-parse HEAD` -> `d4215ced8901742625362bb8c85aaf20eed4ad85`
  - `git status --porcelain` -> clean
  - `git log -1 --oneline` -> `d4215ce SF-REBUILD-031: restore live preview transport in workspace surface`
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase31 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now adds an `Original` compare affordance beside the live preview and surfaces source/result reference chips directly under the preview.
2. The new `sourcePreview` sheet uses live scrubbable transport for the untouched source clip, so users can compare the original take without leaving the workspace or reopening review/player first.
3. Gate A PASS: `/tmp/itfactor_smartfill_phase32_gateA.log`
4. Focused parity PASS: `/tmp/itfactor_smartfill_phase32_tests.log`
5. xcresult: `/tmp/itfactor_smartfill_phase32_tests/Logs/Test/Test-STSiPhone-2026.03.27_10-35-16--0400.xcresult`
6. Next best slice after this compare pass: decide whether the next preview-centered upgrade should be inline result-vs-source state switching or a tighter tool-specific live overlay, without re-expanding the tray chrome.

## Ticket 031 SmartFill Workspace Live Preview Transport (2026-03-27)
- Thread Status: live preview transport landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is ready to anchor as `SF-REBUILD-031`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase31`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase31`
- Working Head SHA: `f63db889e7f4c0af6861bf759dc65a5ea0c0aa86`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the editor feel around the pinned preview without adding more chrome:
1. keep the preview as the dominant editor surface
2. replace the passive preview wrapper with the existing live SmartFill preview transport that supports play/pause and scrubbing
3. preserve the preview-focus deck and tray architecture from `SF-REBUILD-030`
4. leave save/reopen routing unchanged so this remains one bounded playback-focused slice

### Preflight
- Thread continuity protocol confirmed in `/tmp/itfactor_smartfill_phase31`:
  - `git rev-parse --show-toplevel` -> `/private/tmp/itfactor_smartfill_phase31`
  - `git branch --show-current` -> `gm/smartfill-itfactor-phase31`
  - `git rev-parse HEAD` -> `f63db889e7f4c0af6861bf759dc65a5ea0c0aa86`
  - `git status --porcelain` -> clean
  - `git log -1 --oneline` -> `f63db88 SF-REBUILD-030: attach active tool focus to the preview surface`
- Truth-sync already confirmed before the fork:
  - `git -C /tmp/itfactor_smartfill_phase30 fetch origin --prune`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Next Action
1. `SmartFillWorkspaceView` now swaps the passive preview wrapper for `SmartFillPreviewView`, so the pinned workspace preview carries real play/pause and scrub transport without reopening the bottom tray.
2. The preview-focus deck stays attached to that live player, and the file/live indicators now sit above the player instead of overlaying transport controls.
3. Gate A PASS: `/tmp/itfactor_smartfill_phase31_gateA.log`
4. Focused parity PASS: `/tmp/itfactor_smartfill_phase31_tests.log`
5. xcresult: `/tmp/itfactor_smartfill_phase31_tests/Logs/Test/Test-STSiPhone-2026.03.27_10-09-37--0400.xcresult`
6. Next best slice after this transport pass: decide whether the next editor-feel upgrade should be inline compare/original-state treatment near the preview or a deeper live-state tool seam, without letting the workspace slide back into generic chrome.

## Ticket 030 SmartFill Workspace Preview-Focus Deck (2026-03-27)
- Thread Status: preview-attached tool focus landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is ready to anchor as `SF-REBUILD-030`.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Active Worktree Truth: `/tmp/itfactor_smartfill_phase30`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-phase30`
- Working Head SHA: `257ed2100e995d01aeceb7a24e310f49fd48f46f`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the editor feel around the preview and active tool:
1. remove the generic status strip that still reads like dashboard chrome
2. attach the active tool summary directly to the preview so the user sees the current look/output/save state where they are actually looking
3. keep one context-aware drill-in action near the preview instead of expanding the bottom tray again
4. preserve all existing save/reopen truth while making the preview and tool chrome feel like one editor surface

### Preflight
- Truth-sync confirmed:
  - `git -C /tmp/itfactor_smartfill_phase30 fetch origin --prune`
  - `HEAD`: `257ed2100e995d01aeceb7a24e310f49fd48f46f`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- `SF-REBUILD-029` is the clean local baseline for this preview-focus phase.
- Work continues in `/tmp/itfactor_smartfill_phase30` so the already-anchored phase-29 worktree stays untouched.

### Next Action
1. `SmartFillWorkspaceView` now replaces the generic horizontal status strip with a preview-attached focus deck that shows the active tool’s key values and one relevant drill-in action.
2. `SmartFillWorkspaceTool` now owns a small tested focus/drill-in seam so preview-adjacent inline ownership stays intentional as SmartFill adds more tools.
3. Gate A PASS: `/tmp/itfactor_smartfill_phase30_gateA.log`
4. Focused parity PASS: `/tmp/itfactor_smartfill_phase30_tests.log`
5. xcresult: `/tmp/itfactor_smartfill_phase30_tests/Logs/Test/Test-STSiPhone-2026.03.27_09-47-12--0400.xcresult`
6. Future candidate after chrome architecture stabilizes: evaluate a more professional live SmartFill preview with scrubbing/playhead control instead of only passive preview treatment.

## Ticket 029 SmartFill Workspace Inline Control Ownership (2026-03-27)
- Thread Status: inline-vs-sheet ownership landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is anchored as `SF-REBUILD-029`.

## Ticket 028 SmartFill Workspace Secondary Sheet Split (2026-03-27)
- Thread Status: tray-to-sheet split landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is anchored as `SF-REBUILD-028`.

## Ticket 027 SmartFill Workspace Density Pass (2026-03-27)
- Thread Status: density refactor landed on the clean GM branch, passed Gate A plus focused SmartFill parity, and is anchored as `SF-REBUILD-027`.

## Ticket 026 SmartFill Workspace Chrome Refactor (2026-03-27)
- Thread Status: chrome refactor landed in the clean GM worktree, passed Gate A and focused SmartFill parity, and was pushed on `gm/smartfill-itfactor-phase26`.

## Ticket 024 Source-Take Compare Actions In Reopened Destinations (2026-03-26)
- Thread Status: reopened player/review and editor destinations now expose direct compare/open-source actions back to the original source take when SmartFill lineage is known, local gating is green, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `6c0a3b23f7ffe7fcbb161ff44060888477f3715d`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Make reopened destinations support real result-versus-source comparison:
1. let project-review/player reopen destinations jump directly from the saved SmartFill result back to the original source take when lineage exists
2. let editor reopen destinations offer a direct `Open <source take>` comparison action instead of trapping the user on the saved result only
3. keep the saved-result/original-source relationship centralized in one shared destination-context seam instead of inventing separate comparison UI paths
4. keep standalone derivation aligned because the later hidden-session utility will need the same `open saved result` plus `compare to original source` finish seam after save

### Completed This Pass
- Truth-sync preflight confirmed:
  - `HEAD`: `6c0a3b23f7ffe7fcbb161ff44060888477f3715d`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Archaeology confirmed the remaining product gap after `SF-REBUILD-023`:
  - reopened destinations now named the saved SmartFill result correctly
  - neither player/review nor editor gave the user a direct way to compare the saved result against the original source take
  - the original-take lineage already existed in `SmartFillResultBridgeRecord.originalTakeID`, so the correct next move was to extend the destination-context seam instead of inventing another workspace completion surface
- `SmartFillReopenDestinationContext` now also carries original/source take identity and user-facing compare/open-source action titles for both player/review and editor destinations.
- `ProjectDetailView` now resolves the original source take alongside the adopted SmartFill take and passes that comparison truth into `SwipeableVideoPlayerData`.
- `SwipeableVideoPlayerView` now exposes a direct compare button in the reopened result overlay, and that action jumps the player/review flow back onto the original source take.
- `LightweightEditorViewController+ModularWiring` now offers a direct `Open <source take>` action after reopening the saved SmartFill result in editor context.
- Focused parity now covers:
  - player/review compare-action titles when source lineage exists
  - editor compare-action titles when source lineage exists

### Validation
- Preflight fetch:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase24_gateA build | tee /tmp/itfactor_smartfill_phase24_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase24_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase24_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase24_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase24_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase24_tests/Logs/Test/Test-STSiPhone-2026.03.26_20-21-40--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-021`, `SF-REBUILD-022`, and `SF-REBUILD-023` got the user back to the right saved result and named it honestly, but the reopened destination still left the original source take hidden behind generic swipe navigation or manual re-selection.
- The rebuild already had enough truth to wire comparison directly:
  - `SmartFillResultBridgeRecord.originalTakeID`
  - adopted take identity
  - review/player session take list
  - editor reopen callback path
- The right seam was therefore the reopened destination itself:
  - player/review should make comparison one tap away
  - editor should make source take reopening one action away
- The same seam matters for the future standalone hidden-session utility because post-save result review there will also need a direct compare-back-to-source behavior without reviving a separate success screen or utility-only compare controller.

### Next Action
1. Commit and push Ticket 024 on `gm/smartfill-itfactor-rebuild` with Gate A and focused parity evidence attached.
2. Choose the next flagship SmartFill workspace phase now that reopened destinations can both identify the saved SmartFill result and offer a direct path back to the original source take when lineage exists.
3. Keep the standalone derivation ledger synchronized because the future hidden-session utility should inherit the same saved-result plus source-compare finish seam.

## Ticket 023 Saved Result Context In Reopened Destinations (2026-03-26)
- Thread Status: reopened project-review/player and editor destinations now explicitly surface saved SmartFill result identity/context after completion, local gating is green, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `694bd29d0440a0cb8b980fafbdfc5e5cfa0ce254`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Make reopened destinations explicitly identify the saved SmartFill result:
1. make project-review/player reopen destinations clearly identify the just-saved SmartFill result instead of silently landing on the adopted take
2. make editor reopen destinations clearly identify the just-saved SmartFill result instead of only swapping takes with no explicit context
3. keep saved-result identity consistent for both manual and automatic reopen paths
4. keep standalone derivation aligned because the later hidden-session utility will need the same `you are viewing the result you just saved` seam

### Completed This Pass
- Truth-sync preflight confirmed:
  - `HEAD`: `694bd29d0440a0cb8b980fafbdfc5e5cfa0ce254`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Archaeology confirmed the remaining product gap after `SF-REBUILD-022`:
  - both manual reopen and automatic `Return` now reached the correct saved take
  - neither player/review nor editor destinations explicitly told the user that the reopened take was the SmartFill result they had just saved
  - the saved-result label already existed in `SmartFillResultBridgeRecord`, but there was no shared presentation seam carrying that identity into reopened destinations
- Added `SmartFillReopenDestinationContext` as the authoritative shared seam for saved-result reopen presentation across:
  - project-review/player reopen flows
  - editor reopen flows
  - later standalone hidden-session reopen flows
- `ProjectDetailView` now passes saved-result identity into `SwipeableVideoPlayerData`, and `SwipeableVideoPlayerView` now surfaces that identity in its title overlay instead of silently reopening the adopted take.
- `LightweightEditorViewController+ModularWiring` now shows explicit saved-result context after swapping the editor onto the adopted SmartFill take.
- Focused parity now covers:
  - player/review reopen context naming the saved take
  - editor reopen context naming the saved take

### Validation
- Preflight fetch:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
- Storage recovery:
  - deleted stale `/tmp/itfactor_smartfill_*` and `/tmp/sts_*` artifacts after build/test failures hit `No space left on device`
  - recovered roughly `70 GiB` on the data volume before rerunning the authoritative gates
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase23_gateA_rerun3 build | tee /tmp/itfactor_smartfill_phase23_gateA_rerun3.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase23_gateA_rerun3.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase23_tests_rerun3 -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase23_tests_rerun3.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase23_tests_rerun3.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase23_tests_rerun3/Logs/Test/Test-STSiPhone-2026.03.26_19-56-52--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-021` and `SF-REBUILD-022` fixed the actual reopen routing for both manual and automatic finish paths, but they still reopened into destinations that looked the same as any normal take open.
- The rebuild already had the correct saved-result identity source in `SmartFillResultBridgeRecord.adoptedTakeDisplayName`, so the right next move was to add a shared presentation seam rather than invent another shell banner or duplicate completed-state summary.
- `SwipeableVideoPlayerView` and editor reopen were the correct flagship seams because they are where users actually land after save, and the future standalone utility will need the same destination-context seam once hidden-session reopen becomes the utility's post-save finish path.

### Next Action
1. Commit and push Ticket 023 on `gm/smartfill-itfactor-rebuild` with Gate A and focused parity evidence attached.
2. Choose the next flagship SmartFill workspace phase now that both reopened destinations explicitly identify the just-saved SmartFill result instead of silently landing on the adopted take.
3. Keep the standalone derivation ledger synchronized because the future hidden-session utility will need the same saved-result context seam.

## Ticket 022 Auto-Return Uses Real Saved Take Reopen Path (2026-03-26)
- Thread Status: the rebuild workspace now routes both manual completed-state actions and automatic `Return` through the same saved-result reopen seam for project-review and editor launches, local gating is green, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `6f51c6cd4c3bb9adafa577e55a5d28c626796c4f`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Turn the completed-state auto-return into the same real reopen path:
1. make automatic `Return` use the same saved-result follow-up seam as the manual `Open <saved take>` action
2. keep project-review launches reopening the adopted take inside the correct review or player flow even when the workspace returns automatically
3. keep editor launches reopening the adopted take inside the editor even when save completion auto-returns
4. keep standalone derivation aligned because the later hidden-session utility will need the same automatic `open what you just saved` seam

### Completed This Pass
- Truth-sync preflight confirmed:
  - `HEAD`: `6f51c6cd4c3bb9adafa577e55a5d28c626796c4f`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Archaeology confirmed the remaining gap after `SF-REBUILD-021`:
  - `SmartFillWorkspaceView.handlePrimaryAction()` used `onOpenSavedTake(record)` for completed sessions
  - `SmartFillWorkspaceView.scheduleAutoReturn()` still called `handleClose()` directly
  - that meant manual reopen was truthful but automatic `Return` still skipped the saved-result reopen seam entirely
- `SmartFillWorkspaceCompletionFollowUpAction` now centralizes the completed-state follow-up decision so manual primary actions and queued auto-return both evaluate the same saved-result reopen rule.
- `SmartFillWorkspaceView` now routes:
  - manual completed-state primary actions
  - automatic `Return`
  through `performCompletionFollowUp(_:)` instead of keeping a separate close-only auto-return path.
- Focused parity now covers:
  - primary completed-state follow-up opening the saved take when available
  - close-only fallback when saved-result reopen is unavailable
  - automatic `Return` reusing the saved-result reopen seam only when return mode is active

### Validation
- Preflight fetch:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase22_gateA build | tee /tmp/itfactor_smartfill_phase22_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase22_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase22_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase22_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase22_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase22_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-55-45--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-021` fixed the manual route but not the automatic one:
  - the workspace could now reopen the saved take when the user tapped the primary action
  - the queued auto-return still dismissed the workspace with no saved-result callback
- `SmartFillResultBridgeRecord` already carries the exact IDs needed for both manual and automatic reopen:
  - `projectID`
  - `sessionID`
  - `adoptedTakeID`
  - `adoptedTakeDisplayName`
- `SmartFillWorkspaceFollowUpRoute` already keeps the route choice explicit, so the correct next move is to make auto-return use the same follow-up seam instead of building a second return controller.
- The new `SmartFillWorkspaceCompletionFollowUpAction` keeps that decision small and testable so the future standalone hidden-session utility can reuse the same manual-versus-auto return rule without duplicating workspace-close logic.

### Next Action
1. Commit and push Ticket 022 on `gm/smartfill-itfactor-rebuild` with Gate A and focused parity evidence attached.
2. Choose the next flagship SmartFill workspace phase now that both manual and automatic return paths can reopen the actual adopted SmartFill take instead of dismissing generically.
3. Keep the standalone derivation ledger synchronized because the future hidden-session utility will need the same saved-result reopen seam for both manual and automatic finish paths.

## Ticket 019 Real Saved Take Outcomes In Rebuild Workspace (2026-03-26)
- Thread Status: the rebuild workspace now carries the real adopted SmartFill take label through save outcomes, completion guidance, and return messaging, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `d7ed99ab48e53a3eb501c1096fb83d216976b0e4`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Make SmartFill save outcomes concrete instead of generic:
1. carry the actual adopted SmartFill take label through repository-backed save outcomes instead of defaulting to generic `SmartFill take` language
2. show the real session take name in completed-state comparison, return guidance, and saved-result summaries
3. keep notification-backed reopen/review flows aligned by emitting the same adopted take label alongside save completion
4. keep standalone derivation aligned because the later hidden-session utility should also tell users exactly what saved result was created or updated

### Completed This Pass
- `SmartFillResultBridgeRecord` now carries `adoptedTakeDisplayName` so the rebuild workspace can describe the real saved session take instead of relying on generic destination copy.
- Repository-backed adoption now computes the concrete SmartFill take label from persisted take/session truth and emits that same label through SmartFill completion notifications.
- Notification-backed result reconstruction now restores the same saved take label, so reopen/review flows keep the same concrete result identity as live workspace sessions.
- `SmartFillWorkspaceView` now uses that adopted take label in:
  - the save outcome panel
  - the latest saved result summary
  - completed-state `Stay here` guidance
  - completed-state `Return to ...` guidance
- Focused tests now cover:
  - concrete adopted take labels in repository-backed result adoption
  - concrete adopted take labels in notification-backed result reconstruction
  - completed-state stay/return guidance that names the real saved SmartFill take

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase19_gateA build | tee /tmp/itfactor_smartfill_phase19_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase19_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase19_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase19_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase19_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase19_tests/Logs/Test/Test-STSiPhone-2026.03.26_17-17-41--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-018` made save/update wording obey the user's chosen `Return` versus `Stay` mode, but the workspace still described completed outcomes with generic `SmartFill take` wording even after repository adoption had decided the concrete saved take.
- The rebuild already had the right shared seam in `SmartFillResultBridgeRecord`, so the correct next move was to deepen that result bridge and workspace presentation path instead of reviving any separate success banner, settings wrapper, or shell-owned save summary.
- The same seam matters for the future standalone utility because hidden-session save/share/history messaging should also name the actual saved result instead of falling back to generic copy.

### Next Action
1. Choose the next intentional flagship SmartFill workspace phase now that the rebuild owns entry, preview, defaults, result adoption, quick fill, treatment-finish presets, explicit stay/return choice, finish-state-aware save affordances, and real saved take outcome messaging.
2. Implement that next slice on `gm/smartfill-itfactor-rebuild`, then rerun Gate A plus focused SmartFill parity before any promotion decision.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same concrete saved-result identity seam without project/session wording.

## Ticket 018 Save Affordances Match Chosen Finish Behavior (2026-03-26)
- Thread Status: save/update actions, save-lane messaging, and completed-state comparison guidance now honor the user's chosen `Return` versus `Stay` behavior in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `e6e900e14297dd3be51004b75e3bed62ba07c571`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the save lane so the rebuilt SmartFill workspace tells one consistent finish-state story:
1. stop showing `Save and Return ...` or `Update and Return ...` when the user explicitly chose `Stay`
2. make the save-lane message and footnote reflect whether SmartFill will return automatically or remain open for comparison
3. show a clean completed-state comparison panel when the user saves and stays in the workspace
4. keep standalone derivation aligned because the same seam later becomes the hidden-session utility app's `Stay in editor` versus `Share/History` finish-state guidance

### Completed This Pass
- `SmartFillWorkspacePresentation.actionTitle` now honors `completionBehavior` during save/update stages:
  - `Save and Stay Here`
  - `Update and Stay Here`
  instead of implying an automatic return when the user chose to remain in the workspace.
- `SmartFillWorkspacePresentation.saveLaneMessage` and `saveFootnote` now differentiate:
  - update-in-place versus variant-take adoption
  - return automatically versus stay and compare
  so the save lane no longer tells users to expect a return path they did not choose.
- `SmartFillWorkspaceView` now shows a completed-state `Saved and staying here` comparison panel whenever:
  - the session is complete
  - the chosen after-save behavior is `Stay`
  - no new unsaved changes exist
- Focused tests now cover:
  - stay-here action titles
  - stay-here save-lane and footnote messaging
  - the completed-state stay-here comparison guidance
  - update-in-place save-lane wording for return-mode sessions

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase18_gateA_rerun build | tee /tmp/itfactor_smartfill_phase18_gateA_rerun.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase18_gateA_rerun.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase18_tests_rerun -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase18_tests_rerun.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase18_tests_rerun.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase18_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_15-00-06--0400.xcresult`
- Retry note:
  - the initial Gate A/parity attempt failed at compile time because `SmartFillWorkspacePresentation.saveFootnote` was missing a fallback `return`; the rerun after that fix is the authoritative gate proof.
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-017` correctly introduced `Return` versus `Stay`, but save/update action text still defaulted to return-oriented wording even when the user had chosen to stay in the workspace.
- The rebuild already centralized finish-state copy inside `SmartFillWorkspacePresentation`, so the correct fix was to deepen that shared presentation seam instead of reviving any separate completion banners, save modals, or wrapper UI.
- The future standalone utility needs the same seam because its hidden-session finish state also depends on whether the user stays in the editor or moves into share/history immediately after save.

### Next Action
1. Choose the next flagship SmartFill workspace phase now that the rebuild owns entry, defaults, real preview, explicit product lanes, quick fill, treatment-finish presets, explicit stay/return choice, and save/update copy that now fully matches the chosen finish behavior.
2. Implement that next slice on `gm/smartfill-itfactor-rebuild`, then rerun Gate A plus focused SmartFill parity before any promotion decision.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same finish-state truth without project/session wording.

## Ticket 017 Treatment Finish Presets And Post-Save Stay Mode (2026-03-26)
- Thread Status: one-tap treatment finish presets plus an explicit after-save stay/return mode are implemented in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `c6f271a478717e50fc6796708b2a758654615b5e`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Deepen the rebuilt SmartFill workspace from save-truth clarity into faster end-of-edit decisions:
1. restore shipped-style treatment finish choices so users can land on a strong background look without dragging blur and darken sliders first
2. make after-save behavior an explicit choice before render instead of implying auto-return for every launch target
3. keep processing, completion, and deferred-return copy honest when the user chooses to stay and compare the preview after save
4. keep standalone derivation aligned because the same treatment-finish presets and stay/return seam later become the hidden-session utility app's edit-finish model

### Completed This Pass
- `SmartFillWorkspaceView` now exposes a `Treatment finish` section with one-tap shipped-style presets:
  - `Soft`
  - `Balanced`
  - `Bold`
  Each preset maps onto shared blur/darken settings and refreshes the live preview without reviving any deleted shell wrappers.
- The save lane now includes an explicit `After save behavior` choice:
  - `Return`
  - `Stay`
  so review/player launches can still default to auto-return while editor launches default to staying in the workspace for comparison.
- `SmartFillWorkspacePresentation` now differentiates save-outcome, processing, completion, and deferred-return copy when the user chooses to stay instead of automatically returning.
- Focused tests now cover:
  - stay-here save/processing/completion/deferred-return wording
  - default completion behavior for editor versus review-style launch targets

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase17_gateA build | tee /tmp/itfactor_smartfill_phase17_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase17_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase17_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase17_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase17_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase17_tests/Logs/Test/Test-STSiPhone-2026.03.26_14-13-06--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- The shipped SmartFill settings flow used named treatment presets (`Subtle`, `Medium`, `Dramatic`) as faster decision points than raw slider-first tuning.
- `SF-REBUILD-016` restored quick fill and honest save-outcome messaging, but the rebuild workspace still made users derive a finished look from blur/darken sliders and still framed post-save behavior as auto-return-first.
- The correct next move was to keep both treatment-finish presets and stay/return choice inside `SmartFillWorkspaceView` / `SmartFillWorkspacePresentation` instead of reviving deleted settings shells or reintroducing one-off completion wrappers.

### Next Action
1. Choose the next flagship SmartFill workspace phase now that the rebuild owns entry, defaults, real preview, explicit product lanes, dirty-save truth, quick fill presets, one-tap treatment finish presets, and an explicit after-save stay/return mode.
2. Implement that slice on `gm/smartfill-itfactor-rebuild`, then rerun Gate A plus focused SmartFill parity before any further promotion decision.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same treatment-finish and stay/return behavior with hidden-session wording.

## Ticket 016 Background Fill And Save Outcome Affordances (2026-03-26)
- Thread Status: shipped-style quick fill presets and explicit save-outcome messaging are anchored on the GM branch, and the next action is the next intentional workspace evolution.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `c6f271a478717e50fc6796708b2a758654615b5e`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Strengthen the rebuilt SmartFill workspace around treatment speed and save clarity:
1. restore shipped-style quick background fill choices so users can clean up side bars without dragging a raw scale slider first
2. explain exactly what save changes, what stays untouched, and where SmartFill returns next before the user commits a render
3. keep dirty-after-save, in-progress save, and auto-return copy honest without reviving any deleted legacy shell UI
4. keep standalone derivation aligned because the same quick-fill and save-outcome seams later become the utility app's simpler edit-to-save guidance

### Completed This Pass
- `SmartFillWorkspaceView` now exposes a `Quick fill` section with `Subtle`, `Default`, and `Edge-to-edge` presets mapped onto shared `backgroundScale` values.
- The background fill slider remains available for fine-tuning, but the workspace now gives users a shipped-style fast first step before they reach for raw values or advanced settings.
- The save lane now includes a `What happens on save` panel that explains:
  - the source clip stays unchanged
  - whether SmartFill will update the current take or create/refresh a SmartFill take
  - what return behavior follows save for review/player versus editor launches
- `SmartFillWorkspacePresentation` now owns save-outcome copy for first save, save-in-progress, pending auto-return, clean completion, and dirty-after-save states.
- Focused tests now cover both first-save outcome messaging and dirty-after-save / auto-return outcome wording.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase16_gateA_rerun build | tee /tmp/itfactor_smartfill_phase16_gateA_rerun.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase16_gateA_rerun.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase16_tests_rerun2 -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase16_tests_rerun2.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase16_tests_rerun2.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase16_tests_rerun2/Logs/Test/Test-STSiPhone-2026.03.26_13-34-53--0400.xcresult`
- Retry note:
  - the initial parity run at `/tmp/itfactor_smartfill_phase16_tests.log` failed on save-copy capitalization; the rerun after the `sentenceDestinationOutcomeTitle` fix is the authoritative parity proof.
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- The shipped SmartFill settings flow used quick background scale choices at `5×`, `10×`, and `15×` as a fast first-step treatment model.
- The rebuild workspace already had richer background modes and honest dirty-save truth, but it still made users infer the actual save outcome from generic action titles alone.
- The correct fix was to keep quick fill and save-outcome explanation inside `SmartFillWorkspaceView` / `SmartFillWorkspacePresentation` instead of reviving deleted settings/dashboard shells.

### Next Action
1. Choose the next flagship SmartFill workspace phase now that the rebuild owns quick fill presets, explicit save-outcome truth, honest dirty-after-save state, real preview, defaults, and shared launch/return behavior.
2. Implement that slice on `gm/smartfill-itfactor-rebuild`, then rerun Gate A plus focused SmartFill parity before any further promotion decision.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse quick-fill and save-outcome guidance with hidden-session wording.

## Ticket 015 Dirty Save Truth In Rebuild Workspace (2026-03-26)
- Thread Status: dirty-after-save workspace truth is anchored on the GM branch, and the next action is the next intentional workspace evolution.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `c6f271a478717e50fc6796708b2a758654615b5e`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Restore honest save-lane truth now that the rebuild workspace can linger after save:
1. keep the latest saved SmartFill result visible inside the workspace instead of hiding saved truth behind a generic completed stage
2. revert the workspace back to a save-needed state whenever settings change after a completed save
3. cancel auto-return whenever the saved result is no longer clean so return affordances stop implying the current changes are already persisted
4. keep standalone derivation aligned because the same saved-result-versus-dirty-changes seam later becomes the utility app’s save/share/history truth

### Completed This Pass
- `SmartFillWorkspaceView` now compares the live settings snapshot against `coordinator.lastResult?.settingsSnapshot` to decide whether the current session still matches the last saved SmartFill output.
- The workspace now shows a `latestSavedResultPanel` when a saved result exists, including:
  - destination outcome
  - saved output file name
  - saved look summary restored from the saved settings snapshot
- The workspace now drops back from completed-state truth into a save-needed state whenever settings change after save:
  - stage chip changes from completed to a dirty `Needs Save` preview state
  - primary action returns to `Save/Update and Return ...`
  - auto-return is canceled until the user saves again
- Dirty-after-save copy now warns that the current changes are not yet saved and must be persisted again before returning.
- Common settings mutations now explicitly mark the session dirty after completion by refreshing the preview token and canceling auto-return without reviving any legacy shell wrapper.
- Focused tests now cover:
  - completed-stage action titles restoring save/update wording when the session becomes dirty again
  - unsaved-changes copy for both review and editor return targets
  - saved-result destination titles for update vs variant-take adoption

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase15_gateA build | tee /tmp/itfactor_smartfill_phase15_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase15_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase15_tests_rerun -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase15_tests_rerun.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase15_tests_rerun.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase15_tests_rerun/Logs/Test/Test-STSiPhone-2026.03.26_13-00-56--0400.xcresult`
- Retry note:
  - initial simulator-name parity run at `/tmp/itfactor_smartfill_phase15_tests.log` failed before test-runner handoff with `Channel disconnected`; the explicit-UDID rerun is the authoritative parity proof.
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-014` introduced live progress and `Stay Here`, but the workspace still behaved like a completed session even if the user changed settings after the save finished.
- The rebuild already had all the data needed to restore honest state because `SmartFillResultBridge` preserved the last adopted result and the workspace already owned stage/copy logic.
- The correct fix was to compare current settings against the last saved snapshot and keep save truth inside `SmartFillWorkspaceView` / `SmartFillWorkspacePresentation` instead of reviving legacy completion banners or shell-level warning chrome.

### Next Action
1. Choose the next flagship SmartFill workspace phase now that the rebuild owns launch truth, preview, defaults, explicit product lanes, inline treatment controls, live save progress, explicit stay/return control, and honest dirty-after-save state.
2. Implement that slice on `gm/smartfill-itfactor-rebuild`, then rerun Gate A plus focused SmartFill parity before any further promotion decision.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same saved-result and unsaved-changes model.

## Ticket 014 Workspace Save Progress And Return Control (2026-03-26)
- Thread Status: live save-progress feedback plus explicit stay-vs-return control are implemented in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `d2ca4242b760db2d3e297604f0e2a27f0143d362`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Deepen the rebuild workspace now that inline treatment controls and explicit return actions are already anchored:
1. surface live SmartFill save progress inside the rebuild workspace instead of relying on generic processing copy alone
2. carry take/session/project identity through SmartFill progress notifications so the workspace can trust real progress updates
3. replace forced post-save auto-dismiss with a clearer stay-vs-return moment while still preserving quick default return behavior
4. keep standalone derivation aligned because the same progress/return seam later becomes the utility app’s save/share/history finish state

### Completed This Pass
- `SmartFillProcessingManager` progress notifications now carry:
  - `takeID`
  - `sessionID`
  - `projectID`
  so the rebuild workspace can listen for real progress without reviving any project-level wrapper UI.
- `SmartFillWorkspaceView` now listens for `.smartFillProcessingProgress` and updates the save lane with:
  - a live percentage
  - a `ProgressView`
  - stage-aware processing copy
- The workspace save lane now exposes a real completed-state control surface:
  - saved-and-ready status
  - explicit `Stay Here` affordance
  - primary `Return to ...` action remains available for immediate handoff
- Auto-return is still the default completion path, but users can now cancel it intentionally and keep the workspace open after save.
- Focused tests now cover:
  - progress-aware processing copy
  - deferred return messaging after canceling auto-return

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase14_gateA build | tee /tmp/itfactor_smartfill_phase14_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase14_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase14_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase14_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase14_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase14_tests/Logs/Test/Test-STSiPhone-2026.03.26_12-32-18--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-013` made completion clearer, but the workspace still had no live processing progress and auto-return still behaved like a silent timer.
- The SmartFill engine was already publishing progress, but those notifications were missing take/session/project identity, so the workspace could not safely consume them.
- The correct next move was to enrich the existing shared notification seam and keep save-progress / return behavior inside the rebuild workspace instead of reintroducing banners, modal wrappers, or project-detail-only status chrome.

### Next Action
1. Commit and push the workspace save-progress and return-control slice on `gm/smartfill-itfactor-rebuild`.
2. Choose the next flagship SmartFill workspace phase now that the rebuild owns launch truth, real preview, explicit product lanes, inline treatment controls, live save progress, and intentional return control.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same progress and finish-state model.

## Ticket 013 Workspace Treatment Controls And Return Flow (2026-03-26)
- Thread Status: richer inline treatment controls plus tighter save/return behavior are implemented in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `c23f2cbfcd2101933f1ab1e679d790852ca3f6ee`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Deepen the rebuild workspace now that launch truth and explicit product lanes are anchored:
1. move more background treatment controls directly into the main workspace instead of hiding them behind generic advanced-sheet flow
2. make save/export action states clearer while processing and after completion
3. tighten post-save return behavior so review/player/editor re-entry feels intentional instead of generic auto-dismiss
4. keep standalone derivation aligned because the same treatment controls and return model should later map onto the hidden-session utility editor

### Completed This Pass
- `SmartFillWorkspaceView` now exposes inline background-treatment sliders for:
  - blur radius
  - darken amount
  - background fill
  so the main workspace can handle the common tuning path without forcing a separate advanced-sheet detour.
- Each inline treatment control now explains its effect in plain language so the user can understand whether they are preserving room detail, balancing separation, or aggressively hiding background gaps.
- The main workspace action path is now tighter after save:
  - export stage disables both close and primary actions
  - completed stage changes the primary action into an explicit `Return to ...` affordance instead of leaving a passive saved-state label
  - completion now schedules a slightly slower auto-return so the user can see the saved state before the workspace dismisses
- Completion copy now describes the active return target as an in-progress return instead of describing the save as already finished and gone.
- Focused tests now cover:
  - completed-stage `Return to ...` action titles
  - completed-stage return copy for editor and review contexts

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase13_gateA build | tee /tmp/itfactor_smartfill_phase13_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase13_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase13_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase13_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase13_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase13_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-57-39--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-012` made the return target truthful in copy, but the workspace still hid day-to-day treatment adjustments behind a separate sheet and left the completed state as a passive label.
- The underlying settings model already exposed blur, darkening, and background fill directly, so the right next move was to bring those controls into the main workspace instead of inventing another modal or rebuilding the settings engine.
- The rebuild workspace already owned return-target truth, so the completed-state improvement stays inside the shared workspace seam instead of reopening any deleted SmartFill wrapper path.

### Next Action
1. Commit and push the workspace treatment-controls and return-flow slice on `gm/smartfill-itfactor-rebuild`.
2. Choose the next intentional flagship SmartFill workspace phase now that the rebuild owns launch truth, real preview, inline treatment controls, and explicit return actions.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same inline control and return model.

## Ticket 012 Workspace Return Context And Save States (2026-03-26)
- Thread Status: real launch/return context, stage-aware save copy, and explicit background-look modes are implemented in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `83ce749bd1042b08bbec3640f7ea97f81e2bc320`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Tighten the rebuild workspace so the save/return story reflects real flagship context instead of heuristics:
1. use the actual launch source and return target from project detail, take review/player, and editor entry points
2. make save/export action text change with workspace stage instead of staying static
3. replace raw preset language with clearer background-look modes while preserving the same shared `SmartFillSettings` engine state
4. keep standalone derivation aligned because the same context/copy model later maps directly onto the hidden-session utility shell

### Completed This Pass
- `ProjectDetailView` now resolves real SmartFill launch and return truth before presenting the rebuild workspace:
  - player launches return to player unless the flow is explicitly reopening the editor
  - take-review launches return to review unless the flow is explicitly reopening the editor
  - project-detail launches return to project detail unless the flow is explicitly reopening the editor
- `LightweightEditorViewController+ModularWiring` now seeds editor-origin SmartFill sessions with explicit `.editorBadge` launch source and `.editor` return target.
- `SmartFillWorkspaceView` now builds its coordinator context from the real `SmartFillSettingsContext` launch/return values instead of hardcoding take-review return assumptions.
- Workspace save/export copy is now stage-aware:
  - configure -> `Save and Return ...` or `Update and Return ...`
  - export -> `Saving SmartFill...`
  - completed -> `Saved to ...`
- The look lane now exposes three explicit background modes:
  - Natural
  - Balanced
  - Cinematic
  while still mapping back onto the existing preset-backed `SmartFillSettings` state.
- Completion, processing, and save-lane messaging now describe the actual return target and adoption mode instead of a generic destination summary.
- Focused tests now cover:
  - explicit return-target copy
  - stage-aware action-title changes
  - background-mode naming

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase12_gateA build | tee /tmp/itfactor_smartfill_phase12_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase12_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase12_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase12_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase12_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase12_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-27-31--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-011` exposed the main product lanes, but the workspace still described save/return behavior as if every flow returned to take review.
- Review/player, project-detail, and editor entry all already carried enough context to resolve real return behavior, so the correct move was to push that truth into `SmartFillSettingsContext` and `SmartFillWorkspacePresentation` instead of inventing another wrapper layer.
- The existing preset system already encoded usable look groupings; the new background modes rename those same settings for product clarity without changing the underlying shared engine contract.

### Next Action
1. Commit and push the workspace return-context and save-state slice on `gm/smartfill-itfactor-rebuild`.
2. Choose the next intentional flagship SmartFill workspace/product phase now that launch truth, preview, product lanes, and save/return copy all live under the rebuild namespace.
3. Keep the standalone derivation ledger synchronized so the later hidden-session utility can reuse the same context and copy model.

## Ticket 011 Explicit Workspace Controls And Save Flow (2026-03-26)
- Thread Status: explicit background/look, framing, output, and save lanes are implemented in the rebuild workspace, locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `17de187c9b6da05e712b0e1e4a1b34902022371a`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Expose the real SmartFill product decisions directly inside the rebuild workspace now that entry, defaults, preview, and repository adoption all live under rebuild ownership:
1. make background/look choices explicit instead of hiding them behind generic presets-only copy
2. add a real subject-framing lane the user can understand and manipulate
3. expose output size and processing-priority choices as first-class workspace controls
4. make save-back behavior visible so the workspace tells the user where SmartFill output goes and what action will occur
5. record how the same explicit control lanes later become the standalone utility editor behind a hidden static session

### Completed This Pass
- `SmartFillWorkspaceView` now uses five intentional product lanes:
  - preview
  - background look
  - subject framing
  - output
  - save back to session
- Workspace header copy now derives from `SmartFillWorkspacePresentation` so the same launch context can describe itself clearly for flagship review/edit entry and later standalone derivation.
- The look lane now keeps the existing preset affordance but also surfaces blur, darken, and background-scale summaries in plain language.
- The framing lane now exposes a real `foregroundScale` slider and descriptive framing copy instead of leaving subject treatment implicit.
- The output lane now presents explicit render-size choices plus processing-priority controls in the main workspace.
- The save lane now makes destination, return target, current action, and status/error copy visible without reviving any deleted legacy shell.
- Focused tests now cover context-driven copy, SmartFill-variant save messaging, and framing/priority descriptions.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase11_gateA build | tee /tmp/itfactor_smartfill_phase11_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase11_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase11_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase11_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase11_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase11_tests/Logs/Test/Test-STSiPhone-2026.03.26_11-04-50--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-010` restored the real SmartFill preview, but the workspace still hid major product choices behind implicit settings and generic button language.
- The underlying `SmartFillSettings` model already carried background, framing, render-size, and processing-priority state, so the correct next move was to expose those seams directly rather than create another modal/settings shell.
- The new presentation helpers stay inside the rebuild workspace and avoid reviving any deleted controller/modal/dashboard surface.

### Next Action
1. Commit and push the explicit workspace controls and save-flow slice on `gm/smartfill-itfactor-rebuild`.
2. Choose the next flagship SmartFill workspace/product phase now that the rebuild exposes preview, look, framing, output, and save lanes together.
3. Keep the standalone derivation ledger synchronized so the same lane model can later back the hidden-session utility app.

## Ticket 010 Real SmartFill Preview Restoration (2026-03-26)
- Thread Status: the rebuild workspace now renders the real SmartFill preview path, the slice is locally gated, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `9a1959eefeea6ae65b5ba5aa7e2d350cc1fd287b`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Restore the actual SmartFill preview experience inside the rebuild workspace instead of showing the raw source take:
1. replace the source `VideoPlayer` fallback with the real SmartFill preview pipeline
2. make preview reload deterministic when settings or an explicit refresh token change
3. surface preview-load errors without reviving any legacy SmartFill wrapper UI
4. record how the same preview seam remains reusable for the future standalone hidden-session utility

### Completed This Pass
- `SmartFillWorkspaceView` now renders `SmartFillPreviewPlayer` against the active workspace preview URL instead of a raw `AVPlayer` source fallback.
- Workspace settings mutations now call a shared `markPreviewDirty()` helper so blur, darken, background scale, preset, and render-size changes invalidate preview state consistently.
- `SmartFillPreviewPlayer` now tracks a refresh token in addition to video URL and settings, and `SmartFillRealPreviewView` stores that token so refreshes are deterministic.
- Preview load failures now surface as an inline warning label in the workspace instead of silently failing.
- Focused rebuild tests now cover preview reload truth:
  - reload on refresh token change
  - reload on settings change
  - no reload when inputs are unchanged

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase8_gateA build | tee /tmp/itfactor_smartfill_phase8_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase8_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase8_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase8_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase8_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase8_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-29-03--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- The rebuild workspace previously showed a raw source-player fallback, which made the flagship SmartFill screen look like intake/review instead of a real processing workspace.
- The underlying preview engine already existed in `Core/VideoPipeline/SmartFill`, so the correct move was to wire that engine into the rebuild workspace rather than invent another shell-specific preview layer.
- The preview path now depends on shared engine seams, not any of the deleted legacy controller/modal/dashboard surfaces.

### Next Action
1. Commit and push the real SmartFill preview restoration slice on `gm/smartfill-itfactor-rebuild`.
2. Choose the next intentional flagship SmartFill workspace/product phase now that the rebuild owns entry, result adoption, defaults, and real preview.
3. Keep the standalone derivation ledger synchronized so the later utility shell can reuse the same preview-backed workspace.

## Ticket 009 Intentional SmartFill Defaults Entry Restoration (2026-03-26)
- Thread Status: one intentional SmartFill defaults entry is implemented, locally gated, and waiting on commit/push as the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `866ed1c6a40774608c9d8c5540467599dcf7a51d`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Restore one intentional SmartFill defaults surface after the duplicate settings shells were removed:
1. add one rebuild-owned defaults view instead of reviving legacy settings/dashboard wrappers
2. expose one reachable SmartFill Defaults entry from flagship Settings
3. persist the same `SmartFillSettings` defaults that seed rebuild workspace sessions
4. record how the same defaults seam later becomes the standalone utility defaults surface

### Completed This Pass
- Added the rebuild-owned defaults surface:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillDefaultsView.swift`
- Restored one reachable Settings entry in:
  - `STSiPhone/STSiPhone/Features/Settings/SettingsView.swift`
- The new defaults view now:
  - loads shared `SmartFillSettings`
  - persists changes through `saveToUserDefaults()`
  - exposes preset, render-size, enable, and advanced-defaults controls
  - reuses `SmartFillAdvancedSettingsView` instead of reviving deleted settings-side wrappers

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase7_gateA build | tee /tmp/itfactor_smartfill_phase7_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase7_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase7_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase7_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase7_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase7_tests/Logs/Test/Test-STSiPhone-2026.03.26_10-11-10--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-006` intentionally deleted the dormant settings-side SmartFill wrappers and left no reachable global defaults entry.
- `SmartFillSettings` remains the correct persistence model for defaults that seed rebuild workspace launches.
- `SmartFillAdvancedSettingsView` already lived under `Features/SmartFill/Rebuild`, so the correct follow-on was one small rebuild-owned defaults view, not resurrecting `SmartFillSettingsView`.

### Next Action
1. Commit and push the intentional SmartFill defaults entry restoration slice on `gm/smartfill-itfactor-rebuild`.
2. Decide the next flagship SmartFill workspace/product slice now that legacy duplicate screens are gone and one clean defaults entry exists again.
3. Keep the standalone derivation ledger synchronized with every future shared-workspace or defaults evolution.

## Ticket 006 Legacy SmartFill Settings-Side Duplication Retirement (2026-03-26)
- Thread Status: the settings-side SmartFill duplicate surfaces are retired, locally gated, and waiting on commit/push as the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `52289e4b337d15c1f2b360139a1734c11ec193a8`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Finish the remaining settings-side cleanup under `SF-REBUILD-006` now that the rebuild workspace fully owns SmartFill entry:
1. retire the dead settings-side SmartFill shells with no live triggers or callers
2. preserve only the reusable advanced-settings component by moving it under the rebuild workspace
3. remove dead Settings/editor state that still referenced the deleted settings shells
4. close the duplicate SmartFill UI cleanup contract so future work is intentional workspace evolution, not legacy wrapper removal

### Completed This Pass
- Deleted the dormant settings-side SmartFill shells:
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift`
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
  - `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift`
- Moved the reusable advanced settings sheet into:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillAdvancedSettingsView.swift`
- Removed dead SmartFill settings state from:
  - `STSiPhone/STSiPhone/Features/Settings/SettingsView.swift`
  - `STSiPhone/STSiPhone/Features/Editing/LightweightEditorViewController.swift`
- Updated the audit, status, board, catalog, and standalone derivation docs to mark `SF-REBUILD-006` complete once this slice is committed.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase6_gateA build | tee /tmp/itfactor_smartfill_phase6_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase6_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase6_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase6_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase6_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase6_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-53-26--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SmartFillMigrationDashboard` and `SmartFillBatchProcessingView` had no live callers outside previews.
- `SmartFillSettingsView` remained only as a zombie sheet in `SettingsView`; the state existed but no live trigger set it true.
- The rebuild workspace still needed `SmartFillAdvancedSettingsView`, so that reusable component was split out instead of reviving the dead settings shell.

### Next Action
1. Commit and push the settings-side SmartFill duplication retirement slice on `gm/smartfill-itfactor-rebuild`.
2. Decide the next intentional flagship SmartFill workspace/product phase now that `SF-REBUILD-006` is complete.
3. Keep the standalone derivation ledger synchronized with each future shared-workspace cut.

## Ticket 005 Legacy SmartFill Editor Seam Retirement (2026-03-26)
- Thread Status: the legacy editor-only SmartFill seams are retired, locally gated, and waiting on commit/push as the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `75cf668d3e3fed99f95c56a00605f0e58fa1505e`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Retire the old editor-owned SmartFill controller/modal path now that review/player and editor-origin launches both share the rebuild workspace:
1. delete the dead editor-only SmartFill controller/modal/preview seams
2. remove the unused coordinator and modular wiring hooks that only supported those seams
3. preserve the repository-backed rebuild workspace as the sole active editor SmartFill path
4. leave settings-side SmartFill duplication cleanup for the next bounded cutover slice

### Completed This Pass
- Deleted the editor-only legacy SmartFill seams:
  - `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift`
  - `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
  - `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift`
- Removed the dead `smartFillFinished` coordinator event and controller wiring from:
  - `STSiPhone/STSiPhone/Features/Editing/Coordinator/EditorCoordinator.swift`
  - `STSiPhone/STSiPhone/Features/Editing/LightweightEditorViewController+ModularWiring.swift`
- Updated the legacy audit and standalone derivation ledger so the remaining delete-after-cutover scope is now settings-side only.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase5_gateA build | tee /tmp/itfactor_smartfill_phase5_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase5_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase5_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase5_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase5_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase5_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-25-08--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- The rebuild workspace is now the only active SmartFill entry path for:
  - review/player launch from `ProjectDetailView`
  - editor-origin launch from `LightweightEditorViewController+ModularWiring`
- The deleted controller/modal/preview files were no longer referenced anywhere in the app target.
- Remaining legacy SmartFill duplication is now concentrated on settings-side surfaces:
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift`
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
  - `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift`

### Next Action
1. Commit and push the legacy editor seam retirement slice on `gm/smartfill-itfactor-rebuild`.
2. Continue `SF-REBUILD-006` on the remaining settings-side SmartFill dashboard/duplicate surfaces.
3. Keep the standalone derivation ledger synchronized with each cleanup cut.

## Ticket 004 Legacy SmartFill Entry Unification (2026-03-26)
- Thread Status: editor-side SmartFill entry unification is implemented and locally gated; commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `47eb208e105fbc8ecdd6679df82a405b3560604a`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Unify the remaining editor-side SmartFill launch path so the rebuild workspace becomes the only active SmartFill entry surface:
1. replace the legacy editor modal/controller launch path with the rebuild workspace bridge
2. keep repository-backed result adoption intact across review/player and editor-origin launches
3. preserve persistence seams that carry shipped SmartFill lineage
4. update the standalone derivation ledger so the same launch seam remains portable to a future hidden static-session utility shell

### Completed This Pass
- `EditorCoordinator` now routes `.smartFillRequested` back through `modularSmartFillTapped()` instead of the legacy controller-owned path.
- `LightweightEditorViewController+ModularWiring` now presents `SmartFillWorkspaceView` from the editor affordance instead of `SmartFillSettingsModal`.
- `SmartFillTakeBridge` now resolves canonical/original take truth for editor launches and preserves variant SmartFill settings when refining an existing SmartFill take.
- Focused rebuild bridge tests now cover:
  - persisted default workspace settings fallback
  - canonical original-take launch seeding for SmartFill variants

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase4_gateA build | tee /tmp/itfactor_smartfill_phase4_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase4_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase4_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase4_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase4_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase4_tests/Logs/Test/Test-STSiPhone-2026.03.26_09-06-16--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- Review/player entry already launches `SmartFillWorkspaceView` from `ProjectDetailView`.
- The editor stack now shares the same rebuild workspace entry seam through:
  - `STSiPhone/STSiPhone/Features/Editing/LightweightEditorViewController+ModularWiring.swift`
  - `STSiPhone/STSiPhone/Features/Editing/Coordinator/EditorCoordinator.swift`
- Remaining delete-after-cutover editor legacy seams are now:
  - `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift`
  - `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
- Legacy settings/dashboard surfaces remain present for later cutover cleanup:
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift`
  - `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
  - `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift`

### Next Action
1. Commit and push the editor-entry unification slice on `gm/smartfill-itfactor-rebuild`.
2. Delete the remaining `DELETE_AFTER_CUTOVER` SmartFill seams now that review/player and editor-origin entry both share the rebuild workspace.
3. Keep the standalone derivation ledger synchronized with the delete-after-cutover cleanup.

## Ticket 003 SmartFill Result Adoption Through Repository Truth (2026-03-25)
- Thread Status: the third rebuild slice is implemented and locally gated in the writable integration repo.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `bcf41a32dc3bc23ac87a79003c94f756ff8053b8`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Route SmartFill completion out of the rebuild workspace and back into flagship repository truth:
1. preserve original take lineage and SmartFill gating metadata
2. create or refresh one standalone SmartFill variant take in repository/session truth
3. publish completion notifications that reopen review/player against the adopted take ID
4. keep standalone derivation truth updated so the future utility swaps persistence, not workspace behavior

### Completed This Pass
- Added repository-backed SmartFill take upsert behavior:
  - `STSiPhone/STSiPhone/Shared/Repositories/SmartFillRepository+Upsert.swift`
  - deletes any existing variant for the same original take and recreates one authoritative standalone SmartFill take
- Expanded the rebuild result bridge:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillResultBridge.swift`
  - adopts output through `ProjectsRepository`
  - preserves `originalTakeID` for current review flow listeners
  - publishes `lineageOriginalTakeID` and `smartFillTakeID` for variant-aware reopen paths
- Rewired SmartFill completion handling:
  - `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/SmartFillProcessingManager.swift`
  - result notifications now carry repository-adopted take/session/project truth instead of inline-only payloads
- Updated rebuild workspace result capture:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceView.swift`
  - converts completion notifications into repository-backed `SmartFillResultBridgeRecord`s
- Expanded focused parity coverage:
  - `STSiPhone/STSiPhoneTests/SmartFillRebuildBridgeTests.swift`
  - validates standalone and inline notification-backed adoption records

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase3_gateA build | tee /tmp/itfactor_smartfill_phase3_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase3_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase3_tests_final -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase3_tests_final.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase3_tests_final.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase3_tests_final/Logs/Test/Test-STSiPhone-2026.03.25_22-46-56--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Commit and push this repository-adoption slice on `gm/smartfill-itfactor-rebuild`.
2. Complete bounded workspace replacement so the rebuild workspace, not the legacy settings/editor stack, fully owns SmartFill entry and return.
3. Start deleting `DELETE_AFTER_CUTOVER` legacy SmartFill UI surfaces once the replacement path is the only active path.

## Ticket 002 SmartFill Review Launch + Workspace Entry (2026-03-25)
- Thread Status: the second rebuild slice is implemented and locally gated in the writable integration repo.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `342eb22253f38f019508978271bca1822237802a`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Move SmartFill entry out of the legacy settings modal and into the rebuild bridge layer that fits the shipped itFactor shell:
1. launch from project/session/take review with one selected clip already loaded
2. seed workspace settings from take snapshot plus default preferences
3. host one bounded SmartFill workspace entry point in the flagship shell
4. keep standalone-derivation truth updated in the same slice

### Completed This Pass
- Replaced the `ProjectDetailView` SmartFill sheet branch so it now presents:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceView.swift`
  - instead of `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
- Added a new rebuild workspace entry view:
  - preview-backed clip hero
  - grouped preset buttons
  - advanced settings section
  - queue/create action tied to `SmartFillWorkspaceCoordinator`
- Added settings round-trip helpers to `SmartFillTakeBridge` so take snapshots and rebuild settings stay synchronized.
- Expanded focused rebuild bridge tests to cover:
  - settings round-trip fidelity
  - coordinator completion/result record behavior
- Updated standalone derivation notes so the same review-launch seam maps cleanly to a later hidden static-session utility flow.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase2_gateA build | tee /tmp/itfactor_smartfill_phase2_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase2_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_phase2_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase2_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase2_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase2_tests/Logs/Test/Test-STSiPhone-2026.03.25_21-16-50--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Next Action
1. Commit and push this review-launch integration slice on `gm/smartfill-itfactor-rebuild`.
2. Route workspace completion and export adoption fully through repository/take/session truth.
3. Finish bypassing and then remove the remaining duplicate SmartFill settings/editor surfaces after cutover.

## Ticket 001 SmartFill Rebuild Bootstrap (2026-03-25)
- Thread Status: initial itFactor-first SmartFill rebuild slice is implemented and locally gated in the writable integration repo.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` configured at baseline `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` configured at baseline `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/main` also exists as the bootstrap branch

### Objective
Rebuild SmartFill inside the itFactor shell first, not inside the current standalone utility shell:
1. classify and clear legacy SmartFill seams
2. preserve shipped persistence and take-lineage truth
3. introduce shared SmartFill bridge/coordinator seams
4. record standalone derivation truth at every stage so the future utility app is a fast extraction, not a reinvention

### Completed This Pass
- Added legacy SmartFill audit matrix:
  - `Docs/Recovery/SMARTFILL_ITFACTOR_REBUILD_AUDIT.md`
- Added standalone derivation ledger:
  - `Docs/Recovery/SMARTFILL_STANDALONE_DERIVATION_LEDGER.md`
- Added first rebuild bridge/coordinator seams:
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillSessionContext.swift`
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillTakeBridge.swift`
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillResultBridge.swift`
  - `STSiPhone/STSiPhone/Features/SmartFill/Rebuild/SmartFillWorkspaceCoordinator.swift`
- Added focused bridge parity coverage:
  - `STSiPhone/STSiPhoneTests/SmartFillRebuildBridgeTests.swift`
- Fixed inherited baseline test debt in `STSiPhone/STSiPhoneTests/OrientationTests.swift` so focused parity can run truthfully.

### Validation
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_rebuild_gateA_final build | tee /tmp/itfactor_smartfill_rebuild_gateA_final.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_rebuild_gateA_final.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/itfactor_smartfill_rebuild_tests_final2 -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_rebuild_tests_final2.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_rebuild_tests_final2.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_rebuild_tests_final2/Logs/Test/Test-STSiPhone-2026.03.25_19-50-58--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Laws In Force
1. `/Users/kevinbarrett/Dev/SelfTapeStudio` is read-only reference truth. No writes are allowed there.
2. `/Users/kevinbarrett/Dev/itFactor_1.23.26_git` is the writable flagship SmartFill rebuild repo.
3. The current standalone SmartFill utility UI is not the shell authority; only its SmartFill engine/domain/store work should be preserved conceptually.
4. Every integration cut must update standalone derivation truth in the ledger so the later utility extraction remains straightforward.

### Next Action
1. Commit and push this first rebuild bootstrap slice on `gm/smartfill-itfactor-rebuild`.
2. Wire SmartFill launch from project/session/take review into the new `SmartFillSessionContext` and `SmartFillWorkspaceCoordinator` seams.
3. Route result adoption through repository truth and remove or bypass the legacy duplicate SmartFill settings/editor surfaces after cutover.
