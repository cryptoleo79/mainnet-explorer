# NightForge — Main Truth Audit

Audit only. No code, no deploy. Each item verified against current `main` (@ `77b971a`) — claims from the 111-agent research were re-checked against real file:line and live endpoints; **two did not reproduce and are marked as such** (truth-first: we don't repeat unverified claims).

> **Status (closeout 2026-06-21):** **A1 RESOLVED / LIVE** and **A2 RESOLVED / LIVE** — both shipped to `main` and verified in production. A3 remains a MED follow-up. B1/B2 stay NOT-REPRODUCED. See the per-item RESOLVED blocks below.

---

## A. CONFIRMED issues

### A1 — Fabricated DUST economics presented as analytics — **HIGH**
- **Source:** `src/api/server.ts:2280-2320` (`/api/dust-economics`).
- **Evidence:** the endpoint computes everything from invented constants — `totalNightSupply = 4_500_000_000`, `estimatedStakedNight = supply * 0.3` (a guessed 30% stake), `avgDustPerTx = 300_000_000` ("~300M specks average fee"). Live output ships `sustainabilityScore: 100`, `netFlow.status: "surplus"`, `estimatedStakedNight: 1350000000`, `dailyNetDust: 964262879.99`, `avgFeePerTransaction: "300M specks"`.
- **User-facing risk:** a "sustainabilityScore"/"surplus" reads as a real on-chain economic health metric; it is a function of guesses. The endpoint *does* carry a `note: "Estimates based on tokenomics parameters…"`, which softens but does not cure it — the field **names** still assert authority.
- **Fix priority:** HIGH (actively misleads).
- **Proposed safe fix:** rename every derived field with an `estimated*` prefix, demote `sustainabilityScore` → remove or rename `estimatedRatio`, surface an explicit `assumptions { stakedPct: 0.3, avgFeeSpecks: 300000000, nightSupply: 4.5e9 }` object so the guesses are visible, and keep/strengthen the `note`. Do **not** present `status: surplus/deficit` without real fee data.
- **✅ RESOLVED / LIVE (2026-06-21).** Main commit `72b8107` (PR **#2**, merge-commit preserving `adbff8f` plan + `e709618` fix). Production-verified live.
  - Endpoint now returns the **truth-safe shape**: `title, basis, generation, activity, assumptions, parameters, unavailable`.
  - **Removed fake live economics:** `sustainabilityScore`, `netFlow`, `avgFeePerTransaction`, `estimatedDustBurnPerDay`, `avgDustPerTx`.
  - Note: `sustainabilityScore` / `netFlow` / `avgFeePerTransaction` / `estimatedDustBurnPerDay` may appear **only as strings inside `unavailable.omittedFields`** (an honest list of what's omitted) — **not** as live analytics values. `avgDustPerTx` is gone entirely.
  - **UI** (`tools/dust-console.html` #economics) now reads **"DUST Generation Estimate"** ("projection … not live on-chain economics"); the Sustainability gauge, Surplus/Deficit badge, and net-DUST/burn/avg-fee cards are removed.
  - **Assumptions explicit:** `stakedNightPct: 0.3`, `totalNightSupply: 4.5e9`, labelled "not measured on-chain".
  - **`unavailable.reason`:** "No real per-transaction DUST fee source yet (indexer fees field pending)." — explains why consumption/net-flow/sustainability are intentionally absent.
  - Plan/record: `docs/NIGHTFORGE_A1_DUST_ECONOMICS_PLAN.md`.

### A2 — `interactions: 0` hardcoded for every contract — **HIGH**
- **Source:** `src/indexer/database.ts:522` (inside `topContracts` map in the contracts summary).
- **Evidence:** `interactions: 0,` is a literal; it is never populated from the local `events` table, so the "Most Active Contracts" view shows 0 for all — despite real call counts existing locally (research cited a top contract at ~6,057 calls; **unverified exact number**, but the call data demonstrably exists in `events`).
- **User-facing risk:** a contract activity/leaderboard that is permanently, silently wrong (all zeros) — reads as "no activity" when activity exists.
- **Fix priority:** HIGH.
- **Proposed safe fix:** join/count `events` by contract address to populate `interactions`; until then, omit the field rather than emit a false `0`.
- **✅ RESOLVED / LIVE.** Production-verified. Main commits `e15a249` (derive) + `a89862f` (dedupe), merged via `da99bdf`.
  - Interactions now **derive from real local data**: `events WHERE section='midnight' AND method='ContractCall'`, counted per `contractAddress` (extracted from the event `data`).
  - The hardcoded `interactions: 0` is **removed**; genuine `0` = deployed-but-never-called; unknown/unparsed address → `null` (never a fabricated `0`); `interactionsSource: 'events.ContractCall'` provenance added; leaderboard sorted by real count and **deduped to one row per address**.
  - **Reconciles true:** `Σ interactions == totalCalls` (verified live, top contract 6,057; 107 distinct rows, 0 duplicates).
  - Records: `docs/NIGHTFORGE_A2_INTERACTIONS.md`, `docs/NIGHTFORGE_A2_PR_REVIEW.md`.

### A3 — Tool pages: epochs + passport already fixed; others need a render check — **MED**
- **Source:** `tools/` (17 pages).
- **Evidence:** `epochs.html` (field-mapping fix) and `passport-ready.html` (reframed wording) were fixed and merged this cycle (`ed0cece`, `866e6c8`). `dust-console.html` / `dust-economics.html` are now **covered by A1 (RESOLVED)**. Remaining pages not yet audited for backend/field drift: `tx-inspector.html`, `network.html` (has hardcoded `night_dust_ratio` / `generation_decay_rate` parameter cards — confirm they're labeled as constants, not live).
- **User-facing risk:** medium — stale/misleading tool panels.
- **Fix priority:** MED.
- **Proposed safe fix:** per-page pass confirming each displayed number has a real source or is explicitly labeled a constant; same pattern as the epochs fix (hide/label unsourced sections).

---

## B. NOT REPRODUCED / UNCONFIRMED (agent claims that did NOT verify)

> Recorded for honesty — do **not** action these as written; they failed live verification.

### B1 — "Stale hardcoded price placeholder ($0.06 vs ~$0.032)" — **NOT REPRODUCED**
- **Check:** `/api/price` (`src/api/server.ts:1364`) proxies live to CoinGecko; **no hardcoded price constant** exists in `src/` or `tools/` (every `0.06`/`0.05` hit was CSS `letter-spacing`/`rgba`, not a price). Apex nginx also proxies `/api/price` to CoinGecko directly.
- **Verdict:** no stale price constant found in code. If a stale figure appears anywhere, it's in a surface not in this repo (or a transient CoinGecko fallback) — **needs a specific screenshot/URL to pursue.** Not a confirmed code issue.

### B2 — "Apex nginx routing gap silently serving HTML to a JSON parser (credential-gate liveness)" — **NOT REPRODUCED**
- **Check:** live `https://nightforge.jp/api/credential-gate/liveness` returns **`application/json`** (not HTML). `https://nightforge.jp/api/epoch/current` also returns JSON, and `/tools/epochs.html` returns the real tool page.
- **Nuance worth flagging (config clarity, not a user bug):** the apex nginx file `/etc/nginx/sites-available/nightforge.jp` shows **only** `/api/testnet`, `/api/preview`, `/api/price` proxies and **no** `/tools` or mainnet `/api/`→:3005 block — yet those URLs resolve correctly live. That means the **active routing differs from this config file** (a default server, include, or different active vhost). 
- **Verdict:** no user-facing html-to-JSON mismatch right now. **Recommend an ops check** of which nginx config is actually active for the apex, purely for maintainability — not a shipping bug.

---

## C. What NOT to build
- ❌ Any DEX / AMM / liquidity / swap UI or "TVL/volume" — no live DEX exists on Midnight (cross-contract calls + oracles officially blocked); never display fabricated figures (e.g. the "texswap $2.4B" the research flagged as invented).
- ❌ Any new metric derived from guessed constants presented as live (no more `sustainabilityScore`-style fields).
- ❌ Fee/DUST-amount displays **until the unit is locked** — the live `/api/dust-economics` declares `specksPerDust: "1e15"`, which resolves the earlier 1e9-vs-1e15 ambiguity in this repo's favor (1e15), but any new fee display must be re-verified against a funded wallet before shipping a number.
- ❌ WalletConnect (no Midnight CAIP-2 namespace) — vapor.
- ❌ Validator/SPO populated views as if live — federated phase means zeros are *correct*, not errors; label `phase: federated`.

---

## D. Top 5 next APIs — REAL DATA ONLY
Each backed by data that demonstrably exists (indexer v4 or local `events`); none requires inventing constants.

| # | Endpoint | Real data source | Feasibility | Truth-risk | Why |
|---|---|---|---|---|---|
| 1 | Fix `interactions` (not a new endpoint — A2) + `GET /api/contracts/leaderboard` | local `events` (contract calls) | now | low | "Most Active" is broken today; data is already local |
| 2 | Add `transactionResult { status }` to tx queries | indexer v4 | now | low→med | Today every tx looks successful; show real PARTIAL/FAILURE |
| 3 | Add real per-tx `fees { paidFees }` to enriched-tx | indexer v4 `RegularTransaction.fees` | now | **gate on unit** | Replaces the A1 `300M specks` guess with truth — but hold the *display* until unit re-confirmed on a funded tx |
| 4 | `GET /api/governance/validator-series` (`registeredSpoSeries`) + d-parameter change log | indexer + local | now | low | Mōhalu-readiness; surfaces the real 10→130 d-param history |
| 5 | Expand unshielded UTXO fields (`owner tokenType outputIndex registeredForDustGeneration`) | indexer v4 | now | low | `tx-inspector.html` already has render slots starved of data |

(Deliberately excluded the "DUST economics" expansion — it cannot be made real until per-tx fees + actual stake data replace the guesses.)

---

## E. Recommended order
1. **A2** (interactions:0) — pure local join, highest value/lowest risk.
2. **A1** (DUST economics honesty) — rename `estimated*` + expose `assumptions`, or pull the endpoint from any prominent UI until backed by real fees.
3. **A3** per-page tool render check (dust-economics/network/tx-inspector).
4. Then **D1–D5** real-data endpoints, with D3's *display* gated on a funded-wallet unit confirmation.
5. **B2** ops check of the active apex nginx config (maintainability, not a bug).

---

## Closeout verification (2026-06-21) — A1 + A2 LIVE
- ✅ `npm run build` (tsc) passed on `main` @ `72b8107`.
- ✅ `/api/dust-economics` live-verified: returns `title, basis, generation, activity, assumptions, parameters.daysToCapPerNight, unavailable`; `sustainabilityScore / netFlow / avgFeePerTransaction / estimatedDustBurnPerDay / avgDustPerTx` absent as live data (the first four appear only inside `unavailable.omittedFields`). Apex + mainnet parity confirmed.
- ✅ `tools/dust-console.html` live copy verified: no "Real-time generation, consumption" / "strong surplus" theater; header reads "DUST Generation Estimate".
- ✅ `/api/analytics/contracts` (A2) live-verified earlier: real per-contract interactions, deduped, reconciles to `totalCalls`.
- ✅ Service `midnight-mainnet-indexer.service` **active**; `:3005/health` → 200; clean boot (resumed block 1,362,169).
- ✅ No YAMORI touched. No nginx changes. Controlled restart only (operator sudo) — no `deploy-all.sh`.

*Audit + closeout. Sources: `src/api/server.ts`, `src/indexer/database.ts`, `tools/*.html`, live mainnet endpoints, `/etc/nginx/sites-available/nightforge.jp`. Cross-ref: `YAMORI/docs/YAMORI_111_AGENT_FINDINGS.md` §4; `docs/NIGHTFORGE_A1_DUST_ECONOMICS_PLAN.md`, `docs/NIGHTFORGE_A2_INTERACTIONS.md`, `docs/NIGHTFORGE_A2_PR_REVIEW.md`.*
