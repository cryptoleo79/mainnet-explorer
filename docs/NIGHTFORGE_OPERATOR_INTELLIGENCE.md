# NightForge Operator Intelligence — Indexer / API Audit

**Scope:** API + indexer intelligence only. What real data NightForge already has but is not surfacing, what is broken, and what is genuinely worth building.
**Date:** 2026-06-03
**Method:** Live GraphQL schema introspection + signal/noise checks against `https://indexer.mainnet.midnight.network/api/v4/graphql` (verified this session), plus a 4-agent read-only audit of `mainnet-explorer/src/api/server.ts` (3131 lines, 71 route handlers), `src/indexer/{indexer,database}.ts`, the front-end (`index.html`, `tools/*.html`, `website/*.html`), and `docs/`.
**Constraints honored:** research only — no code, no deploy, no install, no backend/frontend/wallet edits. Every "available" claim below is marked **LIVE-VERIFIED** (probed the live indexer this session) or **CODE-VERIFIED** (read in source). No speculative claims.

---

## 0. TL;DR — the three things that matter

1. **The governance/decentralization story is real, unique, and usable NOW.** `dParameterHistory` carries two genuine on-chain events — the permissioned-validator cap was raised **10 → 130** (genesis block 0 / block 522886, 2026-04-24), both with **0 registered** (network still fully federated). `termsAndConditionsHistory` carries the genesis T&C (hash `ca85ed77…`, url `midnight.gd/global-terms-txt`). **No other Midnight explorer surfaces governance history at all.** *(LIVE-VERIFIED)*

2. **Two address endpoints are silently broken on mainnet.** Both `/api/address/:address/detail` and `/api/address-summary/:address` issue `transactions(where:… orderBy:… limit:…)`. Mainnet v4 `transactions` accepts **only** `offset:{hash,identifier}` — there is no `where`/`orderBy`/`limit`, no `fees` field, and no address-indexed query at all. Both return zeros/empty for every address and **cannot be repaired with the public indexer alone.** *(LIVE-VERIFIED)*

3. **The cheapest real wins are already in our own SQLite — never exposed.** Top-signers leaderboard (indexed `signer` column), per-block event/extrinsic drill-down, decoded/enriched tx views, and fee/transfer analytics from `balances.*` + `transactionPayment.TransactionFeePaid` event payloads we already store but never parse. *(CODE-VERIFIED)*

Everything `spo*` / `stakeDistribution` / `registered*Series` / `epochPerformance` is **empty on both mainnet and preview** (federated phase) and is **WAIT-for-Mōhalu**, not a build target today. *(LIVE-VERIFIED)*

---

## 1. Full capability inventory

71 route handlers (≈57 distinct paths after alias normalization). Data-source legend: **SQLite** = local indexer DB · **RPC** = node RPC at boot · **GraphQL** = live v4 indexer · **computed** = formula · **static** = hardcoded.

### By data source
| Source | Count | Representative endpoints |
|---|---|---|
| SQLite-local | ~38 | `/api/stats`, `/api/blocks`, `/api/extrinsics`, `/api/analytics/*`, `/api/committee`, `/api/contracts/*`, `/api/live/*`, `/api/governance`, `/api/epochs` |
| GraphQL-v4 | ~15 | `/api/tx-enriched/:hash`, `/api/block-producers`, `/api/contracts/entrypoints`, `/api/address*/detail`, `/api/dust-status`, `/api/dust-eligibility`, `/api/validators/{directory,performance,liveness}`, `/api/epoch/{current,utilization}`, `/api/governance/{d-parameter,tc-history}`, `/api/credential-gate/liveness` (preview) |
| computed-derived | ~3 | `/api/dust-calculator`, `/api/dust-economics`, parts of `/api/privacy-score` |
| RPC-at-boot | embedded | `/api/network`, `/api/analytics/overview` |
| static | ~5 | `/health`, `/api/docs`, `/api/widget/dust-rate` (hardcoded) |

### Live v4 GraphQL schema — what the indexer actually exposes *(LIVE-VERIFIED via introspection)*
Root query fields and whether NightForge uses them:

