# Upgrade Radar — NightForge · YAMORI · CredentialGate

Research-first upgrade survey across the whole stack. **Read-only sweep — no
code changed, no deploy, no SDK bump, no npm install.** Every finding below was
produced by a probe (live curl, source read, npm registry query, or MCP/web
lookup) and the headline defects were re-verified by hand before landing here.

- **Date:** 2026-06-02
- **Scope:** mainnet-explorer (NightForge), preview-explorer-new, preprod-explorer, YAMORI, CredentialGate (`YAMORI/contracts/credential-gate`)
- **Posture:** propose only. Anything touching the YAMORI vault, storage, signing, transaction construction, an SDK major, or the deployed `7ee02faf…` CredentialGate verification logic defaults to **WAIT/PLAN**, never DO NOW.
- **Method:** 5 parallel research agents (YAMORI SDK/security · NightForge API/indexer · CredentialGate/Compact/proof · nginx/deploy/topology · frontend/tools discoverability), findings de-duplicated and the actionable defects re-probed directly.

Recommendation legend: **DO NOW** (safe, additive, verified) · **PLAN** (real value, needs a tested change) · **WAIT** (gated on an external event or data) · **DO NOT DO** (no value / already complete / unsafe).

---

## 1. Verified current versions / endpoints

### NightForge state (verified)
- Apex `nightforge.jp/api/credential-gate/liveness` → **200 JSON**, contract `7ee02faf…`, network `preview`. **No regression.** (The duplicate-SSL backup-file issue in `sites-enabled` is resolved — no `.bak`/`.backup`/`~` files present.)
- Indexer services listening: **:3000** (preview), **:3004** (preprod), **:3005** (mainnet). **Nothing on :3006.**
- All three explorer local trees' `git remote` correctly match their environment (mainnet→mainnet-explorer, preview-new→preview-explorer, preprod→preprod-explorer). **No cross-push hazard.** mainnet-explorer tree is clean; preview/preprod trees carry uncommitted `tools/*` edits.
- All four docroots render correct per-env labels (Mainnet/Preview/Preprod), **zero `__NETWORK_LABEL__` placeholder leaks**, all deployed in one `deploy-all.sh` pass on 2026-05-26.

### Public Midnight indexer GraphQL (introspection ENABLED, all three nets)
- Schema version **v4**. Mainnet + preprod expose an **identical 26-field** queryType; preview adds 4 Zswap/DUST-internal fields (`zswapMerkleTreeCollapsedUpdate`, `dustGenerations`, `dustCommitmentMerkleTreeUpdate`, `dustGenerationMerkleTreeUpdate`).
- Subscriptions (all nets): `blocks, contractActions, dustLedgerEvents, shieldedTransactions, unshieldedTransactions`.
- **Indexer 4.3.0 left the GraphQL schema unchanged at v4** — there are **no new query fields upstream to surface.** (4.3 changes are operational: SPO standalone-SQLite mode, DUST `dtime` added to the subscription stream, redirect-loop fix on unknown `/api/vN` paths.)

