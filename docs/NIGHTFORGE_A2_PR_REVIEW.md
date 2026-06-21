# NightForge A2 — PR Readiness Review

Branch: `fix/nightforge-contract-interactions` (HEAD `0484657`). Reviews the `interactions:0` truth fix for merge readiness. No merge, no deploy, no DUST work, no YAMORI.

## Verdict: **PASS** (with one documented caveat — owner decision below)

The fix is correct, truthful, and strictly better than the shipping lie (`interactions:0` for all). It is safe to merge as-is. One pre-existing display artifact (duplicate leaderboard rows) is now *visible* and warrants a yes/no before it fronts a user-facing "Most Active" list.

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

**After (this branch):**
```
totalContracts: 155 | totalCalls: 15310
top 3:  6057 | 2206 | 2206   (events.ContractCall, sorted desc)
distribution (per row): with calls 99 | genuine 0: 56 | null/unknown: 0
zero-check: sampled 0-contract → 0 real call rows  (truly never called ✓)
```

---

## Caveat (pre-existing, now visible) — needs an owner call

**Duplicate `ContractDeploy` rows.** Live: **155 rows, 107 distinct addresses, 48 rows are repeat addresses.** `topContracts` is one row per deploy event, so a contract with multiple deploy events appears **multiple times** in the leaderboard, each row carrying that address's full call count (e.g. `2206` shows twice in the top 3). Consequence: the leaderboard repeats contracts and `Σ interactions` (19,033) over-counts vs `totalCalls` (15,310).

- **Not introduced by this fix** — the old code returned the same duplicate rows; they were just invisible because every value was `0`.
- **Not a truth violation per row** — each row's count is a real, correct per-address tally.
- **But** a user-facing "Most Active" list showing the same contract twice is mildly misleading.

**Options (owner decides — NOT done in this PR, out of stated scope):**
- **(A) Merge as-is, dedupe as a fast follow-up.** The fix is strictly better than the lie today; dedupe is a separate 1-liner.
- **(B) Add a 1-line dedupe before merge** — keep first deploy row per address (e.g. dedupe `topContracts` by `address`). Smallest correct leaderboard.

Recommendation: **(B)** if the leaderboard is imminently user-facing; **(A)** if not. Either way, dedupe is the immediate next step.

---

## Merge readiness
**READY to merge** (criteria all pass; build + typecheck green; no API expansion). Hold only for your decision on the duplicate-row caveat (A vs B). No deploy implied by merge — the change is server-side and takes effect only on a service restart.

*Verification only. Docs committed (this file). Not pushed pending approval.*