| Query field | Returns real data on mainnet today? | Used in server.ts? |
|---|---|---|
| `block`, `transactions`, `contractAction` | ✅ yes | ✅ heavily |
| `dustGenerationStatus` | ✅ yes | ✅ `/api/dust-status` |
| `currentEpochInfo` | ✅ yes (30-min epochs) | ✅ `/api/epoch/current` |
| `epochUtilization` | ⚠️ returns `0.0` (federated) | ✅ `/api/epoch/utilization` |
| `dParameterHistory` | ✅ **2 real entries (10→130)** | ✅ `/api/governance/d-parameter` |
| `termsAndConditionsHistory` | ✅ **1 real genesis entry** | ✅ `/api/governance/tc-history` |
| `committee(epoch)` | ⚠️ empty for current epoch | partial |
| `spoList`, `spoCount`, `spoIdentities`, `spoByPoolId`, `spoCompositeByPoolId` | ❌ **empty** (federated) | partial (directory) |
| `poolMetadata`, `poolMetadataList` | ❌ **empty** | ❌ no |
| `spoPerformanceLatest`, `spoPerformanceBySpoSk`, `epochPerformance` | ❌ **empty** | partial (latest only) |
| `stakeDistribution` | ❌ **empty** | partial (directory) |
| `registeredTotalsSeries`, `registeredSpoSeries`, `registeredPresence`, `registeredFirstValidEpochs` | ❌ **empty** | ❌ no |
| `stakePoolOperators` | ❌ **empty** | ❌ no |

**Per-block headroom not surfaced anywhere** *(LIVE-VERIFIED):*
- `SystemParameters { dParameter, termsAndConditions }` — readable on **every** block (live current governance state without waiting for a change event).
- `block.ledgerParameters` — a decodable hex blob `midnight:ledger-parameters[v5]:…` holding fee/economic ledger params.
- `Transaction { raw, unshieldedCreatedOutputs, unshieldedSpentOutputs, zswapLedgerEvents, dustLedgerEvents }`; `ContractCall { state, zswapState, entryPoint, unshieldedBalances }` — per-contract token balances exist but no top-level "balances by owner" query.

---

## 2. Hidden real capabilities (built, serving, but no front-end consumer)

25 registered endpoints have **zero** front-end consumers *(CODE-VERIFIED, agent B grep of all HTML).* Highest-signal, ranked by real value:

| Endpoint | server.ts | Why it matters | Real data today? |
|---|---|---|---|
| `/api/tx-enriched/:hash` | 534 | Flagship: contractActions + unshielded I/O + block author. Generic explorers can't decode Midnight tx semantics. | ✅ GraphQL real |
| `/api/extrinsics/:hash/decoded` | 462 | Decoded Midnight extrinsic view. | ✅ local + decoder |
| `/api/blocks/:height/events` & `/extrinsics` | 428, 311 | Per-block drill-down — events & extrinsics inside a block. | ✅ local |
| `/api/midnight-txs` | 675 | Recent classified shielded/unshielded/mixed tx feed. | ✅ local |
| `/api/analytics/tx-classification` | 642 | Shielded/unshielded/mixed breakdown. | ✅ local |
| `/api/analytics/events` | 860 | Event-type distribution. | ✅ local |
| `/api/analytics/dust` | 1197 | DUST/fee event series — not on any DUST tool. | ✅ local |
| `/api/governance` | 1240 | Governance overview. | ✅ local |
| `/api/governance/tc-history` | 3055 | T&C change log (genesis entry real). | ✅ GraphQL real |
| `/api/epochs` | 1250 | Epoch history/timeline. | ✅ local |
| `/api/epoch/utilization` | 2852 | Per-epoch utilization (⚠️ flatlines at 0 federated). | ⚠️ federated zeros |
| `/api/live/dust-rate`, `/api/live/shielded-rate` | 2962, 3003 | Per-minute live streams (only the static SVG widget is shown). | ✅ local |
| `/api/address/:address` (local) | 1272 | Address activity from local index — **this one works**, unlike the GraphQL `/detail`. | ✅ local |
| `/api/extrinsics/stats` | 537 | Extrinsic success/fail totals (⚠️ `success` never written — see §3). | ⚠️ partial |
| `/api/validators/performance` | 2683 | SPO performance (⚠️ empty federated). | ❌ federated empty |

**Orphaned tool pages** *(CODE-VERIFIED):* `tools/dust-calc.html`, `tools/dust-status.html`, `tools/dust-economics.html` are stale pre-consolidation leftovers (superseded by `dust-console.html`), unlinked from `tools/index.html`. `tools/passport-ready.html` is reachable (linked from `contracts.html:628`) but missing from the tools hub.

---

