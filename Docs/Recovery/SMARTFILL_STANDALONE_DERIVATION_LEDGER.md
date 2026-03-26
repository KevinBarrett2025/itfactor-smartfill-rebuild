# SmartFill Standalone Derivation Ledger

Date: 2026-03-25
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
The flagship rebuild now has a real SmartFill entry seam:
- `ProjectDetailView` bypasses the legacy `SmartFillSettingsModal` on the review/player sheet path.
- `SmartFillWorkspaceView` owns the new grouped workspace entry experience.
- `SmartFillTakeBridge` now round-trips settings between take snapshots and rebuild workspace settings.
- `SmartFillResultBridge` now adopts SmartFill output through repository truth and creates or refreshes one authoritative standalone SmartFill variant take.
- `SmartFillProcessingManager` completion notifications now preserve the queued take ID for review listeners while also carrying the adopted SmartFill take ID for reopen routing.

This means the future standalone utility already has a clear derivation path:
1. import one clip
2. create or reuse a hidden static `SmartFillSessionContext`
3. open the same `SmartFillWorkspaceView`-style editor scene
4. write result history/export data through a utility-local result bridge that mirrors repository adoption without project/session vocabulary

## Current Next Step
Replace the remaining legacy SmartFill settings/editor shells in flagship itFactor so the future standalone utility can extract the same workspace model with only a hidden static-session shell and lightweight persistence swap.
