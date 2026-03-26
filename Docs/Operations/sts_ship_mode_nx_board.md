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

## Board State (2026-03-25)
- Shipped shell truth comes from `/Users/kevinbarrett/Dev/SelfTapeStudio` and is read-only.
- Writable flagship integration truth lives in `/Users/kevinbarrett/Dev/itFactor_1.23.26_git`.
- Remote rebuild truth lives at `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`.
- The first two rebuild slices are locally gated:
  - legacy audit
  - standalone derivation ledger
  - SmartFill bridge/coordinator scaffolding
  - focused parity coverage
- Review/player SmartFill launch now enters the rebuild workspace from `ProjectDetailView`.
- `authority/main` now exists remotely and locally at the untouched Jan 23 baseline.

---

## Completed Ledger
| Priority | ID | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| 0 | SF-REBUILD-001 | Legacy SmartFill audit + standalone derivation ledger + bridge/coordinator scaffold | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_rebuild_gateA_final.log`; focused parity PASS `/tmp/itfactor_smartfill_rebuild_tests_final2.log` |
| 0A | SF-REBUILD-002 | Repo bootstrap truth (`origin` + `authority/main` + promotion path) | COMPLETE | Remote `git@github.com:KevinBarrett2025/itfactor-smartfill-rebuild.git`; `origin/main` and `origin/authority/main` now point to baseline `94883522cfa9a76c6fd779de8bac2afe5a4bb79b` |
| 1 | SF-REBUILD-003 | Review/player launch into `SmartFillSessionContext` + rebuild workspace entry | COMPLETE (LOCAL-GATED) | Gate A PASS `/tmp/itfactor_smartfill_phase2_gateA.log`; focused parity PASS `/tmp/itfactor_smartfill_phase2_tests.log` |

---

## Active / Pending Queue
| Priority | ID | Description | Status | Notes |
| --- | --- | --- | --- | --- |
| 2 | SF-REBUILD-004 | Replace legacy SmartFill settings/editor surfaces with one bounded workspace | OPEN | Initial `SmartFillWorkspaceView` landed; broader cutover still required |
| 3 | SF-REBUILD-005 | Adopt SmartFill result back into repository/take/session truth | OPEN | Route through `ProjectsRepository` + SQLite |
| 4 | SF-REBUILD-006 | Delete or retire duplicate legacy SmartFill UI surfaces after cutover | OPEN | `DELETE_AFTER_CUTOVER` items only after replacement ships |
| 5 | SF-REBUILD-007 | Standalone utility extraction package from flagship architecture | OPEN | Hidden static session derivation |

---

## Guardrails
- No code changes are allowed in `/Users/kevinbarrett/Dev/SelfTapeStudio`.
- Legacy SmartFill persistence fields are protected and must survive the rebuild.
- The standalone utility must be derived from flagship architecture, not designed as a competing shell.
- No direct promotion to `authority/main` is allowed from GM work. Promotion must follow `gm/* -> promo/* -> authority/main`.

---

## Next Action
1. Commit and push the review/player launch slice on `gm/smartfill-itfactor-rebuild`.
2. Route workspace completion back into repository/take/session truth.
3. Continue replacing legacy settings/editor UI with the bounded rebuild workspace.