### YAMORI dependency landscape (npm `latest`, probed 2026-06-02)
| Package | YAMORI pins | npm `latest` | Note |
|---|---|---|---|
| `@midnight-ntwrk/wallet-sdk-facade` | `^3.0.0` | **4.0.1** (4.0.0 @ 2026-04-23, **4.0.1 @ 2026-05-27**) | SDK major; pulls ledger-v8 8.1 + abstractions 2.1 |
| `@midnight-ntwrk/ledger` | `^4.0.0` | **4.0.0** (already latest) | The "v8 line" is a **separate package** `ledger-v8` (8.1.0), transitive via facade 4.x |
| `@midnight-ntwrk/wallet-api` | `^5.0.0` | **5.0.0** | already latest |
| `@midnight-ntwrk/compact-runtime` | `^0.15.0` | **0.16.0** | minor |
| `@midnight-ntwrk/wallet-sdk-address-format` | `^3.1.0` | 3.1.2 | caret covers |
| `@midnight-ntwrk/wallet-sdk-hd` | `^3.0.1` | 3.0.2 | caret covers |
| `@midnight-ntwrk/wallet-sdk-indexer-client` | `^1.2.0` | 1.2.2 | caret covers |
| `@midnight-ntwrk/wallet-sdk-prover-client` | `^1.2.0` | 1.2.2 | caret covers |
| `@midnight-ntwrk/midnight-js-network-id` | `^4.0.4` | 4.1.1 | caret covers (<5) |
| `@midnight-ntwrk/wallet-sdk-abstractions` | — | **2.1.0** | would become a NEW direct dep under SDK4 |
| `@midnight-ntwrk/wallet-sdk-dust-wallet` | (transitive) | **4.1.0** | migration doc §2 targets 4.0.0 — **stale** |
| `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | (transitive) | **3.1.0** | migration doc §2 targets 3.0.0 — **stale** |

### CredentialGate / Compact (verified)
- Contract `CredentialGate.compact` declares `pragma language_version >= 0.17` (open-ended, **no upper bound**). Current validated language band **0.16–0.23** (compiler ≥0.30 → language 0.22). Installed `compact 0.3.0` is the **CLI wrapper**, not the language version.
- Deploy stack: `compact-runtime 0.15.0`, `ledger 4.0.0`, `midnight-js 4.0.4`, `wallet-sdk-facade 3.0.0`.
- Deployed contract `7ee02faf…` on **preview**, live (recent proveKyc + swap txs confirmed via liveness endpoint).

---

## 2. Latest upstream findings

| Topic | Finding (dated) | Source |
|---|---|---|
| wallet-sdk-facade 4.x | **4.0.1 published 2026-05-27.** This satisfies the explicit "revisit when 4.0.1 appears" trigger in `YAMORI/docs/WALLET_SDK_MIGRATION.md`. 4.0.1's specific deltas vs 4.0.0 are **not independently confirmed** (no published changelog found; presumed the awaited patch). | `npm view` time map |
| ledger-v8 | `@midnight-ntwrk/ledger-v8` **8.1.0** GA (2026-05-13). Rebuilds the tx envelope for `TransactionExtension` (Substrate node 1.0.0). Bytes built on 8.0.x are rejected once mainnet activates node 1.0.0. | npm |
| Indexer | 4.3.0 out upstream; **GraphQL schema unchanged at v4** — no new fields. Mainnet still effectively v4. | indexer release notes + live introspection |
| Compact | Language band 0.16–0.23 (MCP, updated 2026-05-18). Breaking since 0.17: `NativePoint`→`JubjubPoint` rename (compiler 0.30), Uint width 254→248 (0.27), reserved identifiers (0.28), module-level `const` removed. **The CredentialGate contract trips none of these** as written. | MCP `get-latest-syntax` |
| SD-JWT base | **RFC 9901 published Nov 2025** (now a stable RFC). | datatracker |
| SD-JWT-VC | Still a draft — **draft-16, updated 2026-04-24** (YAMORI doc references draft-15). Not yet an RFC. | datatracker |
| OpenID4VP / DCQL | OpenID4VP reached **Final 1.0**; **DCQL is the sole query language** (Presentation Exchange removed). Mandated in EUDI/HAIP high-assurance profiles. | openid.net |
| Passkey PRF | Windows Hello PRF now works (KB5077181, Feb 2026 / 25H2); Safari 18+ works with iCloud Keychain; Chrome/Android solid; **Firefox still no PRF**; iOS roaming-authenticator PRF still blocked. YAMORI's PRF-absent fallback is correct. | Corbado/Yubico |

---

## 3. API opportunities (NightForge)

| Area | Finding | Source/probe | Value | Risk | Effort | Recommendation |
|---|---|---|---|---|---|---|
| Apex routing bug | `/api/mainnet/analytics/volume` → **404 on apex**, **200 on `mainnet.nightforge.jp`**. Backend route is bare `/analytics/volume`, excluded from the apex re-prefix alias. Homepage volume/daily charts silently blank on the flagship domain (`.catch(){}` hides it). | curl apex 404 / sub 200 (re-verified) | Med | Low | Low | **DO NOW** |
| Apex routing bug | Bare `/api/dust-eligibility` → **200 `text/html`** (SPA fallthrough), not JSON. `tools/dust-console.html:1349` calls the bare path; the 200-HTML defeats its `/api/dust-status` fallback → `resp.json()` throws → "Failed to fetch status". `/api/mainnet/dust-eligibility` → 200 JSON works. | curl re-verified | Med | Low | Tiny | **DO NOW** (point caller at `/api/mainnet/dust-eligibility`, or add the apex `location`) |
| Preprod dead port | preprod nginx routes `/api/live/`, `/api/validators/`, `/api/extrinsics`, `/api/address-summary/`, `/api/tx-enriched/` to **`127.0.0.1:3006` — nothing listens there → all 502 in production.** preprod's own `:3004` endpoints (`/api/blocks`) are 200. | curl 502 ×3 re-verified; `ss -ltn` shows no :3006 | High | Low (config repoint) | Low | **PLAN** (repoint the 5 `location` blocks to `:3004`, or start the intended :3006 service — needs operator/sudo) |
| Dead documented endpoint | `/api/docs` advertises `/api/extrinsics/stats` with a "Try it" link, but the route is **shadowed by `/api/extrinsics/:hash`** → 404 "Extrinsic not found". Embarrassing in public docs; no homepage consumer. | curl 404 + docs page | Low | Low | Low | **PLAN** (register `/extrinsics/stats` before `/extrinsics/:hash`, or drop from docs) |
| New homepage cards (real, un-surfaced) | Four **live, rich, zero-UI** endpoints: `/api/analytics/extrinsic-types` (section/method breakdown), `/api/analytics/tx-classification` (shielded/unshielded/mixed split), `/api/epoch/utilization` (per-epoch series), `/api/midnight-txs` (decoded Midnight tx list). All 200 with real data. WOW from real capability. | grep + curl 200 | Med-High | Low | Med | **PLAN** (add cards/tabs; honest fallbacks) |
| Apex nginx systemic | Apex `/api/*` is ~25 explicit per-endpoint `location` blocks, not a catch-all. **Any new server.ts endpoint silently falls to the SPA (200-HTML) unless a `location` is added** — the dust-eligibility break is one instance. | nginx config read | Med | Low | Low | **PLAN** (consider a scoped `/api/` proxy_pass after the specific blocks; topology rule 12 keeps bare-`/api/`→mainnet intentional) |
| Subscriptions / push | Backend is HTTP-poll only; indexer offers 5 subscriptions (4.3 added DUST `dtime`). Could power true live push instead of polling. | introspection | Med | Med (WS lifecycle — the 2026-04-20 silent-stall risk) | High | **PLAN** (only with a real real-time UX need; polling works today) |
| SPO/stake/registration fields | 13 unused indexer query fields (`spoIdentities`, `poolMetadata`, `stakePoolOperators`, `epochPerformance`, registration series…). But mainnet `spoCount=0`, `stakeDistribution=[]`, `/api/validators/directory` → "federated phase". **No real data yet — building cards now renders empty.** | introspection + live data | Low now | Low | Med | **WAIT** (gated on Foundation populating SPO data post-decentralization) |
| Governance | `dParameterHistory` + `termsAndConditionsHistory` already wired to `/api/governance/*`, live 200 on apex. | curl 200 | — | — | — | **DO NOT DO** (already complete) |

---

## 4. YAMORI upgrade opportunities

| Area | Finding | Source/probe | Value | Risk | Effort | Recommendation |
|---|---|---|---|---|---|---|
| SDK 4.0 migration | **Unblocked:** facade 4.0.1 (2026-05-27) satisfies the migration doc's revisit trigger. But the bump touches **tx construction + on-disk storage format + an SDK major** → it stays a deliberate, tested action on preview testnet per the doc's 11-step plan, not a reflexive bump. | `npm view`; `WALLET_SDK_MIGRATION.md` | High | High | High (≈40-line adapter rewrite + `yamori.txHistory.v1→v2` on-disk migration) | **PLAN** (execute on preview; tie wire-layer cutover to mainnet node 1.0.0 activation) |
| Migration doc drift | Doc §2 pin table is **stale**: `dust-wallet` is now 4.1.0 (doc says 4.0.0), `unshielded-wallet` 3.1.0 (doc says 3.0.0). Re-audit §2 before executing. | `npm view` vs doc | Med | None | Low | **PLAN** (doc refresh; pairs with the migration) |
| ledger landscape clarity | YAMORI's direct `@midnight-ntwrk/ledger` dep is still 4.0.0 and **stays put**; the "v8/8.1" line is the separate `ledger-v8` package that rides in transitively via facade 4.x. No direct `ledger` bump needed. | npm dist-tags | Med (removes confusion) | n/a | n/a | **note only** |
| compact-runtime minor | `^0.15.0` → 0.16.0 available. | npm | Low | Low | Trivial | **PLAN** (bundle with SDK4 or standalone) |
| MV3 / CSP / keepalive | Manifest clean: MV3, `minimum_chrome_version 116`, `'wasm-unsafe-eval'` CSP (required for prover WASM), SW keepalive via `chrome.alarms` + offscreen port ping. **No deprecations, no security regression.** | `public/manifest.json`, `service-worker.ts` | — | None | None | **DO NOT DO** (already correct) |
| Passkey/PRF | YAMORI uses WebAuthn PRF → BIP39 entropy → HKDF → AES-256-GCM vault. Graceful throw when PRF absent. Landscape improving (Win Hello PRF now works). | `src/popup/lib/passkey.ts` + web | Low | Low | — | **DO NOT DO** (current handling correct) |
| Store-build CSP hygiene | CSP `connect-src` includes `http://localhost:6300` (local prover) — harmless in dev, worth stripping from store builds to tighten CSP. | `manifest.json:44` | Low | Low | Trivial | **PLAN** (optional) |
| Dead build script | `build:offscreen` is known-broken (`Could not resolve "crypto"`) and `CONTRIBUTING.md` already warns never to run it; `npm run build` doesn't call it. Footgun. | `package.json:11` | Low | Low | Trivial | **PLAN** (optional: delete the dead script) |
| Version drift | `package.json` version `1.0.0` vs `manifest.json` `1.5.0`. Cosmetic. | files | Low | None | Trivial | **PLAN** (optional cleanup) |

---

## 5. CredentialGate upgrade opportunities

**Current model (verified from `CredentialGate.compact`):** signed selective disclosure with a Poseidon on-chain commitment — *not* in-circuit predicate ZK. Real guarantees today = **trusted-issuer-set membership** (`_trusted_issuers.member`, line 200) + **consensus expiry** (`blockTimeLt`, line 209). Issuer/wallet ed25519 signatures are asserted via **witnesses that the prover supplies** (Compact has no native `verify_signature`), and in all three deploy paths those witnesses are wired to `return true` (`deploy/{demo,e2e,deploy}.ts`). The demo does an independent off-chain ed25519 verify before submit, but that check is **not bound to the proof**.

| Area | Finding | Source/probe | Value | Risk | Effort | Recommendation |
|---|---|---|---|---|---|---|
| Real ed25519 in witness | The signature witnesses `return true` unconditionally; the genuine verify already exists in `demo.ts` but isn't run inside the prover. Wiring it into the witnesses is **off-chain, additive, zero deployed-contract risk** — and removes the most misleading stub. | `deploy/*.ts:81/233/109`; `verify-credential.ts` | High | Low | Low | **DO NOW** |
| Pragma upper bound | `pragma language_version >= 0.17` is open-ended → a future toolchain could silently bump language semantics. Pin `>= 0.17 && <= 0.23` to the validated band. | `CredentialGate.compact:38`; MCP band | Med | Med | Low | **PLAN** |
| SD-JWT-VC Phase 1 | `docs/SDJWTVC_MIGRATION.md` is sound; Phase-1 is an **off-chain adapter swap, contract untouched** (iss/kid→issuer_pk_hash, cnf.jwk→subject_binding, KB-JWT nonce→challenge, exp→expires_at). Standardizes the envelope. Note: SD-JWT-VC is signed-disclosure, **not** in-circuit ZK — it does not by itself change the on-chain proof. Bump doc refs draft-15→**draft-16**; `vc+sd-jwt`→`dc+sd-jwt` typ remains the top interop bug. | docs read + web | Med | Low | Med | **PLAN** |
| Revocation | **None** on- or off-chain — expiry is the only freshness mechanism; a compromised-but-unexpired credential can't be revoked. Adopt SD-JWT-VC status-list (RFC 9938 / `@sd-jwt/jwt-status-list`) checked off-chain in the witness; optionally a revoked-commitment `Set` on-chain. Keep expiry windows short meanwhile. | `CREDENTIALS_V1.md`; contract:209 | High | High | Med-High | **PLAN** |
| Issuer key rotation | Single long-lived ed25519 key; `keygen --force` invalidates every prior credential (no overlap). The contract's `Set<Bytes<32>>` trust set **already allows multiple concurrent issuer pk-hashes** — support overlapping rotation + a runbook; move key to HSM/KMS for real use. | `issuer/src/keys.ts` | Med | Med | Med | **PLAN** |
| On-chain replay | `record_verification` overwrites the stored record for `(subject, claim)` and the challenge is disclosed on-chain → re-submission freshness rests on verifier nonce discipline. Consider asserting supersession or a used-challenge set if replay-onto-chain matters. | contract:213-219 | Med | Med | Low | **PLAN** |
| Schnorr-on-JubJub (v2) | Compact stdlib **does** expose `ecMul`, `ecMulGenerator`, `ecAdd`, `hashToCurve`, `JubjubPoint`, Poseidon (`persistentHash`) — a Schnorr verify on JubJub is constructible in-circuit. **But** ed25519 (Edwards25519) ≠ JubJub, so issuers must re-key to JubJub; this is a new contract + domain tag + benchmark + fresh deploy (CredentialGate **v2**), not a drop-in. Adding curve ops materially raises proving time. | MCP `search-compact` (zswap.compact); memory research | High | High | High | **PLAN/WAIT** (design v2; **do not touch deployed `7ee02faf…`**) |
| Expiry anchor | `blockTimeLt` is consensus-enforced on every gate call — the model's strongest guarantee. | contract:209/249/267 | High | Low | — | **Keep** (preserve through any v2) |

---

## 6. Risk matrix

| Bucket | Items |
|---|---|
| **Safe & additive (DO NOW)** | apex `analytics/volume` routing fix · apex `dust-eligibility` caller/route fix · real ed25519 verify in CredentialGate prover witnesses |
| **Real value, needs tested change (PLAN)** | preprod :3006 dead-port repoint · 4 un-surfaced analytics cards · `/api/extrinsics/stats` route order · SDK 4.0 migration (preview first) · migration-doc §2 refresh · SD-JWT-VC Phase 1 · revocation status-list · issuer key rotation · pragma upper bound · CredentialGate v2 design |
| **Gated on external event/data (WAIT)** | SPO/stake/registration widgets (no mainnet data) · epoch utilization widget (federated zeros) · indexer schema (v4, nothing new) · ledger-v8 wire cutover (tie to mainnet node 1.0.0) · subscription/push UX |
| **Do not do** | governance endpoints (already complete) · MV3/CSP/keepalive/passkey changes (already correct) · touch deployed `7ee02faf…` verification logic · re-debug the resolved liveness/backup-file issue · reflexive `npm install`/SDK bump |
| **Dangerous items explicitly avoided this sweep** | no SDK upgrade · no npm install · no deploy · no nginx mutation · no vault/storage/signing code touched · no force-push/rebase/amend · no fabricated metrics or field names |

---

## 7. Ranked actions

### DO NOW (3 — safe, additive, verified)
1. **Fix apex `/api/analytics/volume` 404** — re-prefix-alias gap; flagship homepage volume chart blanks on apex only (200 on `mainnet.` subdomain).
2. **Fix apex `dust-eligibility`** — point `tools/dust-console.html:1349` at `/api/mainnet/dust-eligibility` (or add the apex `location`); bare path returns 200-HTML and breaks the dust console's fallback.
3. **Wire real ed25519 verify into CredentialGate prover witnesses** — kill the `return true` stubs; verify already exists in `demo.ts`, off-chain/additive, zero deployed-contract risk.

### PLAN (5 — top priority)
1. **Repoint preprod's 5 endpoints off dead port :3006** to `:3004` (live 502s in production; needs operator/sudo).
2. **Schedule the SDK 4.0 migration** on preview testnet per the 11-step plan; refresh doc §2 pins first (dust-wallet 4.1.0, unshielded 3.1.0).
3. **Add 4 un-surfaced analytics cards** (`extrinsic-types`, `tx-classification`, `epoch/utilization`, `midnight-txs`) — live data, no UI; WOW from real capability.
4. **CredentialGate revocation** via SD-JWT-VC status-list (off-chain witness check) + short expiry windows.
5. **Issuer key rotation** support (multiple concurrent trusted pk-hashes — contract already allows it) + HSM/KMS + runbook.

### WAIT (5 — gated)
1. SPO/stake/registration widgets — gated on Foundation populating mainnet SPO data.
2. Epoch-utilization widget on mainnet — federated-phase zeros until decentralization.
3. ledger-v8 8.1 wire cutover — tie to announced mainnet node 1.0.0 activation.
4. Indexer schema additions — none exist (v4 unchanged through 4.3).
5. CredentialGate v2 (in-circuit Schnorr-on-JubJub) — design + benchmark + issuer re-key; do not touch deployed contract.

### DO NOT DO (5)
1. Re-debug the apex liveness / `sites-enabled` backup-file issue — resolved, no regression.
2. Reflexive `npm install` / SDK bump on YAMORI — touches vault/storage/signing.
3. New governance endpoints — already complete and live.
4. MV3/CSP/keepalive/passkey rewrites — already correct.
5. Any force-push/rebase/amend or cross-env push — topology rules 5/6/15.

---

## REPORT

- **agents used:** 5 (YAMORI SDK/security · NightForge API/indexer · CredentialGate/Compact/proof · nginx/deploy/topology · frontend/tools discoverability), all read-only.
- **sources/probes:** live curl against apex + mainnet/preview/preprod subdomains; GraphQL introspection on the three public Foundation indexers; `ss -ltn`; `npm view` (registry); midnight MCP `get-latest-syntax`/`search-compact`/`check-version`; WebSearch (RFC 9901, SD-JWT-VC draft-16, OpenID4VP/DCQL, PRF); source reads of `server.ts`, `nightforge-main.html`, `deploy-all.sh`, `CredentialGate.compact`, `deploy/*.ts`, `passkey.ts`, `manifest.json`, `WALLET_SDK_MIGRATION.md`. Three headline defects re-verified by hand.
- **code changed:** NO
- **docs changed:** `mainnet-explorer/docs/UPGRADE_RADAR.md` (this file, new)
- **top 5 DO NOW:** apex `analytics/volume` 404 fix · apex `dust-eligibility` caller fix · CredentialGate prover real-ed25519 witness · (only 3 qualify as DO NOW; the rest are PLAN by risk rule)
- **top 5 PLAN:** preprod :3006 repoint · SDK 4.0 migration on preview · 4 un-surfaced analytics cards · CredentialGate revocation status-list · issuer key rotation
- **top 5 WAIT:** SPO/stake widgets · epoch-utilization widget · ledger-v8 wire cutover · indexer schema (none new) · CredentialGate v2 Schnorr-on-JubJub
- **top 5 DO NOT DO:** re-debug liveness/backup-file · reflexive SDK bump · new governance endpoints · MV3/CSP rewrites · force-push/cross-env push
- **dangerous items avoided:** SDK upgrade, npm install, deploy, nginx mutation, vault/storage/signing edits, force-push/rebase/amend, fabricated metrics/field names.
- **commit hash:** none (not committed)
- **pushed:** NO

*WOW must come from real capability. The four un-surfaced analytics endpoints and the CredentialGate real-verify witness are the highest-leverage "real WOW" items — all backed by data/code that already exists. No theater. Build only after approval.*