## 3. Invalid / broken assumptions (verified)

| # | Assumption baked into code | Reality | Evidence |
|---|---|---|---|
| 1 | `Transaction.fees { paidFees }` is queryable | **No `fees` field on mainnet v4 Transaction.** | LIVE introspection; `server.ts:1326` |
| 2 | `transactions(where:… orderBy:… limit:…)` filters by address | **Mainnet `transactions` accepts only `offset:{hash,identifier}`.** No `where`/`orderBy`/`limit`; no address-indexed query exists. | LIVE introspection (`TransactionOffset` inputFields = `hash,identifier`); `server.ts:1318, 1420` |
| 3 | `/api/address/:address/detail` returns balances | **Returns all-zeros for every address** (query errors → `txs=[]`). Cannot be fixed with public indexer. | Derives from #1+#2; `server.ts:1307-1377` |
| 4 | `/api/address-summary/:address` works | **Also broken on mainnet** — same invalid `where/orderBy/limit`, plus selects `timestamp` directly on Transaction (it lives under `block`). | `server.ts:1420-1432` (corrects an earlier "summary works" read) |
| 5 | `/api/validators` lists validators | **Always returns `[]`.** The `validators` SQLite table is **never written** (no `INSERT INTO validators` anywhere). Documented at `server.ts:1864`. | CODE-VERIFIED; `database.ts:55-62` |
| 6 | `extrinsics.success` enables failed-tx intelligence | **Column never bound** by `insertExtrinsic` → always defaults `1`. No failed-tx data from local store. | `database.ts:160-182` |
| 7 | `epoch_info.committee` holds committee | **Never written**; committee comes from extrinsic args instead. | `indexer.ts:298-323` |
| 8 | SPO/stake/performance widgets can be built | **Empty on mainnet AND preview** (`spoCount=0`). Federated phase. | LIVE-VERIFIED both hosts |

**Trustworthy by contrast:** committee identity is **real**, sourced from the latest `sessionCommitteeManagement.set` extrinsic args via RPC (`getCommitteeMembers`, `database.ts:676-734`), de-duplicated per validator and correctly flagged `federated:true`. `/api/validators/liveness` is a real hybrid (real committee × live block authors from GraphQL). `epoch_info` Cardano-anchor data is real (`sidechain_getStatus`).

---

## 4. Untapped data sources (real, populated, already ours — zero new indexing)

*(CODE-VERIFIED — all live in our SQLite right now)*

1. **`extrinsics.signer`** — populated and **indexed** (`database.ts:83`) but only ever exact-matched. A `GROUP BY signer ORDER BY COUNT(*)` yields a **most-active-accounts leaderboard** for free.
2. **`balances.*` + `transactionPayment.TransactionFeePaid` event `.data`** — captured for every block, parsed for nothing. Enables **fee-collected-over-time** and **transfer-flow** analytics.
3. **`events.extrinsic_index`** — populated; lets a tx/block detail view show "events emitted by this extrinsic." Used only internally for dedupe today.
4. **`extrinsics.args` (full JSON)** — stored for every call; decoded for only 3 call types. A generic "decoded extrinsic args" view is buildable from local data.
5. **`block.state_root` / `extrinsics_root`** — captured, leak via `SELECT *`, never presented as block metadata.
6. **`SystemParameters{dParameter,termsAndConditions}` per block** *(LIVE-VERIFIED)* — live "current governance state" without waiting for a change event.
7. **`ledgerParameters` hex blob** *(LIVE-VERIFIED)* — decodable fee/economic params; gated only on writing a decoder.

---

## 5. Operator opportunities

- **Validator liveness pulse** (already real at `/api/validators/liveness`) — the single best operator signal today: who's producing, who's silent, last-seen age. Surface it more prominently; it bypasses the dead `validators` table entirely.
- **Failed-extrinsic / health rate** — requires binding `success` from the `system.ExtrinsicFailed` events we already store. Gives operators a real "is the chain healthy / are my txs landing" signal generic explorers lack.
- **Committee composition + Nakamoto coefficient** (real, RPC-sourced) — honest "federated phase, 10→130 permissioned cap" framing is itself a credibility differentiator.
- **Epoch progress** (`currentEpochInfo`, real) — 30-min epoch countdown; useful operator cadence anchor.

## 6. Developer opportunities

