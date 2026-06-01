# Ecosystem Wakeup Plan

Research + planning pass dated **2026-05-30**. Goal: identify the highest-leverage, truthful, original Midnight infrastructure work for NightForge / YAMORI / CredentialGate. No vanity. No fake metrics. No theater.

This is a planning document. **No code has been written for any item below.** Implementation requires explicit approval per item.

## Verified upstream state — what actually shipped

### Midnight node + open blockers

| item | state | source |
|---|---|---|
| `midnight-node` 1.0.0 GA | **shipped 2026-05-20** | github.com/midnightntwrk/midnight-node/releases |
| `midnight-node` 1.0.1-rc.1 prerelease | 2026-05-29, "single small config fix", not yet stable | same |
| **Mainnet RPC version (rpc.mainnet.midnight.network)** | **still 0.22.1-9ce45781** — node 1.0.x NOT yet rolled to mainnet | live JSON-RPC probe |
| **Preview RPC version** | **1.0.0-8af7d08a** — preview is on node 1.0.0 GA | live JSON-RPC probe |
| Issue #1206 (shielded mint EffectsCheckFailure) | **CLOSED 2026-05-19** | github issue page |
| Issue #1374 (sendShielded + insertCoin-on-change) | **CLOSED 2026-05-28** via merged PR #1449 | github issue page |
| Issue #1397 (mapping-validator-same-address-across-deployments) | OPEN | github issue page |
| Forum thread #1209 (Mainnet DUST HRP mismatch) | unresolved | forum.midnight.network/t/.../1209 |

**Memory correction needed.** Prior session memory (`session_2026_05_12_recon`, `session_2026_05_18_research_sweep`) labeled #1397 as the "Mainnet DUST HRP mismatch." That is wrong. #1397 is a different bug (mapping-validator-same-address). The HRP mismatch is forum thread #1209. This file is the corrected reference; older session memory should be updated next pass.

### Midnight indexer

| host | live version | notable schema state |
|---|---|---|
| `indexer.mainnet.midnight.network` | v4.3.x baseline | no merkle roots, no `dustGenerations` query |
| `indexer.preview.midnight.network` | v4.3.x + extras (effectively v4.3.2-ish build) | adds `dustCommitmentMerkleTreeRoot`, `dustGenerationMerkleTreeRoot`, `zswapMerkleTreeRoot`, `Query.dustGenerations`, plus 3 extra subscriptions |
| `indexer.preprod.midnight.network` | v4.3.x baseline | same as mainnet |
| Upstream latest | **4.3.3-rc.3 (2026-05-29)** with `zswapEndIndex` + `dustCommitmentEndIndex` + `dustGenerationEndIndex` | **all three end-index fields 404 on all public hosts** |
| Common-to-all subscriptions | `blocks`, `contractActions`, `dustLedgerEvents`, `shieldedTransactions`, `unshieldedTransactions`, `zswapLedgerEvents` (6) | — |
| **Critical empty-set warning** | SPO / committee / epoch-performance fields exist in schema but **return empty** (`spoCount=0`) on all three public hosts | a "validators by performance" widget against these would render blank — do not ship |

### Wallet SDK ecosystem

| package | latest | published | YAMORI status |
|---|---|---|---|
| `@midnight-ntwrk/wallet-sdk-facade` | **4.0.1** | **2026-05-27** (the 25-day gap closed) | YAMORI on `^3.0.0` |
| `@midnight-ntwrk/midnight-js-types` | **4.1.0** | **2026-05-25** on npm | not yet adopted |
| `@midnight-ntwrk/midnight-js-protocol` | 4.1.0 | 2026-05-26 | not yet adopted |
| `@midnight-ntwrk/wallet-sdk-abstractions` | 2.1.0 | 2026-04-23 (stable, no patches in 37 days) | `TransactionHistoryStorage` interface ready to implement |
| `@midnight-ntwrk/dapp-connector-api` | 4.0.1 | 2026-02-17 (unchanged 102 days) | no new methods to surface |

Coordinated swarm release on 2026-05-27 across ~10 packages. Migration verdict: **PLAN — re-evaluate 2026-06-05** after a community-bug-report cycle. Not a CVE; ledger v8 transitive bump warrants caution.

### Compact toolchain

