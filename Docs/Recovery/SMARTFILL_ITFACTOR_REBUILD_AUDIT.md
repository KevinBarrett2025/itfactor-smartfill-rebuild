# SmartFill itFactor Rebuild Audit

Date: 2026-03-25
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
| SmartFill processing core | `STSiPhone/STSiPhone/Core/VideoPipeline/SmartFill/*` | `REFERENCE_ONLY` | Contains useful compositor, preview, export, policy, and worker archaeology, but the rebuild will move toward a new workspace contract instead of continuing these UI-facing seams as-is. | Keep available for comparison; do not extend as product shell truth. |
| Legacy SmartFill controller | `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift` | `KEEP` | This is the current launch/process seam from editor/review context and shows how SmartFill fits into the flagship shell. | Preserve while new workspace coordinator is introduced behind it. |
| Legacy SmartFill settings modal | `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift` | `REPLACE` | Old modal-level UI does not match the new bounded editor-workspace target. | Replace with workspace-driven grouped controls. |
| Legacy real preview handoff | `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift` | `REPLACE` | Preview orchestration is tied to the old settings/editor arrangement. | Replace with new preview-backed SmartFill workspace. |
| Legacy still preview view model | `STSiPhone/STSiPhone/Features/Editing/SmartFillStillPreviewViewModel.swift` | `REFERENCE_ONLY` | Useful to understand earlier preview state handling, but not a durable flagship seam. | Read for behavior notes only. |
| Global SmartFill settings screen | `STSiPhone/STSiPhone/Features/Settings/SmartFillSettingsView.swift` | `REPLACE` | Global settings remain necessary, but this screen should stop acting like the main editing surface. | Keep the role, replace the structure and vocabulary. |
| Legacy migration dashboard | `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift` | `DELETE_AFTER_CUTOVER` | Migration and dashboard status UI compete with the future editor workspace and confuse SmartFill entry. | Remove after replacement settings/workspace ship. |
| Batch processing view | `STSiPhone/STSiPhone/Features/Settings/Views/SmartFillBatchProcessingView.swift` | `REFERENCE_ONLY` | Shows prior bulk-processing ideas but is not a first-class flagship edit flow. | Keep only as support archaeology until bulk processing is intentionally redesigned. |
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
- `STSiPhone/STSiPhone/Features/Editing/Tools/SmartFillController.swift`

## Duplicate Or Obsolete UI Surfaces To Remove After Cutover
- `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
- `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
- `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift`

These should not survive once the new SmartFill workspace is live and launched from project/session/take review.

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