- **Enriched/decoded tx endpoints already exist** (`/api/tx-enriched/:hash`, `/api/extrinsics/:hash/decoded`) — Midnight-aware decode (contractActions, unshielded I/O) is the thing a generic explorer can't do. They are built and **dark**; exposing them is the highest dev-facing leverage.
- **Contract entry-point inspector** (`/api/contracts/entrypoints`, real GraphQL) — resolves circuit names; genuinely useful for Compact developers.
- **Embeddable widgets** (`/api/widget/*`) — block-height and privacy-score badges are real; the `dust-rate` badge is **hardcoded static** and should be flagged as not-live before promotion.
- **Per-block drill-down** (`/blocks/:height/events|extrinsics`) — standard dev affordance, built, dark.

## 7. Governance opportunities (the differentiator)

- **D-parameter timeline** — 2 real dated on-chain events (10/0 → 130/0). Present as an audit-grade decentralization timeline. *(LIVE-VERIFIED)*
- **T&C compliance memory** — record *when* chain-governing terms changed and snapshot the document body so the human-readable record survives URL link-rot; on-chain hash is the verifier. *(design exists: `docs/GOVERNANCE_MEMORY_DESIGN.md`)*
- **Registration crossover watch** — pre-wire the moment `numRegisteredCandidates` first goes non-zero (the visible signal of permissionless participation). The display surface is already wired to light up; **no card may claim registered validators until the value is non-zero.**
- **Live current-governance-state** from `SystemParameters` per block — unexploited NOW headroom.

---

## 8. Top 10 ranked opportunities

> Each: **data source · user value · risk · effort · recommendation**. Recommendations use DO NOW / PLAN / WAIT / DO NOT DO. (No implementation here — research only.)

**1. Surface the governance/d-parameter + T&C timeline more prominently**
- **Data:** `dParameterHistory`, `termsAndConditionsHistory` — LIVE-VERIFIED real (10→130; genesis T&C). Endpoints already wired (`server.ts:2895, 3055`).
- **Value:** The one thing no other Midnight explorer has. Audit-grade decentralization narrative.
- **Risk:** Low — real, chain-anchored, independently reproducible. Must keep honest "0 registered / federated" framing.
- **Effort:** Low (data + endpoints exist; presentation only).
- **Recommendation:** **DO NOW** (research/design surfacing; build is a separate approved step).

**2. Fix or retire the broken address endpoints**
- **Data:** `/api/address/:address/detail` + `/api/address-summary/:address` — LIVE-VERIFIED broken (invalid `where/orderBy/limit`, no `fees`, no address-indexed query on mainnet v4).
- **Value:** Currently return zeros → actively misleading. The working `/api/address/:address` (local SQLite) should be the canonical address surface.
- **Risk:** High to leave as-is (false data). Cannot be repaired from the public indexer.
- **Effort:** Low to retire/redirect to the local endpoint.
- **Recommendation:** **DO NOW** (decision: retire the two GraphQL address endpoints or hard-mark them degraded; route address UX to the local one). *No edit performed in this pass.*

**3. Top-signers / most-active-accounts leaderboard**
- **Data:** `extrinsics.signer` — CODE-VERIFIED populated + indexed.
- **Value:** "Who's active on Midnight" — a real explorer staple, zero new indexing.
- **Risk:** Low.
- **Effort:** Low (one indexed `GROUP BY`).
- **Recommendation:** **PLAN** (clean, high-value, additive).

**4. Failed-extrinsic / tx success-rate intelligence**
- **Data:** `system.ExtrinsicSuccess`/`ExtrinsicFailed` events (already stored) → bind `extrinsics.success`.
- **Value:** Real chain-health signal; "are txs landing." Generic RPC explorers don't compute it.
- **Risk:** Medium — requires an indexer change to correlate events back to extrinsics (data already captured, logic missing).
- **Effort:** Medium.
- **Recommendation:** **PLAN**.

**5. Expose the enriched/decoded transaction views**
- **Data:** `/api/tx-enriched/:hash` (GraphQL real), `/api/extrinsics/:hash/decoded` (local) — CODE-VERIFIED built, dark.
- **Value:** Midnight-aware tx semantics — the core dev/analyst differentiator.
- **Risk:** Low (endpoints exist and return real data).
- **Effort:** Low–medium (front-end only).
- **Recommendation:** **PLAN**.

