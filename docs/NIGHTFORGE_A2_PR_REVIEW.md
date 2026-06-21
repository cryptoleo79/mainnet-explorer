# NightForge A2 — PR Readiness Review

Branch: `fix/nightforge-contract-interactions` (HEAD `0484657`). Reviews the `interactions:0` truth fix for merge readiness. No merge, no deploy, no DUST work, no YAMORI.

## Verdict: **PASS** — caveat resolved (dedupe Option B implemented)

The fix is correct, truthful, and strictly better than the shipping lie (`interactions:0` for all). The duplicate-leaderboard-row caveat has been **resolved** by collapsing to one row per contract address (Option B). The leaderboard now reconciles exactly (`Σ interactions == totalCalls`). Ready to merge.

---

## Verification checklist

| Check | Result | Evidence |
|---|---|---|
| Branch based on current `origin/main` | ✅ | `merge-base == origin/main == 0b35951`; linear, no rebase needed |
| No conflicts | ✅ | `git merge-tree` shows no conflict markers |
| Changed files only expected | ✅ | `src/indexer/database.ts` (+29/−3) + `docs/NIGHTFORGE_A2_INTERACTIONS.md`; nothing else |
| No API expansion beyond the fix | ✅ | diff contains **no** `app.get/post/...` route changes; only `getContractAnalytics()` internals |
| Leaderboard/API shows **real** interactions | ✅ | top: 6057, 2206, 1443, 1031, 983 (real, sorted desc) |
| Zero-count contracts truly never-called | ✅ | sampled a `0` contract → 0 real `ContractCall` rows in DB |
| Unknown/unparseable → null, not fake 0 | ✅ | code: `interactions: address ? (agg?.count ?? 0) : null`; live unparseable count = 0 today |
| Build | ✅ | esbuild bundle OK |
| Typecheck | ✅ | `tsc --noEmit`: 0 errors in `database.ts`, 0 repo-wide |

---

## Before / after (live `data/mainnet.db`)

**Before (origin/main):** every contract `interactions: 0` (hardcoded at `database.ts:522`).

**After (this branch, post-dedupe):**
```
totalContracts: 107 | totalCalls: 15315        (one row per address)
top 5:  6057 | 2206 | 1443 | 1033 | 983        (all distinct contracts, sorted desc)
distribution: with calls 70 | genuine 0: 37 | null/unknown: 0
Σ interactions: 15315 == totalCalls 15315       (RECONCILES exactly)
zero-check: sampled 0-contract → 0 real call rows  (truly never called ✓)
```
(`totalCalls` drifts upward between runs because the live indexer keeps advancing — 15301 → 15310 → 15315.)

---

## Caveat — RESOLVED (dedupe Option B implemented)

**Duplicate `ContractDeploy` rows.** Before dedupe: **155 rows, 107 distinct addresses, 48 duplicate rows** — a contract with multiple deploy events appeared multiple times, each row carrying the full per-address count (`2206` showed twice in the top 3), so `Σ interactions` over-counted `totalCalls`.

**Fix (this commit — `getContractAnalytics`):** collapse to **one row per contract address**. Earliest deploy wins `firstSeen`/`block`/`txHash`; `lastSeen` takes the latest activity; per-address `interactions` count is unchanged. **Unknown/unparsed addresses (`interactions === null`) are kept individually** — distinct unknown contracts, never merged. Deterministic sort: interactions desc, address tiebreaker.

| | Before dedupe | After dedupe |
|---|---|---|
| rows | 155 | **107** |
| distinct addresses | 107 | 107 |
| duplicate rows | **48** | **0** |
| Σ interactions vs totalCalls | 19,033 > 15,310 (over-count) | **15,315 == 15,315 (reconciles)** |

No counts altered, no estimates, no API expansion, no new endpoints.

---

## Merge readiness
**READY to merge.** All criteria pass; dedupe applied; build + typecheck green (`tsc` 0 errors); leaderboard reconciles exactly. No deploy implied by merge — server-side change, takes effect on a service restart.

*Verification + dedupe. Docs committed (this file). Pushed with the dedupe commit.*
