# NightForge A1 — DUST Economics Truth Fix (plan)

Audit-first plan. No code yet. Fix `/api/dust-economics` so it stops presenting guessed constants as live analytics. No fake DUST numbers, no new APIs, no YAMORI.

**Scope:** `src/api/server.ts` (`/api/dust-economics`, ~2270-2333) and its only real consumer `tools/dust-console.html` (#economics tab; `tools/dust-economics.html` is just a redirect stub to it). Also referenced by `website/nightforge-main.html`.

---

## 1. Current misleading fields

The endpoint mixes **real protocol constants**, one **real derived metric**, and several **pure guesses** — then labels the whole thing "Real-time generation, consumption, and sustainability metrics" (`dust-console.html:1136`) with a **Sustainability gauge** ("100 = strong surplus. Healthy economies stay above 80." `:1204`). The guesses drive the most authoritative-looking outputs.

**Guessed inputs (no on-chain source):**
| Input | Source | Problem |
|---|---|---|
| `totalNightSupply = 4_500_000_000` | `server.ts:2283` | Assumed supply figure, stated as fact |
| `estimatedStakedNight = totalNightSupply * 0.3` | `server.ts:2284` | **30% staked is a pure guess** — not measured on-chain |
| `avgDustPerTx = 300_000_000` | `server.ts:2291` | **300M specks/tx is a pure guess** — flagged off ~8–14× by prior research; no real per-tx fee source exists yet |

**Output fields, classified:**
| Field | Source | Verdict |
|---|---|---|
| `generation.estimatedStakedNight` | `server.ts:2302` | GUESS (30%) — labeled "Estimated" but the % isn't shown |
| `generation.dustPerDay` / `dustPerWeek` | `:2303-2304` | derived from the stake guess → not live |
| `generation.maxNetworkCapacity` | `:2305` | derived from the stake guess → not live |
| `generation.daysToMaxCapacity` | `:2306` | actually the **constant** `TIME_TO_CAP_SEC` (7d), mislabeled as a network metric |
| `consumption.avgDailyTransactions` | `:2311` | **REAL** — `extrinsics ÷ networkAgeDays` from the indexer |
| `consumption.estimatedDustBurnPerDay` | `:2312` | real tx count **×** the 300M fee guess → contaminated magnitude |
| `consumption.avgFeePerTransaction = "300M specks"` | `:2313` | **pure guess presented as a fact** |
| `netFlow.dailyNetDust` | `:2317` | guess − guess → fabricated |
| `netFlow.status` (`surplus`/`deficit`) | `:2318` | derived from fabricated flow → misleading badge (`dust-console.html:1646`) |
| `netFlow.sustainabilityScore` | `:2319` | **worst offender** — a fabricated 0–100 "health score" rendered as a gauge (`:1188`, `:1651`) |
| `parameters.*` | `:2322-2328` | **REAL** published protocol constants — keep |
| `note` | `:2330` | weak; doesn't name the 30% / 300M guesses |

---

## 2. Proposed safe response shape

Decision rule: anything that depends on the **per-tx fee guess** cannot be made real now (no on-chain fee source until the indexer `fees` field lands — A2/F2 gated) → **remove it** (prefer unavailable over wrong). Anything depending only on the **stake guess** → keep as an explicit, clearly-labeled *projection* with the assumption exposed. Real protocol constants and the real derived average → keep, honestly labeled.

```jsonc
{
  "title": "DUST Generation Estimate",
  "basis": "Projection from published protocol constants and the stated assumptions below. NOT live on-chain economics.",
  "generation": {                          // labeled estimate; depends only on the stake assumption
    "estimatedStakedNight": 1350000000,
    "estimatedDustPerDay": 964262880.0,
    "estimatedDustPerWeek": 6749840160.0,
    "estimatedMaxCapacity": 6750000000
  },
  "activity": {                            // REAL, from the indexer
    "avgDailyTransactions": 20531,
    "basis": "indexer: total extrinsics / network age (days)"
  },
  "assumptions": {                         // every guess made visible
    "stakedNightPct": 0.3,
    "totalNightSupply": 4500000000,
    "note": "Staked % and total supply are assumptions, not measured on-chain."
  },
  "parameters": {                          // REAL protocol constants (unchanged)
    "specksPerStarPerSecond": 8267,
    "starsPerNight": 1000000,
    "specksPerDust": "1e15",
    "capRatio": 5,
    "daysToCapPerNight": 7.0,             // renamed from daysToMaxCapacity — it's a constant, not a network metric
    "gracePeriodHours": 3
  },
  "unavailable": {                         // honest about what we cannot compute
    "reason": "No real per-transaction DUST fee source yet (indexer fees field pending).",
    "omittedFields": [
      "consumption.avgFeePerTransaction",
      "consumption.estimatedDustBurnPerDay",
      "netFlow.dailyNetDust",
      "netFlow.status",
      "netFlow.sustainabilityScore"
    ]
  }
}
```

---

## 3. Fields to REMOVE / HIDE (fee-guess-dependent — cannot be made real)
- `consumption.avgFeePerTransaction` (the literal "300M specks" guess)
- `consumption.estimatedDustBurnPerDay`
- `netFlow.dailyNetDust`
- `netFlow.status` (surplus/deficit)
- `netFlow.sustainabilityScore` ← and its UI gauge + explainer
- `avgDustPerTx` constant becomes unused → delete.

## 4. Fields that CAN REMAIN
- `generation.*` — **renamed `estimated*`**, kept only because they depend solely on the stake assumption, which is now exposed in `assumptions`. (Alternative if you prefer maximal caution: hide these too. Recommendation: keep as labeled estimate — they're a legitimate "if X% staked, then…" projection once the assumption is visible.)
- `activity.avgDailyTransactions` — real indexer-derived average; add `basis`.
- `parameters.*` — real protocol constants; rename `daysToMaxCapacity` → `daysToCapPerNight` (it's a per-NIGHT constant, not a live capacity countdown).
- `assumptions` — new, surfaces the guesses.
- `unavailable` — new, names what's intentionally omitted.

## 5. UI copy changes (`tools/dust-console.html`, #economics)
- `:1135-1136` header "DUST Economics Observatory" / "Real-time generation, consumption, and sustainability metrics" → **"DUST Generation Estimate"** / **"Projection from protocol constants + stated assumptions. Not live on-chain economics."**
- **Remove** the Sustainability gauge (`:1188`) + its setGauge call (`:1651`) and the explainer copy (`:1201-1204`).
- **Remove** the Surplus/Deficit badge (`:1176` area, render `:1644-1650`) and Daily Net DUST stat (`:1176`).
- **Remove** Avg Fee Per Transaction (`:1168`, render `:1640`) and the Dust Burn stat (render `:1639`).
- Keep "Estimated Staked NIGHT" but add an **Assumptions** line (stakedNightPct 30%, totalNightSupply) so the basis is visible.
- Keep avg daily transactions, generation estimates (relabeled "Estimated"), and the protocol parameters panel.
- Update the `renderEcon()` JS (`:1625-1655`) to the new shape and to **gracefully omit** removed fields (no leftover empty cards).

## 6. Verification plan
- **Endpoint:** after the code change, `GET /api/dust-economics` no longer contains `sustainabilityScore`, `netFlow`, `avgFeePerTransaction`, or `estimatedDustBurnPerDay`; contains `assumptions` + `unavailable`; `generation.*` keys are `estimated*`. Confirm via `curl … | python3 -c '…'`.
- **No fabricated magnitudes:** assert the response has no field whose value is a function of `avgDustPerTx`/`300_000_000`.
- **Real field intact:** `activity.avgDailyTransactions` still equals `extrinsics ÷ networkAgeDays` (unchanged real value).
- **UI:** load `tools/dust-console.html#economics` — no Sustainability gauge, no Surplus/Deficit badge, no Avg-Fee/Net-DUST cards; header reads "estimate / not live"; Assumptions visible; no empty/broken cards.
- **Build/typecheck:** `tsc --noEmit` 0 errors in `server.ts`; esbuild bundle OK.
- **No collateral:** `grep` confirms no other tool/website still reads the removed fields (only `dust-console.html` + `website/nightforge-main.html` consume them — re-check `nightforge-main.html`).
- **DUST elsewhere untouched:** `/api/dust-calculator`, `/api/dust-status`, dust-console Calculator/Status tabs unchanged.

---

*Plan only. No code. Branch `fix/nightforge-dust-economics-truth`. No new APIs, no YAMORI, no deploy.*