**6. Fee / transfer-flow analytics from stored event payloads**
- **Data:** `balances.*`, `transactionPayment.TransactionFeePaid` event `.data` — CODE-VERIFIED captured, unparsed.
- **Value:** Real economic activity view without new capture.
- **Risk:** Low–medium (must verify which methods are populated on mainnet before claiming).
- **Effort:** Medium.
- **Recommendation:** **PLAN** (verify population first).

**7. Per-block drill-down (events + extrinsics inside a block)**
- **Data:** `/api/blocks/:height/events|extrinsics` — CODE-VERIFIED built, dark.
- **Value:** Standard explorer depth that's currently invisible.
- **Risk:** Low.
- **Effort:** Low (front-end only).
- **Recommendation:** **PLAN**.

**8. Live current-governance-state from `SystemParameters` per block**
- **Data:** `SystemParameters{dParameter,termsAndConditions}` — LIVE-VERIFIED readable every block; not surfaced.
- **Value:** Real-time "current decentralization parameters," complements the historical timeline.
- **Risk:** Low.
- **Effort:** Medium (new read path).
- **Recommendation:** **PLAN**.

**9. `ledgerParameters` fee-economics panel**
- **Data:** `block.ledgerParameters` hex blob (`…[v5]`) — LIVE-VERIFIED present + decodable; not decoded anywhere.
- **Value:** Real DUST/fee economic params straight from chain — strong for the DUST console.
- **Risk:** Medium — requires a decoder for the binary format; must not present guessed field meanings (no speculation).
- **Effort:** High (reverse/confirm the encoding).
- **Recommendation:** **PLAN** (spike a decoder; gate on confirmed field semantics).

**10. SPO directory / validator-performance / stake-distribution cards**
- **Data:** `spoList`, `spoCount`, `stakeDistribution`, `spoPerformanceLatest/BySpoSk`, `epochPerformance`, `registered*Series` — LIVE-VERIFIED **empty on mainnet AND preview**.
- **Value:** High — but only once data exists (post-Mōhalu, permissionless validators, mid-2026).
- **Risk:** High to build now — renders blank/fake; empty-widget theater.
- **Effort:** Medium when data arrives; surfaces partially pre-wired and degrade honestly today.
- **Recommendation:** **WAIT-for-Mōhalu** (keep honest "federated phase" empty states; do not build cards that imply registered validators exist).

---

## 9. Action ledger

**DO NOW** (decisions/design only this pass — no code edits made)
- Plan to surface the governance d-parameter + T&C timeline more prominently (real data, endpoints live). *(#1)*
- Decide the fate of the two broken GraphQL address endpoints — retire or hard-mark degraded; route address UX to the working local `/api/address/:address`. *(#2)*

**PLAN** (additive, real data, build behind approval)
- Top-signers leaderboard *(#3)* · failed-tx rate *(#4)* · expose enriched/decoded tx views *(#5)* · fee/transfer analytics *(#6)* · per-block drill-down *(#7)* · live `SystemParameters` state *(#8)* · `ledgerParameters` decoder spike *(#9)*.
- Re-link `tools/passport-ready.html` from the tools hub; delete or redirect the 3 orphaned DUST pages.

**WAIT**
- All `spo*` / `stakeDistribution` / `registered*Series` / `epochPerformance` cards → until Mōhalu populates SPO data *(#10)*.
- `epochUtilization` widget → returns `0.0` federated; would flatline.
- Registration-crossover card → light up only when `numRegisteredCandidates > 0`.

**DO NOT DO**
- Chase tx/block chart parity with midnightexplorer.com (RPC-only, already does charts; not our edge).
- Build any SPO/validator-performance widget that implies registered validators exist today (data is empty on all hosts).
- Present `ledgerParameters` field meanings without a confirmed decoder (no speculation).
- "Repair" the address GraphQL endpoints by tweaking the query — mainnet v4 has no address-indexed transaction query; the fix is to retire, not patch.

---

*Sources: live introspection of `indexer.mainnet.midnight.network/api/v4/graphql` and `indexer.preview.midnight.network/api/v4/graphql` (2026-06-03); `mainnet-explorer/src/api/server.ts`, `src/indexer/{indexer,database}.ts`, `index.html`, `tools/*.html`, `website/*.html`; `docs/{UPGRADE_RADAR,GOVERNANCE_MEMORY_DESIGN,ECOSYSTEM_WAKEUP_PLAN,REPO_TOPOLOGY}.md`. Claims tagged LIVE-VERIFIED were probed against the live indexer this session; CODE-VERIFIED were read in source.*
