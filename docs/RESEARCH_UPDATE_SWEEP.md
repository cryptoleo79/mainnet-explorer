# Research Update Sweep — 2026-05-18

Intelligence gathering only. **No code changed. No SDK upgraded. No
deploy.** Every line below is grounded in a probe or upstream source;
nothing is recommendation-by-vibe.

---

## Sources / probes used

- npm registry: `https://registry.npmjs.org/@midnight-ntwrk/<pkg>` for every package YAMORI tracks (full version list + publish timestamps).
- Docker Hub: `https://hub.docker.com/v2/repositories/midnightntwrk/proof-server/tags`
- GitHub: midnight-node, midnight-indexer, midnight-ledger, compact, midnight-improvement-proposals releases + issues + PRs.
- Live RPC `system_version` on `rpc.preview.midnight.network`, `rpc.preprod.midnight.network`, `rpc.mainnet.midnight.network`.
- Live indexer GraphQL introspection on `indexer.{mainnet,preview,preprod}.midnight.network/api/v4/graphql`.
- `forum.midnight.network/latest.json` and `/c/developers.json`.
- Chrome Developer docs (extensions whats-new, MV3 timeline, CSP, offscreen, alarms, web store policy), chromestatus, CVE-2026-7952 advisory.
- IETF datatracker for SD-JWT-VC draft-16, ARKG draft-10; OpenID4VP 1.0 final; OpenWallet Foundation `dcql-ts` releases; EUDI ARF 2.4.0 + roadmap.
- `docs.midnight.network/relnotes/compact` and `compact-runtime` API reference.

---

## Findings — classified

