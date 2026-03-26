# STS · SmartFill Rebuild Full Catalog

_Last updated:_ 2026-03-25

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
| SF-REBUILD-004 | Bounded SmartFill workspace replacement inside itFactor shell | OPEN | Initial `SmartFillWorkspaceView` landed through the review/player launch path; broader duplicate settings/preview surface cutover is still pending |
| SF-REBUILD-005 | SmartFill result adoption bridge into repository/take/session truth | OPEN | Route through `ProjectsRepository`, `SQLiteProjectsRepository`, and SmartFill variant helpers |
| SF-REBUILD-006 | Legacy SmartFill cutover cleanup | OPEN | Delete or retire `DELETE_AFTER_CUTOVER` seams only after replacement is live |
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
- `STSiPhone/STSiPhone/Features/Settings/SmartFillMigrationDashboard.swift`
- `STSiPhone/STSiPhone/Features/Editing/SmartFillSettingsModal.swift`
- `STSiPhone/STSiPhone/Features/Editing/SmartFillRealPreviewSectionHandoff.swift`

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
1. Commit and push the review/player launch slice.
2. Complete SmartFill result adoption through repository/take/session truth.
3. Continue replacing duplicate legacy settings/editor surfaces with the bounded workspace.
4. Keep standalone derivation synchronized in every phase.
