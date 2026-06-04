# Wave 1 — Release-Candidate Review

**Question answered:** *Is Wave 1 ready?*
**Verdict:** ✅ **YES — ready for mainnet deployment.** The one RC issue (cosmetic d-parameter duplication) is now **fixed** — see "Post-review fix" below.

**Branch:** `feat/operator-intel-wave1` · **Commit reviewed:** `7ad1593` (+ dedupe fix) · **Worktree:** `/home/midnight/mainnet-explorer-wave1`
**Date:** 2026-06-03 · **Reviewer scope:** deploy-readiness only. No new features, no Wave 2.

---

## What shipped
- **api** `GET /api/analytics/tx-health` — TxApplied vs TxPartialSuccess from local SQLite (60s cache).
- **api** `GET /api/governance/current-state` — live `SystemParameters` (d-param + T&C) via `queryIndexer()` (60s cache + last-cache fallback).
- **api/truth** `GET /api/address/:address/detail` and `/api/address-summary/:address` retired to honest `HTTP 501` (no more fabricated zeros).
- **tools** `tools/tx-inspector.html` (new) — enriched tx view + decoded extrinsic + per-block drill-down + tx-health strip.
- **web** `website/nightforge-main.html` — Governance tab: live-state, tx-health, T&C memory, d-param timeline (10→130); en+ja i18n.
- **tools** `tools/validators.html` — Federation & Governance card + d-param timeline; fixed a latent bug (old card read wrong fields, showed `--`).
- **tools** `tools/index.html` — links Transaction Inspector. *(Passport-Ready card cut pre-merge — see "Post-review fix #2": it is a YAMORI/credential standards-alignment explainer mixing live + future capability, not NightForge operator intelligence; reverted to its pre-Wave-1 reachability from contracts.html only.)*

Diffstat vs `be4e4ec`: 6 files, +1365 / −172.

---

## Item-by-item verdict

### 1. Governance timeline / current-state — ✅ PASS *(was CONDITIONAL; fixed)*
- Real data confirmed live: `current-state` → block 1,099,178, **130 permissioned / 0 registered**, T&C `ca85ed77…` + `midnight.gd/global-terms-txt`. `d-parameter` history = genesis 10/0 → block 522886 130/0. Values 100% data-driven; `0 registered` rendered red as "fully federated" (honest).
- **Duplication resolved:** the redundant `dparamCard` in `tools/validators.html` was removed. D-parameter now appears as two *distinct* views only — the live snapshot tile (`govLivePerm`, fed by `current-state`) and the history timeline (fed by `d-parameter` history) — no repeated surface. The cross-page appearance (homepage Governance tab vs validators tool) is acceptable tiering (summary vs detail).

### 2. Tx-health rate — ✅ PASS
- Real data: `TxApplied=179594`, `TxPartialSuccess=8696` (~4.62% partial-fail). `recentPartial` returns real txHashes (e.g. `0x21b2d910…`@1086404).
- Latency: count query **32 ms**, recent query **15 ms** (uses `idx_events_section_method`). Cached 60s.
- Failure: handler `try/catch` → 500 with message; FE shows "tx-health endpoint not available" + `—` gracefully.

### 3. Tx-inspector — ✅ PASS
- Uses only real, working endpoints (`/tx-enriched`, `/extrinsics/:hash/decoded`, `/blocks/:h/{extrinsics,events}`, `/analytics/tx-health`).
- Loading state ("Inspecting transaction…"), empty states ("No contract actions", "No unshielded UTXOs", "No decoded extrinsic"), error states, null→`—`, input validation ("Enter a transaction hash").
- Honest note that mainnet is quiet (many blocks have 0 tx) and that decode is keyed by extrinsic hash.
- Responsive: `@media 900px` (4→2 col) and `600px` (→1 col). Viewport meta present.

### 4. Per-block drill-down — ✅ PASS
- In tx-inspector: block-height mode fetches `/api/blocks/:h/extrinsics` + `/events`, renders two tables; extrinsic hashes click back into tx mode. Real local data.

### 5. Honest handling of broken address endpoints — ✅ PASS
- Both `/detail` and `/summary` confirmed in source to return `501 { error, reason, alternative:'/api/address/:address (local activity)' }`. **No zero-fabrication path remains.** Unused `addressSummaryCache` removed.

---

## Cross-cutting checks

| Check | Verdict | Notes |
|---|---|---|
| Real data only | ✅ PASS | Every value traced to a real source; live-verified. |
| No fake values | ✅ PASS | No hardcoded data literals (the "87171" was the color `#f87171`). |
| No empty widgets | ✅ PASS | All endpoints return real data on the mainnet target; missing-endpoint cases degrade to honest "unavailable", not blank boxes. |
| No duplicated surfaces | ✅ PASS | `validators.html` dedupe applied — redundant `dparamCard` removed. |
| Mobile layout | ✅ PASS | Media queries collapse grids; viewport meta on all pages. |
| Desktop layout | ✅ PASS | Cards reuse existing grid/card classes. |
| API latency | ✅ PASS | tx-health 32 ms+15 ms; indexer current-state 184 ms round-trip. |
| Failure behavior | ✅ PASS | Backend try/catch + cache fallback; FE `r.ok ? … : null` + `.catch`. |
| Loading states | ✅ PASS | Spinners/placeholders present. |
| Environment correctness | ⚠️ CONDITIONAL | Tool pages use relative `/api/…` (per-domain nginx → correct env). `current-state` uses `queryIndexer()` hardcoded to the **mainnet** indexer — correct for the mainnet deploy and consistent with all existing GraphQL endpoints (d-parameter, dust-status, etc.). Not a Wave-1 regression. |
| Preview/mainnet separation | ⚠️ CONDITIONAL | If tool pages are propagated to preprod/preview docroots, those environments' Express must carry the new endpoints (or rely on graceful degradation), and their `queryIndexer` must point at their own indexer — same pre-existing per-env config the deploy script already handles. |

---

## What should be cut
- **Done:** the redundant simple `dparamCard` in `tools/validators.html` was removed (post-review dedupe fix).
- Nothing else. Noise was already cut pre-build: top-signers (12 signers), fee analytics (no fee events).

## What should wait
- SPO directory / validator-performance / stake-distribution cards, `epochUtilization` widget, registration-crossover card — empty on mainnet **and** preview (federated). Hold for Mōhalu. Surfaces stay pre-wired to light up automatically. **Not in Wave 1.**

## Quality / build evidence
- Parse: `node --experimental-strip-types --check` → both TS files OK (tsx type-strips in prod).
- Build: `tsc --noEmit` (temp deps symlink, no install) → **0 errors** project-wide.
- Isolation: live service working tree clean throughout; worktree-only.

---

## Deployment recommendation

**Deploy Wave 1 to mainnet — APPROVED.** All five reviewed items PASS (the one conditional is now fixed). Real signal only; no fake data; no empty widgets; no duplicated surfaces; honest 501s.

Environment notes (pre-existing patterns, action for the deploy step, not blockers): build with `npm run build` (tsc, 0 errors) then `scripts/deploy-all.sh`; ensure preprod/preview backends carry the new endpoints if their tool pages are updated, else they degrade honestly.

- **Pushed: NO**
- **Deploy needed: YES** (changes live only on the branch).
- **Blocking failures: NONE.**
