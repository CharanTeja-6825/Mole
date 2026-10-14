# Product synchronization

This is the synchronization entry point for **Mole CLI (macOS)**, branch `main` of `tw93/Mole`. Workflow and the four canonical product names are in [AGENTS.md](AGENTS.md#product-synchronization). Source review baseline: `3fdf4040`, 2026-10-14, Asia/Singapore. This is a source/record review, not a new full runtime audit or a release.

## Ownership

- The two CLIs: the [Windows branch SYNC.md](https://github.com/tw93/Mole/blob/windows/SYNC.md) owns the shared CLI adaptation queue; the macOS entry links to it rather than duplicating rows.
- Mole CLI (macOS) with Mole Mac: the app's root `SYNC.md` owns the detailed comparison.
- Mole CLI (Windows) with Mole for Windows, and the two apps: Mole for Windows' root `SYNC.md` owns the detailed comparison.
- App-owned records remain private. Public CLI records contain public behavior, source and tests only; never copy private catalogs, implementation details, support data or repository links here.

## Current disposition

| Topic | Status | Source and next check |
| --- | --- | --- |
| Log-root traversal and late Git ownership | Implemented | `8811fcbd` and follow-ups `61756c27`, `f5b5a335`, `a5ba6e79`, `1c323dba`; `lib/clean/user.sh` and `lib/clean/caches.sh` recheck roots/ownership. The app-owned comparison must no longer call these unfixed. This record does not re-certify the full test suite. |
| Offline and generated media | Implemented | `b364d17d`, `lib/clean/app_caches.sh`; preserve data that a user cannot regenerate from the cache alone. Windows paths require their own policy review, tracked by CLI-SYNC-01 (Spotify, implemented) and CLI-SYNC-09 (recordings, pending) on `windows`. |
| Uninstall review and configuration references | Implemented | `eb21fff1`, `lib/uninstall/config_refs.sh`; Windows adaptation remains pending, not an instruction to copy macOS paths. |
| Process CPU denominator | Intentional difference | `cmd/status/metrics_process.go` consumes macOS `ps` process CPU; both CLIs use one logical CPU as 100%. Do not divide by machine CPU count just to match a GUI. |
| Unreadable whitelist | Implemented | `clean`, `purge` and `optimize` stop when the whitelist exists but cannot be opened, instead of running as if it were empty; `lib/core/base.sh`, `lib/manage/whitelist.sh`, `tests/manage_whitelist.bats`. |
| APFS clone sizing in `analyze` | Implemented | Clones that share every block count once per clone id, an edited clone counts in full, hardlinks keep the existing dedupe; `cmd/analyze/clone_darwin.go`, cache schema 8. The User Library overview row stays one serial `du` and is clone-unaware by design. |
| Stable `analyze` ordering | Implemented | Equal sizes tie-break by path in lists, large files and the heap; `cmd/analyze/live_scan.go`, `heap.go`. |
| Battery temperature on macOS 27 | Implemented | `cmd/status/metrics_battery.go` falls back to `AppleSmartBatteryPack` when the top-level key is 0. |
| Alibaba Cloud Security, Symantec and Broadcom | Implemented | Official-uninstaller and endpoint-security protection for `com.alibaba.security.`, never-orphan for `com.symantec.*` and `com.broadcom.*`. |
| Wallpaper caches, audio plugin roots, Claude Code temp folders, SwiftPM checkouts | Pending | Each needs a measured value and an explicit non-target list before any cleanup row (AGENTS.md); Claude Code temp folders need a read-only probe first. Next check: probe output from real machines. |
| GUI-only capabilities | Not applicable | Menu/tray, app bulk updates and private leftover catalogs are not CLI parity requirements. |

Delivery: GitHub's latest macOS stable checked on 2026-10-14 is `V1.59.1`; source after that tag must not be called released. Consult the live release and exact commit ancestry before replying to users.
