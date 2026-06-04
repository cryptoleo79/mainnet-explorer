# Wave 1 — Post-Deploy Verification

**Verified:** 2026-06-04 ~05:30 UTC · **Deployed commit:** `e174abf` (`main`) · **Service:** `midnight-mainnet-indexer.service` active since 2026-06-04 05:01 UTC.
**Result:** ✅ **ALL PASS** on Wave 1 deploy targets (apex + mainnet). Read-only verification; no build, no code change, no deploy.

## Deploy scope (by design — mainnet-first)
Wave 1 backend + tool pages live on **apex (`nightforge.jp`)** and **`mainnet.nightforge.jp`** (both served by the mainnet service on :3005). **preprod (:3004)** and **preview (:3000)** run separate services from separate repos and intentionally do **not** carry Wave 1 yet — their new-endpoint 404s and `tx-inspector` 404s are the *correct* outcome (no preview/mainnet bleed).

## PASS/FAIL matrix

| Check | apex | mainnet | preprod | preview | Verdict |
|---|---|---|---|---|---|
| `/api/governance/current-state` | 200 | 200 | 404* | 404* | ✅ PASS |
| `/api/analytics/tx-health` | 200 | 200 | 404* | 404* | ✅ PASS |
| `/api/governance/d-parameter` | 200 | 200 | 404* | 404* | ✅ PASS |
| `/api/address/:a/detail` → honest 501 | 501 | 501 | 200† | 200† | ✅ PASS (targets) |
| `/api/address-summary/:a` → honest 501 | 501 | 501 | 502† | 200† | ✅ PASS (targets) |
| `/tools/tx-inspector.html` | 200 | 200 | 404* | 404* | ✅ PASS |
| `/tools/` hub | 200 | 200 | 200 | 200 | ✅ PASS |
| homepage `/` | 200 | 200 | 200 | 200 | ✅ PASS |

`*` = Wave 1 intentionally absent on preprod/preview (mainnet-first). `†` = preprod/preview still run the **pre-Wave-1** address endpoints (see "Known residual").

## The 9 functional checks (Wave 1 targets)
1. **Governance timeline** ✅ — `d-parameter` returns 2 real entries `[(130,0),(10,0)]` (permissioned cap raised 10→130); deployed homepage carries the new `loadGovernanceFederation` wiring (not stale).
2. **Governance current-state** ✅ — live: block 1,107,214, `dParameter {130, 0}`, T&C `ca85ed77…`.
3. **Tx-health** ✅ — live: `{applied:179602, partialSuccess:8696, total:188298, partialRatePct:4.62}`, 10 real `recentPartial` txHashes.
4. **Tx-inspector** ✅ — page 200; header-nav present; wires `tx-enriched` + per-block drill-down + tx-health strip.
5. **Address detail/summary** ✅ — both return honest **501** (`alternative:/api/address/:address`); no fabricated zeros.
6. **No preview/mainnet bleed** ✅ — preview uses env-relative `"/api/"+__NF_NET`; preview `current-state` returns a 404 page, **not** mainnet's `130/0`.
7. **No fake values** ✅ — every surfaced number traced to a live source (tx counts advancing across runs; 130/0; real T&C hash).
8. **No broken nav** ✅ — tools hub links Transaction Inspector; **Passport-Ready not linked** (cut confirmed live); tx-inspector header-nav intact.
9. **Mobile usable** ✅ — viewport meta + responsive `@media` breakpoints present.

## Latency (public, end-to-end)
`tx-health` / `d-parameter` ~10 ms; `current-state` ~0.43–0.53 s (live v4 indexer round-trip, 60 s cached). All within budget.

## Failures found
**None** on Wave 1 deploy targets.

## Known residual (not a Wave 1 failure — tracked, no action this pass)
preprod and preview still serve the **old** address endpoints (Wave 1's honest-501 fix is not deployed there): `detail` returns 200, `address-summary` returns 200 (preview) / 502 (preprod, the old broken GraphQL erroring). These are pre-existing behaviors on separate environments; they resolve if/when Wave 1 is propagated to preprod/preview (a separate, future decision — out of scope here).

## Rollback
**Not required.** Wave 1 is healthy on its targets; data is real; no bleed; nav and mobile intact.

---
*Verification method: HTTP matrix + payload inspection + deployed-content greps across `nightforge.jp`, `mainnet.nightforge.jp`, `preprod.nightforge.jp`, `preview.nightforge.jp`. No code changed, nothing built or deployed.*