| Area | Finding | Source / probe | Value | Risk | Effort | Recommendation |
|---|---|---|---|---|---|---|
| **YAMORI / SDK** | `wallet-sdk-facade@4.0.1` patch still not shipped — only `4.0.0` (2026-04-23) on npm 25 days later | npm `latest` for facade | n/a | n/a | n/a | **WAIT** — keep migration plan deferred |
| **YAMORI / ledger** | `ledger-v8 8.1.0 GA` published **2026-05-13** (was 8.0.3 + 8.1.0-rc.1). Proof-server Docker image `8.1.0` GA shipped same minute | npm registry; hub.docker.com | medium | medium | low (transitive bump via facade 4.0 once it patches) | **WAIT** — gated on `wallet-sdk-facade@4.0.1` |
| **YAMORI / Chrome** | `minimum_chrome_version: 116` is too lax. CVE-2026-7952 extension policy-bypass patched Chrome 148 (2026-05-06). Chrome 132+ has stable PRF on Windows Hello + offscreen-reason expansion | chromestatus, CVE advisory | medium | low | tiny (manifest 1 line + rebuild + new zip) | **PLAN** (next zip cut) — bump 116 → 132 |
| **YAMORI / passkey** | Chrome 147 ships **PRF-on-create**; today YAMORI does PRF-on-get only. Pure additive opportunity to derive wallet seed at passkey-creation time | chromestatus 5138422207348736 | medium | low | medium | **WAIT** — revisit when Chrome 147 hits stable |
| **YAMORI / forum** | Forum 2026-05-18: "Preprod indexer ~23h behind chain — wallet ctime stuck at stale `block.timestamp` causes Custom error". Affects YAMORI on preprod (DUST registration / shielded ops use ctime) | forum.midnight.network | medium | low | low (defensive ctime guard in offscreen.ts) | **PLAN** — add to next pass; don't ship a fix without reproduction |
| **YAMORI / forum** | Forum 2026-05-16: mainnet DUST not generating (HRP mismatch upstream, #1397). Foundation hasn't fixed. YAMORI em-dashes through it correctly today | forum.midnight.network | n/a | n/a | n/a | **WAIT on Foundation** — already documented in OBSERVATION_MODE |
| **YAMORI / forum** | Forum 2026-05-13: Lace doesn't implement `getProvingProvider()`. Still unresolved (3 posts) | forum.midnight.network | informational | n/a | n/a | **WATCH** — confirms YAMORI's v4 spec lead position |
| **NightForge / indexer** | All 3 public indexers (mainnet, preview, preprod) still on **v4.1-class schema** — same Query/Subscription roster, byte-identical. v4.2/v4.3 fields all return "Unknown field". `/live` endpoint returns 404 everywhere | curl GraphQL introspection + field probes | n/a | n/a | n/a | **WAIT** — gated on Foundation indexer upgrade |
| **NightForge / indexer** | 5 indexer fields already live on every public host but NOT used by NightForge: `epochUtilization`, `registeredTotalsSeries`, `registeredSpoSeries`, `spoPerformanceLatest`, `registeredPresence + registeredFirstValidEpochs`, `dParameterHistory + termsAndConditionsHistory` | introspection vs current NightForge `/api/*` callsites | medium | low (read-only widgets) | medium (each is a real card/strip) | **PLAN** — only after a justified user-question per field. Do NOT recommend a dashboard per field by default |
| **NightForge / indexer docs** | `docs.midnight.network/api-reference/midnight-indexer/` documents the minimal v4.0 surface; the 22 SPO/epoch/committee queries actually live on the public indexers are **undocumented** | docs site vs live introspection | informational | n/a | n/a | **WATCH** — Foundation gap; no NightForge action |
| **NightForge / node** | midnight-node issue #1520 opened 2026-05-15: "Test new release against forked preview/pre-prod/mainnet" — staging push imminent for the Midnight 1.1 bundle | github.com/midnightntwrk/midnight-node/issues/1520 | informational | n/a | n/a | **WATCH** — next sweep 2026-05-21/22 may see rc.9 / bundle promotion |
| **NightForge / MIPs** | MIP #107 "Public Contract Log Emission for Compact Smart Contracts" opened 2026-05-17; #108 USDM stablecoin deployment 2026-05-16; #109 Ascend Perps 2026-05-17 | github.com/midnightntwrk/midnight-improvement-proposals/pulls | informational | n/a | n/a | **WATCH** — MIP-0007 (node events) already merged; #107 affects contract-explorer surface |
| **CredentialGate / contracts** | Compact 0.23 (compiler 0.31) **exposes EC primitives in stdlib**: `ecAdd`, `ecMul`, `ecMulGenerator`, `hashToCurve`. **Schnorr-on-JubJub is implementable today** as an in-circuit predicate to replace the `_verify_issuer_sig` witness `return true` with real cryptographic verification | docs.midnight.network/api-reference/compact-runtime + CompactStandardLibrary inspection | high (real ZK trust upgrade) | medium (curve switch + issuer CLI rewrite, no contract surface change) | high (1-2 week rewrite + redeploy + verifier-side update) | **PLAN** — material rewrite, write proposal doc before coding |
| **CredentialGate / contracts** | In-circuit **ed25519** is not feasible (no native primitive; non-native arithmetic ~50-200× cost of Schnorr-on-JubJub) | midnight-zk + Compact stdlib | n/a | high | very high | **DO NOT DO** |
| **CredentialGate / spec** | SD-JWT-VC draft-16 (2026-04-24) — `typ` header is `dc+sd-jwt` (was `vc+sd-jwt`); draft expires 2026-10-26. Migration item if YAMORI/CredentialGate target SD-JWT-VC interop | datatracker draft-ietf-oauth-sd-jwt-vc | informational | n/a | n/a | **WATCH** — revisit at WGLC or draft-17 |
| **CredentialGate / spec** | OpenID4VP 1.0 final (2025-07-09); DCQL mandated; `dcql-ts@3.0.0` (2025-11-27, ESM-only). Stable | openid.net + openwallet-foundation-labs/dcql-ts | informational | n/a | n/a | **WATCH** — only relevant if CredentialGate adds OID4VP interop |
| **CredentialGate / spec** | ARKG IETF draft-10 (2026-02-27, expires 2026-08-31). Still individual submission; no CFRG WG adoption | datatracker draft-bradleylundberg-cfrg-arkg | n/a | high | n/a | **DO NOT DO** — not deployable; passkey rotation flow stays out |
| **CredentialGate / Compact** | compactc 0.31.0 (Compact 0.23, 2026-04-29) — still the latest. No newer toolchain | github.com/midnightntwrk/compact/releases | informational | n/a | n/a | **WAIT** — bump compact-runtime 0.15 → 0.16 deferred until next release window |
| **YAMORI / safety filter** | Migrate seed/vault encryption to PBKDF2 (midnight-js PR #883 landed on main, unreleased) | midnight-js main | low (already strong) | high (vault touch, defaults to WAIT per brief safety filter) | medium | **WAIT** — defaults to WAIT per brief safety filter; revisit if a CVE forces it |

---

## DO NOW list

**Empty.** No safe code change today. The smallest viable real fix
(`minimum_chrome_version` 116 → 132) is reclassified PLAN because it
ships in the next zip cut and the brief explicitly says "do not change
code yet."

If the brief were "smallest safe action right now," the `minimum_chrome_version`
bump would qualify. It's docs/manifest only, build-verifiable in seconds,
and tightens the security floor without touching any wallet logic.

## PLAN list (queued, awaiting authorization)

1. **`minimum_chrome_version` 116 → 132** in `YAMORI/public/manifest.json`. Pairs with next zip cut. Surfaces CVE-2026-7952 fix floor + stable PRF on Windows Hello. Effort: 1 line + rebuild + new zip.
2. **Defensive ctime guard in offscreen.ts** against the forum-reported preprod indexer-lag scenario. Effort: ~10 lines + reproduction test. Needs an actual repro before fixing.
3. **CredentialGate Schnorr-on-JubJub migration design doc** in `contracts/credential-gate/docs/SCHNORR_MIGRATION.md`. Effort: 1-2 day design pass. **Do NOT touch contract code without the design being reviewed.**
4. **Per-field justification doc** for each unused indexer field (`epochUtilization`, `registeredTotalsSeries`, `registeredSpoSeries`, `spoPerformanceLatest`, `registeredPresence`, `dParameterHistory`+`tcHistory`). Each must answer "what user-facing question does this answer." Discard any that fails the test.

## WAIT list (gated on upstream / external trigger)

1. `wallet-sdk-facade@4.0.1` patch (25 days unfixed)
2. Midnight node 1.0.0 mainnet cutover (no date)
3. Indexer v4.2/v4.3 public deployment (mainnet+preview+preprod still v4.1)
4. Shield blocker `midnight-node#1206` + `#1374` (no movement)
5. Mainnet DUST HRP mismatch (Foundation-side; #1397)
6. Chrome 147 PRF-on-create (revisit at GA)
7. SD-JWT-VC WGLC / draft-17 (revisit ~2026-07-17)

## DO NOT DO list

1. **In-circuit ed25519 verification** — no native primitive; non-native arithmetic 50-200× cost of Schnorr-on-JubJub. Use Schnorr-on-JubJub instead if/when migrating.
2. **ARKG-based passkey rotation** — still individual IETF draft, no WG adoption, no production deployments. Out of band.
3. **Lighting up unused indexer fields as new widgets without per-field user-question justification** — explicit anti-pattern from the brief ("Do not recommend dashboards just because data exists").
4. **SDK 4.0 bump today** — exact same risk profile as `2026-05-17` audit; `4.0.1` patch not yet shipped.

## Dangerous items avoided in this sweep

- **No `npm install`** — registry was queried via HTTP only, no local package.json change.
- **No package version bumps** — current pins untouched.
- **No live wallet vault access** — Chrome storage untouched.
- **No transaction construction** — wallet signing / fee balancing untouched.
- **No deploy** — `/var/www/explorer-*` docroots untouched.

---

## Exact next safest action

**Open the discussion on PLAN item #1 (Chrome 132 manifest bump).** That
is the only item in this sweep that's:
- a single-line manifest edit,
- build-verifiable in seconds,
- security-positive (CVE-2026-7952 floor + stable PRF),
- and aligned with the SDK-4.0-wait posture (no SDK touched).

If approved, it bundles with the next zip cut, no special release.
Everything else here is queued or watching.

---

*Sweep run 2026-05-18. No code or deploy artifacts changed.*
