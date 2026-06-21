# NightForge A2 — Contract Interactions: Proof & Fix

Fixes the silent truth violation `interactions: 0` hardcoded for every contract (`src/indexer/database.ts`). Goal: prove real per-contract interaction counts exist in local data *before* trusting them. Truth rules: hide if not trustworthy, never substitute estimates, never default to 0 when unknown, prefer "unavailable" over wrong.

**Verified against:** `data/mainnet.db` (live local indexer DB, the path in `src/config.ts:37`). No deploy. No DUST work. No API expansion. No YAMORI.

---

## 1. Source tables

Single table: **`events`** (`src/indexer/database.ts:42`).
```
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  block_height INTEGER NOT NULL,
  block_hash TEXT NOT NULL,
  extrinsic_index INTEGER,
  event_index INTEGER NOT NULL,
  section TEXT NOT NULL,
  method TEXT NOT NULL,
  data TEXT,                 -- double-encoded JSON: ["{...}"]
  timestamp INTEGER NOT NULL,
  ...
);
CREATE INDEX idx_events_section_method ON events(section, method);   -- query is indexed
```
Relevant rows: `section='midnight'` with `method IN ('ContractDeploy','ContractCall')`. Each event's `data` is a JSON array whose `[0]` (string- or object-encoded) holds `{ txHash, contractAddress }`.

Midnight event method counts (live): `ContractCall=15301`, `ContractDeploy=155`, `ContractMaintain=228` (maintenance, intentionally **not** counted as user interactions).

---

## 2. The query (one real query against local data)
```sql
SELECT
  json_extract(json_extract(data, '$[0]'), '$.contractAddress') AS addr,
  COUNT(*) AS cnt,
  MAX(timestamp) AS lastTs
FROM events
WHERE section = 'midnight' AND method = 'ContractCall'
GROUP BY addr;
```
- Double `json_extract` unwraps the double-encoded `data` (`$[0]` → inner JSON → `.contractAddress`). Verified to resolve real addresses for both string- and object-encoded `[0]`.
- SQLite JSON1 is compiled into `better-sqlite3` by default; confirmed working on the live DB.
- Per-contract `interactions` = its row in this aggregate; `lastSeen` = `MAX(timestamp)` of its calls.

**Count rule:** `interactions = address ? (callCount ?? 0) : null`.
- Real number when the deploy address parsed.
- `0` **only** when the address parsed but the aggregate has no calls (genuinely never called — true).
- `null` when the deploy address itself can't be parsed (unknown — never a fabricated `0`).

---

## 3. Sample rows (5 real contracts, live DB)

| contract (addr, truncated) | interactions | last_call (UTC) |
|---|---|---|
| `0x6d69…636f6e7472…` | **6057** | 2026-06-17 17:53:48 |
| `0x6d69…636f6e7472…` | **2206** | 2026-06-19 16:13:06 |
| `0x6d69…636f6e7472…` | **1443** | 2026-06-17 17:50:48 |
| `0x6d69…636f6e7472…` | **1031** | 2026-06-17 17:36:00 |
| `0x6d69…636f6e7472…` | **983** | 2026-06-14 07:42:48 |

Real, non-uniform distribution with real recency. `Σ interactions = totalCalls = 15301` (reconciles).

---

## 4. Edge cases (measured, not assumed)

| Case | Count | Handling |
|---|---|---|
| (a) Deployed addresses with **zero** calls | **37 distinct** | `interactions: 0` — truthful (deployed, never called). |
| (b) `ContractCall` events with **unparseable** address | **0** | Would extract to `null` and be excluded from counts; none exist today. |
| (c) **Duplicate** `ContractDeploy` rows for the same address | **48** | Pre-existing data trait; see note below. |

**Granularity note (so the numbers reconcile):** `topContracts` has one row per `ContractDeploy` event (155 rows), but only ~107 distinct addresses (48 are duplicate deploys). Hence two truthful views:
- **Row-level** (what the endpoint returns): 155 rows → 99 map to a called address, 56 to an uncalled address.
- **Address-level** (distinct): 70 distinct addresses called, 37 distinct never called.
Both are correct at their granularity. The duplicate-deploy rows mean a contract can appear more than once in `topContracts` — **pre-existing**, not introduced by this fix; de-duping deploy rows is a separate follow-up, intentionally out of A2 scope.

---

## 5. Confidence: **HIGH**

- Data exists, is local, indexed, and reconciles (`Σ = 15301`).
- Zero unparseable call addresses → no silent loss.
- Zeros are genuine (deployed-but-uncalled), not unknowns.
- Unknown deploy addresses map to `null`, never `0`.
- No estimate, no guessed constant anywhere in the path.

→ Proceed to implement (high-confidence branch).

---

## 6. Implementation plan (and status)

In `getContractAnalytics()` (`src/indexer/database.ts`):
1. Add the §2 aggregate query; build a `Map<address,{count,lastTs}>`.
2. Per deployed contract: `interactions = address ? (agg?.count ?? 0) : null`; `lastSeen = max(deployTs, agg.lastTs)`; add `interactionsSource: 'events.ContractCall'` provenance.
3. Sort `topContracts` by `interactions` desc (null sinks last) so "Most Active" is genuinely most active.
4. No new endpoint, no shape removal — only the previously-fake field becomes real + a provenance field.

**Status: IMPLEMENTED** on branch `fix/nightforge-contract-interactions`, commit **`e15a249`** *("data: derive contract interactions from events"* — `indexer:` scope was rejected by the commit hook, so scoped `data:`). Verified live: top contract 6057; 99 called rows / 56 genuine-zero rows / 0 unknown; `totalCalls` 15301 reconciles. `src/indexer/database.ts` +29/−3; esbuild clean.

**Not pushed. No deploy. No DUST economics. No API expansion. No YAMORI.**
