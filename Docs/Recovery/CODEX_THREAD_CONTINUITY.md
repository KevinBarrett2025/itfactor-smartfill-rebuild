# CODEX Thread Continuity

## Ticket 021 Real Reopen Handoff For Saved SmartFill Take (2026-03-26)
- Thread Status: the rebuild workspace now routes its completed-state primary action through a real saved-take reopen handoff for both project-review and editor launches, local gating is green, and commit/push is the active next action.
- Repo Truth: `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`
- Remote Truth: `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`
- Working Branch: `gm/smartfill-itfactor-rebuild`
- Working Head SHA: `73b119372213fc13868831a457f0ae3acffe91bf`
- Working Baseline SHA: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Shipped Reference Truth: `/Users/kevinbarrett/Dev/SelfTapeStudio` (read-only only)
- Standalone Engine Reference: `/Users/kevinbarrett/Dev/iTFactorSmartfill`
- Authority Branch State:
  - local `authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main` matches `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`

### Objective
Turn the honest saved-take copy into a real reopen path:
1. let the completed-state primary action open the saved SmartFill take instead of only dismissing the workspace
2. make project-review launches reopen the adopted take inside the correct review or player flow
3. make editor launches reopen the adopted take inside the editor instead of leaving the user on the original take
4. keep standalone derivation aligned because the later hidden-session utility will need the same "open what you just saved" seam

### Completed This Pass
- Truth-sync preflight confirmed:
  - `HEAD`: `73b119372213fc13868831a457f0ae3acffe91bf`
  - local `authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
  - remote `origin/authority/main`: `94883522cfa9a76c6fd779de8bac2afe5a4bb79b`
- Archaeology confirmed the prior gap:
  - `SmartFillWorkspaceView.handlePrimaryAction()` still called `handleClose()` whenever the stage was `.completed`
  - `ProjectDetailView` only restored review/player context on workspace disappear and had no dedicated saved-result reopen path
  - `LightweightEditorViewController+ModularWiring` launched the rebuild workspace but had no callback that swapped the editor onto the adopted SmartFill take after save
- `SmartFillWorkspaceView` now accepts `onOpenSavedTake` and uses it when the workspace has a completed `SmartFillResultBridgeRecord`, so the primary completed-state action no longer falls back to a generic close.
- `SmartFillWorkspaceFollowUpRoute` now centralizes follow-up routing for:
  - editor reopen
  - player/review reopen
  - project-detail player reopen without forced review bounce
  - standalone close-only fallback
- `ProjectDetailView` now stores a pending reopen request, resolves the adopted SmartFill take from repository truth, and reopens that saved take in the correct player/review flow instead of only dismissing the workspace.
- `LightweightEditorViewController+ModularWiring` now reopens the adopted SmartFill take inside the editor after workspace save completion instead of leaving the editor on the original take.
- Focused parity now covers the follow-up route matrix directly.

### Validation
- Preflight fetch:
  - `git -C /Users/kevinbarrett/Dev/itFactor_1.23.26_git fetch origin --prune`
- Gate A command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/itfactor_smartfill_phase21_gateA build | tee /tmp/itfactor_smartfill_phase21_gateA.log`
- Gate A result:
  - `PASS`
- Gate A log:
  - `/tmp/itfactor_smartfill_phase21_gateA.log`
- Focused parity command:
  - `xcodebuild -project /Users/kevinbarrett/Dev/itFactor_1.23.26_git/STSiPhone/ITFactoriPhone.xcodeproj -scheme STSiPhone -destination 'platform=iOS Simulator,id=AF7E7F7C-C0BD-4BEA-AD51-74505E6853DD' -derivedDataPath /tmp/itfactor_smartfill_phase21_tests -only-testing:STSiPhoneTests/SmartFillRebuildBridgeTests test | tee /tmp/itfactor_smartfill_phase21_tests.log`
- Focused parity result:
  - `PASS`
- Focused parity log:
  - `/tmp/itfactor_smartfill_phase21_tests.log`
- Focused parity xcresult:
  - `/tmp/itfactor_smartfill_phase21_tests/Logs/Test/Test-STSiPhone-2026.03.26_18-35-50--0400.xcresult`
- `project.pbxproj` drift:
  - `NONE`

### Archaeology Snapshot
- `SF-REBUILD-020` fixed the words but not the route:
  - the workspace could say `Open <saved take>`
  - the actual primary action still closed the sheet
- `ProjectDetailView` and editor wiring already had most of the repository and presentation seams needed to reopen the adopted take, so the correct fix was to add one bounded callback seam instead of reviving another completion modal or wrapper controller.
- `SmartFillResultBridgeRecord` already carried the exact IDs needed for a real reopen handoff:
  - `projectID`
  - `sessionID`
  - `adoptedTakeID`
  - `adoptedTakeDisplayName`
- The new `SmartFillWorkspaceFollowUpRoute` keeps the route choice explicit so the future standalone hidden-session utility can reuse the same `open what you just saved` seam while swapping player/editor/project-detail targets for utility-local follow-up destinations.

### Next Action
1. Commit and push Ticket 021 on `gm/smartfill-itfactor-rebuild` with Gate A and focused parity evidence attached.
2. Choose the next flagship SmartFill workspace phase now that the rebuild can reopen the actual adopted SmartFill take instead of only dismissing after save.
3. Keep the standalone derivation ledger synchronized because the future hidden-session utility will need the same concrete saved-result reopen seam.

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