| tool | version | date | notes |
|---|---|---|---|
| `compactc` | **0.31.0** | 2026-04-29 | no 0.32 since; #278 JubjubPoint equality fix in JS landed |
| `@midnight-ntwrk/compact-runtime` | **0.16.0** | 2026-04-29 | breaking: `convertBytesToUint` parameter `number` → `bigint` |
| Language | 0.23 stable | — | `JubjubPoint` rename was in 0.22; EC primitive interface unchanged 30 days |

Schnorr-on-JubJub feasibility for CredentialGate `_verify_issuer_sig`:
- Approximate constraint count per signature: **~10k** (ecMulGenerator + ecMul + ecAdd + Poseidon challenge)
- ed25519-in-circuit comparison: 500k–2M constraints (50–200× worse) — **DO NOT** pursue
- **Active contract `7ee02faf…` cannot be upgraded in place** — circuit identifier would change. Migration is deploy-v2-alongside-v1.

### Chrome MV3 + WebAuthn PRF

| field | value |
|---|---|
| Chrome current stable | **148** (148.0.7778.96+, released 2026-05-05/06) |
| CVE-2026-7952 (extension-policy bypass) fix floor | **Chrome 148.0.7778.96** |
| PRF-on-create on Windows Hello | **default-on in Chrome 148** ✅ |
| PRF-on-create on macOS/Linux | still flagged off in 148; rolls in 149 |
| Safari 26.4 PRF | landed but unreliable for CTAP2 security keys |
| **Recommended YAMORI v1.6.0 `minimum_chrome_version`** | **148** (revised up from the 2026-05-18 sweep's "132") |

### Ecosystem competitors / dApps

| dApp / explorer | state |
|---|---|
| midnightexplorer.com v2.0 (TexLabs) | shipped 2026-04-22, still RPC-only / no backend, has 1D/3D/7D charts. Real competitor for tx browsing |
| midnight-testnet.subscan.io | testnet only, Substrate-pattern, wrong audience |
| Nocturne explorer (OSS solo dev) | hobby, not a competitor |
| **1AM wallet v5.0.1** | shipped with native Cardano integration + one-click DUST generation. **Material jump** since our preprod-only log |
| Midnames | preprod-only, public registry contract address **NOT publicly surfaced** — do not promise a resolver link yet |
| LunarSwap, Statera, Hydra Stake, Brick Towers RWA, dMarket, Midnight Starship, Dominion.fun | shipping dApps per awesome-dapps registry |

## Current capability inventory — what we already have

### NightForge

| surface | count | notes |
|---|---|---|
| Registered Express GET endpoints | 71 (across 51 unique paths) | full list captured in `docs/REPO_TOPOLOGY.md` § Adjacent infrastructure |
| `/tools/*.html` pages on disk (mainnet repo) | 16 | including `dust-console.html` (63 KB), `validators.html` (43 KB), `contracts.html` (46 KB), `shielded.html` (28 KB), `network.html` (31 KB), `live-feed.html` (22 KB), `error-codes.html` (21 KB), `epochs.html` (19 KB), `privacy-score.html` (17 KB), `passport-ready.html` (15 KB), `privacy-flow.html` (13 KB), `widgets.html` (13 KB), index 15 KB |
| Visible top-nav tabs | 8 | overview, blocks, extrinsics, privacy, bridge, analytics, governance, epochs |
| Top-of-page topNav row | 7 + Tools | first-paint discoverability bar, restored last session |
| Hidden-but-present tabs (`display:none`) | 2 | `contracts` (lives in /tools/contracts.html) · `transactions` (Midnight has no separate tx table, only extrinsics) |
| CredentialGate hero card | present on apex + mainnet | wired to live `/api/credential-gate/liveness` |
| Documented backend timeouts | 4 endpoints | logged in `docs/BUG_BACKEND_TIMEOUTS.md`, not fixed |
| Last NightForge deploy | `d45862e` UI nav fix, deployed 2026-05-26 06:13 UTC to all 4 docroots | — |

### YAMORI

| field | value |
|---|---|
| Latest release zip | `yamori-v1.5.0.zip` (6,502,023 bytes) |
| All release zips on disk | v1.0.0, v1.1.0, v1.2.0, v1.3.0, v1.4.0, v1.5.0 |
| Latest local HEAD | `0c0414a docs: expand sdk 4 migration plan after fresh audit` |
| Issuer flow | live (gen-issuer, issue, verify-credential) |
| Chrome `minimum_chrome_version` | (manifest path on disk — verify before bump) |
| SDK | wallet-sdk-facade `^3.0.0` (facade 4.0.1 now on npm, **not adopted**) |
| Storage interface conformance | NOT yet aligned to `TransactionHistoryStorage` (interface stable since 2026-04-23) |

### CredentialGate

| field | value |
|---|---|
| Active contract | `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703` |
| Network | Midnight Preview |
| Proof model | signed disclosure verified out-of-circuit (`_verify_issuer_sig` is a witness placeholder returning true) |
| Live status | fail → prove → pass green on preview |
| ZK predicate verification | **NOT YET REAL** — Schnorr-on-JubJub upgrade is the queued path; requires v2 deploy |

## Ranked opportunity list

Anchor scoring: data source must be real; user value must be concrete; risk is rated against the Safety Rule (anything touching wallet storage / signing / SDK major / tx construction / proof internals / contract changes defaults to WAIT unless clearly safe).

| # | Idea | Area | Real data source | User value | Risk | Effort | Recommendation |
|---|---|---|---|---|---|---|---|
| 1 | **D-parameter governance timeline** widget on `/tools/governance.html` or new tab | NightForge | `Query.dParameterHistory` (real; 2 events on mainnet: genesis 10/0 → block 522886 130/0) | Audit-grade visibility into committee policy evolution | low | low | **DO NOW** |
| 2 | **Terms & Conditions version history** widget alongside #1 | NightForge | `Query.termsAndConditionsHistory` (real; 1 entry on mainnet) | Compliance / governance audit signal | low | low | **DO NOW** |
| 3 | **Transaction fee economics** panel (paid vs estimated DUST + failed-segment rate) | NightForge | `RegularTransaction { fees { paidFees, estimatedFees }, transactionResult { status } }` — must use inline fragment, NOT the `Transaction` interface | True fee-market diagnostics; debugging tool for dApp devs | low | medium | **DO NOW** |
| 4 | **YAMORI `TransactionHistoryStorage` interface conformance** (shape only, no SDK bump) | YAMORI | `abstractions@2.1.0` interface (stable 37 days) | Drop-in ready when SDK 4.x lands; zero behavior change today | low | medium | **DO NOW** |
| 5 | **Memory correction commit** + add a `RESEARCH_2026_05_30.md` snapshot in docs/ | docs | this file's verified findings | Prevents future agent runs from inheriting the #1397/#1209 mislabel | low | trivial | **DO NOW** |
| 6 | **Live block author stream** (Subscription.blocks + Block.author + Block.systemParameters.dParameter) — leaderboard "who produced last N blocks" | NightForge | `Subscription.blocks` (real on all 3 hosts) | Real-time committee-activity signal; honest replacement for the empty SPO widgets | low | medium | **DO NOW** |
| 7 | **Contract entrypoint frequency** view per deployed contract | NightForge | `Subscription.contractActions` + `ContractCall.entryPoint` + `.deploy.address` | Hot-path discovery for devs / users | low | medium | **PLAN** |
| 8 | **CredentialGate v2 (`CredentialGateZk.compact`)** new file, compile-only, Schnorr-on-JubJub | CredentialGate / Compact | stdlib `ecMulGenerator`/`ecMul`/`ecAdd` + Poseidon | Real ZK predicate verification (current model is honestly signed-disclosure) | medium-high (contract redeploy required) | high (1-2 weeks design + circuit work) | **PLAN** — start with compile-only file |
| 9 | **YAMORI v1.6.0 manifest `minimum_chrome_version` → 148** | YAMORI | Chrome 148 stable channel + CVE-2026-7952 fix floor | CVE floor + Windows Hello PRF default-on | low (after community-bug cycle on facade 4.0.1) | trivial | **PLAN** — pair with next release zip |
| 10 | **YAMORI CSP tightening + offscreen reason expansion** | YAMORI | manifest + Chrome MV3 offscreen API | Web Store review benefit; fewer SW wakeups (addresses 04-25 boot-storm pattern) | medium (extension behavior change) | medium | **PLAN** |
| 11 | **wallet-sdk-facade `^3.0.0` → `^4.0.1` bump in YAMORI** | YAMORI | npm | Unblocks downstream features (Protocol ACL, TestKit) | high (ledger v8 transitive) | high (full round-trip retest) | **PLAN** — re-evaluate 2026-06-05 |
| 12 | **Preview-only "DUST generations live" widget** behind env gate | NightForge | `Subscription.dustGenerations` (preview only) | Real on-chain DUST-mint visibility, env-honest | low | low | **PLAN** |
| 13 | **Nakamoto Coefficient / Decentralization Dial promotion to nav** | NightForge | committee data (live where present) | Defensible WOW vs midnightexplorer | low | low | **PLAN** |
| 14 | **DUST Console + CredentialGate hero promotion above the fold** (nav surfacing audit) | NightForge | existing surfaces | Sharpens 2 of the 3 differentiators competitors don't have | low | trivial | **PLAN** |
| 15 | "**Validators by performance**" widget | NightForge | SPO fields return empty on all 3 hosts | would render blank — false WOW | — | — | **WAIT** — gated on Foundation populating SPO data |
| 16 | "Mainnet shielded tx" surface in YAMORI / NightForge | both | gated on mainnet rolling to node 1.0.x (currently 0.22.1) | — | — | — | **WAIT** |
| 17 | DUST mapping-validator per-network display | NightForge | gated on #1397 close | — | — | — | **WAIT** |
| 18 | DUST HRP-mismatch removal of "blocked upstream" badges | both | gated on forum #1209 + indexer patch | — | — | — | **WAIT** |
| 19 | Indexer v4.3.3 end-index fields (`zswapEndIndex`, etc.) | NightForge | 404 on all 3 public hosts today | — | — | — | **WAIT** |
| 20 | Midnames resolver UI surface | NightForge / YAMORI | public registry contract address not surfaced | — | — | — | **WAIT** |
| 21 | ed25519-in-circuit verification for CredentialGate | CredentialGate | 50–200× cost vs Schnorr-on-JubJub | — | — | — | **DO NOT DO** |
| 22 | ARKG passkey rotation in YAMORI | YAMORI | still individual IETF draft, no WG adoption | — | — | — | **DO NOT DO** |
| 23 | "Validators by performance" widget against empty SPO data | NightForge | data is empty across hosts | would be fake-feeling | — | — | **DO NOT DO** |
| 24 | 1D/3D/7D price/tx chart parity with midnightexplorer.com | NightForge | their charts work fine; chasing adds no value | — | — | — | **DO NOT DO** |
| 25 | Subscan-style account browser | NightForge | wrong audience for our positioning | — | — | — | **DO NOT DO** |
| 26 | min_version > 149 in YAMORI manifest | YAMORI | 149 is Early Stable only (June 2 promotion) | — | — | — | **DO NOT DO** |
| 27 | Migrate YAMORI to facade 4.x **today** | YAMORI | 3-day-old swarm release; ledger v8 transitive untested | — | — | — | **DO NOT DO** (today; see #11 — PLAN with re-eval) |
| 28 | Touch YAMORI Chrome vault | YAMORI | locked per repo rules | — | — | — | **DO NOT DO** |
| 29 | Force-push / merge / history rewrite on canonical branches | infra | locked | — | — | — | **DO NOT DO** |

## Top 3 DO NOW (safe, real, ships this session)

1. **D-parameter governance timeline + T&C version history widgets** (items #1 + #2 combined). Single new page or section on existing `/governance` tab. Both endpoints already live on mainnet, both return real data, both are uniquely audit-grade vs every competitor. Estimate: 1 commit per repo (mainnet-explorer only — preview/preprod return empty arrays which is honest).
2. **Transaction fee economics panel** (item #3). One new widget on the Analytics tab (or under a "Fee market" sub-section). Uses `RegularTransaction { fees }` inline fragment correctly. Honest paid-vs-estimated histogram + failed-segment rate per N blocks.
3. **Memory correction + research snapshot doc** (item #5). One `docs:` commit. Patches the #1397/#1209 mislabel so future agents don't repeat it. Documents today's verified upstream state in a dated snapshot file.

These three are forward-only, deploy-clean, no SDK bump, no contract touch, no wallet vault touch.

## Top 3 PLAN (bigger, real, gated on safety review)

1. **CredentialGate v2 — `CredentialGateZk.compact` compile-only first commit** (item #8). Adds new contract file alongside v1, removes `_verify_issuer_sig` witness, swaps in `circuit verify_schnorr_jubjub` using stdlib EC primitives. **No deploy.** First commit is just `compactc --stats` proof that the circuit budget is real (~20k constraints for issuer+wallet pair). Active contract `7ee02faf…` remains untouched.
2. **YAMORI v1.6.0** package: `TransactionHistoryStorage` shape conformance (item #4) + `minimum_chrome_version` 116 → 148 (item #9) + CSP tightening + offscreen reason expansion (item #10). Single release. New zip. SDK bump NOT included (deferred to v1.7.0).
3. **NightForge live block author stream + contract entrypoint frequency** (items #6 + #7). Two new widgets using `Subscription.blocks` and `Subscription.contractActions`. Real-time, honest committee + contract activity. Replaces the empty-data "validators by performance" temptation with something that actually returns data.

## WAIT list (do not act without upstream trigger)

1. SPO / committee / epoch-performance widget population — gated on Foundation ingesting SPO data into the indexer (`spoCount=0` everywhere today)
2. Mainnet shielded tx UI — gated on mainnet RPC moving from 0.22.1 to node 1.0.x
3. `#1397` mapping-validator-same-address fix — gated on Foundation close
4. Forum `#1209` HRP-mismatch fix on mainnet — gated on Foundation
5. Indexer v4.3.3 end-index fields — currently 404 on all public hosts (rc.3 only)
6. Midnames resolver UI — gated on public registry contract address being verifiably surfaced
7. wallet-sdk-facade `^3.0.0` → `^4.0.1` SDK bump — re-evaluate **2026-06-05** after community-bug cycle
8. SD-JWT-VC draft-17 / WGLC adoption — revisit ~2026-07-17
9. Chrome 147 PRF-on-create macOS / Linux GA — currently 149 path
10. ARKG draft → WG adoption — currently individual draft

## DO NOT DO list

1. **ed25519-in-circuit** — 50–200× cost of Schnorr-on-JubJub. Use the latter.
2. **ARKG passkey rotation** — no IETF WG adoption yet.
3. **Vanity "validators by performance" widgets** against the SPO fields — they return empty across all 3 hosts.
4. **1D/3D/7D price/tx chart parity** with midnightexplorer.com — they do it fine, chasing adds no differentiation.
5. **Subscan-style account browser** — wrong audience for our positioning.
6. **Midnames resolver UI** — until we can verify the registry contract address on-chain.
7. **`minimum_chrome_version` > 149** — 149 is Early Stable only.
8. **wallet-sdk facade 4.x bump TODAY** — 3 days old, ledger v8 transitive untested.
9. **Touching YAMORI Chrome vault** — locked.
10. **Force-push / merge / history rewrite on canonical branches** — locked.

## Recommended first implementation pass

If approved, the first implementation pass should be a single coherent NightForge commit set with these three forward-only commits, in this order, no push without explicit approval per commit:

1. **`docs: snapshot 2026-05-30 ecosystem research`** — this file plus a dated `RESEARCH_2026_05_30.md` and a one-line correction to the older sweep note in `RESEARCH_UPDATE_SWEEP.md` clarifying #1397 vs #1209. Pure docs, no risk.
2. **`api: surface governance timeline + tc history fields`** — extend an existing or add a new endpoint that proxies `Query.dParameterHistory` and `Query.termsAndConditionsHistory` from the indexer. Read-only proxy. Real data. Tested for empty-array gracefulness on preview/preprod.
3. **`tools: add governance timeline widget`** — a single section added to an existing tools page (likely `network.html` or a small `governance.html`) that consumes the new endpoint. No homepage changes. No new hero card. No vanity metrics. Mainnet shows two events, preview/preprod show "no governance events yet" honestly.

After those three land cleanly, the second pass tackles the fee-economics panel (item #3 above) and the YAMORI v1.6.0 package separately.

## Cross-references

- `docs/REPO_TOPOLOGY.md` — repo / domain / branch mapping
- `docs/DEPLOY_FLOW.md` — exact deploy command + post-deploy verification + rollback
- `docs/SESSION_STATE.md` — current operational posture (OBSERVATION MODE)
- `docs/OBSERVATION_MODE.md` — frozen surface list
- `docs/COMMIT_AND_PR_STYLE.md` — scope-prefixed commit format
- `docs/BUG_BACKEND_TIMEOUTS.md` — captured backend timeout endpoints (separate concern)
- `docs/RESEARCH_UPDATE_SWEEP.md` — prior research sweep (2026-05-18)

This file's research closed **2026-05-30**. Upstream state shifts weekly; reverify before acting on any item dated more than ~10 days back.

---

## Delta sweep — 2026-06-01 (T+2 days)

Re-ran the four research swarms two days after the baseline. Reaffirms most WAIT verdicts; introduces two material developer-side signals that strengthen them.

### Material developer-side findings

1. **`midnight-wallet` issue #438 opened 2026-05-29 (open)** — `@midnight-ntwrk/wallet-sdk-dust-wallet@4.1.0` `computeBalancingRecipe` Effect.iterate never terminates (sign-convention error on `currentFee`). Coin selection returns empty recipe, convergence unreachable. Reporter status "POST_FIX_CONFIRMED" but no patch release yet. This is exactly the fee-pipeline class that would break YAMORI tx flow on an SDK 4.x bump. **The 2026-06-05 re-evaluation gate in the wakeup plan shifts to 2026-06-08 minimum; WAIT verdict on SDK 4.x bump remains and is now concrete, not theoretical.** Source: github.com/midnightntwrk/midnight-wallet/issues/438.
2. **Chrome 148 series accumulated 151 vulnerabilities (22 critical) in late-May patches** — CVE-2026-9111 (WebRTC UAF, RCE critical on Linux), CVE-2026-9872 (GPU OOB write), CVE-2026-9873 (Network UAF), CVE-2026-8004 (DevTools, extension-relevant), CVE-2026-7954 (Shared Storage leak). YAMORI v1.6.0's `minimum_chrome_version: 148` floor still stands, but the recommended patch-revision floor advances from `148.0.7778.96` (CVE-2026-7952 baseline) to whatever 148.x revision contains the May 26 fix cluster. **No `minimum_chrome_version` change vs the baseline; revise the documented rationale before v1.6.0 cuts.**

### Awareness-only findings

3. **`servicedesk` issue #34 opened 2026-05-31 (open)** — mainnet contract deploys return 100% rejection with Substrate `1016 Immediately Dropped`. Tx-pool / node-side. Not actionable from our side; gated on Foundation. Tracks alongside #1397 and forum #1209.
4. **Chrome 149 promoted to Stable June 2** as scheduled. PRF-on-create macOS / Linux not confirmed GA in 149 release notes (still flagged). YAMORI `minimum_chrome_version` stays at 148; revisiting at v1.7.0.
5. **`midnight-awesome-dapps` registry** shows entries beyond the 2026-05-30 baseline (visible: Midnight Escrow, Pintent, SilentLedger, Tokenless, Asset Tokenization Platform, Midnight Seabattle, Midnight DiceRoll). Per-PR timestamps unverified on this box (no `gh` CLI). Worth a `git log` pass on the next sweep.

### Zero deltas (everything else stayed put through 2026-06-01)

- **Mainnet RPC**: still `0.22.1-9ce45781`. 12+ days post node-1.0.0 GA. Unmoved.
- **Preview RPC**: still `1.0.0-8af7d08a`. Unmoved.
- **midnight-node releases**: latest still `node-1.0.1-rc.1` (2026-05-29). No GA promotion.
- **midnight-indexer releases**: latest still `v4.3.3-rc.3` (2026-05-29). No promotion.
- **Issue #1397** (mapping-validator-same-address): no comments, no PR linked.
- **Forum #1209** (Mainnet DUST HRP mismatch — note: this is the HRP issue; #1397 is *not*, despite older session-memory mislabeling): no posts since 2026-05-20.
- **wallet-sdk-facade / midnight-js-types / midnight-js-protocol / abstractions / dapp-connector-api**: all unmoved since 2026-05-27 swarm. `abstractions@2.1.0` now 39 days no-patches (stability signal).
- **compactc 0.31.0 / compact-runtime 0.16.0**: unmoved since 2026-04-29.
- **Foundation blog / forum**: no T&C update, no node 1.0.x mainnet rollout post, no governance change discussion. Most recent dev diary still 2026-05-20 ("Van Rossem Hard Fork"). 1AM Sprint 2 ongoing but no v5.0.2 / v5.1.0 yet.
- **midnightexplorer.com v2.x**: no observable patch.
- **1AM wallet**: still v5.0.1.
- **Midnames registry contract address**: still not publicly surfaced.
- **Safari 26.5.x**: no PRF/WebAuthn fix-note.
- **WebAuthn L3**: still Candidate Recommendation (CR window extended to ≥ 2026-06-23).
- **Firefox / Edge**: no actionable policy delta.

### Net read

No DO NOW / PLAN / WAIT / DO NOT DO classification changes. Both DO NOW items remain available; both PLAN items remain conditional; two WAIT verdicts strengthen with concrete citations (SDK 4.x bump now has #438; Chrome floor justification now has the 22-critical-CVE cluster). No NightForge or YAMORI action is unblocked. The wakeup plan's classifications still hold.
