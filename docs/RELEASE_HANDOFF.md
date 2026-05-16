# Release Handoff

Operator-facing snapshot of the system as it stands before the next
external validation pass. Update this file when state shifts; do not
add aspirational claims.

## Current stable state (2026-05-16)

| Surface | Version / state | Path |
|---|---|---|
| YAMORI Chrome extension | **v1.5.0** | `/home/midnight/YAMORI/yamori-v1.5.0.zip` (6,502,023 bytes, 52 files, manifest_version 3, minimum_chrome_version 116) |
| YAMORI dist (unpacked) | `1.5.0`, built `2026-05-14T23:34:41Z` from `main @ 22a8074` | `/home/midnight/YAMORI/dist/` |
| YAMORI repo | `main @ 138369c` (1 commit ahead of origin until pushed) | `/home/midnight/YAMORI/` |
| CredentialGate contract | live on Midnight **preview** | `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703` |
| CredentialGate deploy tx | `cf00cff58be5300a0d6ea6e42b46a98528de28e3d976e5141bde82f4a21d2c4e` block 454,958, 2026-04-25 | `contracts/credential-gate/deploy/deployment.json` |
| CredentialGate circuits | `add_issuer`, `prove_kyc`, `swap`, `can_swap` | unchanged since commit `f19d698` |
| Issuer CLI | three commands: `gen-issuer`, `issue`, `verify-credential` | `contracts/credential-gate/issuer/` |
| NightForge mainnet-explorer repo | `main @ 39ca84d` (in sync with origin) | `/home/midnight/mainnet-explorer/` |
| NightForge live docs | `OBSERVATION_MODE.md`, `EXTERNAL_TEST_PLAN.md`, `EXTERNAL_VALIDATION.md`, `FRICTION_LOG_TEMPLATE.md`, `RELEASE_HANDOFF.md` (this file) | `docs/` |

## NightForge domains (deploys synced 2026-05-14)

| URL | network label | network color | yamori.html | /api/credential-gate/liveness |
|---|---|---|---|---|
| https://nightforge.jp | Mainnet | green | 45,650 B (real) | HTML fallthrough (limitation) |
| https://mainnet.nightforge.jp | Mainnet | green | 45,650 B (real) | JSON (correct) |
| https://preview.nightforge.jp | Preview | cyan | 45,650 B (real) | HTML fallthrough (limitation) |
| https://preprod.nightforge.jp | Preprod | orange | 45,650 B (real) | HTML fallthrough (limitation) |

All four serve the env-correct label on first paint with zero safety-fallback
script refs and zero placeholders.

## Known limitations (non-blocking for external validation)

1. **CredentialGate liveness route** is proxied only on `mainnet.nightforge.jp`.
   The three other hosts fall through to the SPA HTML. Client-side
   Content-Type guard prevents the 336 KB body download; the hero tile
   stays on its em-dash "Awaiting indexer data" state. Fix is a one-line
   nginx `location /api/credential-gate/ { proxy_pass http://localhost:3005; }`
   block per affected vhost. Operator-with-sudo task.

2. **Preview + preprod nginx API gaps** (`/api/extrinsics`,
   `/api/validators/liveness`, `/api/epoch/current`). Preview falls
   through to SPA; preprod returns 502 for the first two and 404 HTML
   for `/api/epoch/current`. Mainnet vhost has the routes. Same shape
   as limitation 1 — nginx config + reload.

3. **One hardcoded tile** at `website/nightforge-main.html:2373`:
   `<p id="epochBlocksPerEpoch">~50</p>`. The tile is styled like a
   live-data tile but no JS writes to it. Smallest fix: replace `>~50<`
   with `>&mdash;<` + `title="Awaiting indexer data"`. Truth-rule
   correctness item; not blocking validation.

4. **Mainnet DUST HRP mismatch** (upstream — Foundation). The mainnet
   indexer rejects `mn_addr` HRP because it hardcodes `mn_addr_preprod`.
   Multiple users have reported on the forum; no Foundation fix yet
   (thread `forum.midnight.network/t/.../1209`, 8 days open at the
   time of this write-up). Downstream effect: DUST generation does not
   work on Midnight Mainnet for anyone. NightForge's mainnet DUST
   Console correctly em-dashes through this — the em-dashes are honest.

5. **Shield blocker upstream** — `midnight-node#1206`
   (`AllCommitmentsSubsetCheckFailure` on shielded mint) and `#1374`
   (sister EffectsCheckFailure on `sendShielded`) are both open with
   no PR linked. `toolkit-1.0.0-rc.6/7/8` do not include a fix.
   YAMORI's `mainnetConfirmed` gate keeps shield UI off until upstream
   lands a fix. A scheduled remote routine
   (`trig_01APqfwv2SG5ckmhL5UYJJBK`) re-checks weekly.

6. **wallet-sdk-facade@4.0.1 patch** has not shipped (23 days since
   4.0.0). YAMORI stays on `^3.0.0` until either 4.0.1 lands or mainnet
   runtime 1.0.0 cutover forces it. Plan at `YAMORI/docs/WALLET_SDK_MIGRATION.md`.

7. **BUILD.txt vs HEAD discrepancy** in the v1.5.0 zip — `BUILD.txt`
   records the commit the zip was built from (`22a8074`), not the
   commit that ships the zip on `main` (`138369c`). This is the
   build-before-commit pattern; not a tamper signal. Auditors should
   know which commit BUILD.txt actually references.

## What NOT to claim

- **Zero-knowledge** — the credential system is **signed selective
  disclosure** with ed25519. The on-chain checks are issuer-set
  membership + `blockTimeLt` expiry. Witnesses attest off-chain
  signature verification. **Do not call this ZK** until a real ZK
  predicate backend lands.
- **Mainnet shield works** — it does not. The wallet correctly gates
  the shield path; do not market mainnet shield as functional.
- **Mainnet DUST works** — currently broken upstream; the wallet and
  explorer correctly show em-dashes. Do not show fake DUST values.
- **"First wallet to do X"** — do not make first-mover claims without
  verifiable evidence. The competitive framing is intentionally absent.
- **Speed benchmarks** — do not publish unverified latency numbers.
  TTFB and total transfer are visible via curl; cite those if needed.

## What NOT to change in this window

Per `docs/OBSERVATION_MODE.md`, do not modify:

- Wallet popup, background, offscreen, content, or injected code
- Compact contracts (`CredentialGate.compact`, `gated-swap.compact`)
- API endpoints or response shapes
- `scripts/deploy-all.sh` (template only, hands-off until next release)
- CSS / Tailwind classes on visible pages

Allowed changes (small, correctness-oriented):
- Documentation factual corrections
- The single hardcoded `epochBlocksPerEpoch` tile if you choose to fix
  it before validation; otherwise leave it.
- nginx config to close routing gaps (sudo)
- Push of the unpushed YAMORI release commit `138369c`

## What still needs your sudo

1. Push the YAMORI release commit:
   ```sh
   cd /home/midnight/YAMORI && git push origin main
   ```
2. Optionally close the preview/preprod API nginx gaps with three
   `location` blocks matching the mainnet vhost's API proxy. Same
   pattern as the existing `/api/credential-gate/` block.

## Scheduled remote routine

`trig_01APqfwv2SG5ckmhL5UYJJBK` — weekly recheck of `midnight-node#1206`
and `#1374` status, testnet RPC version, and any new shield-related
issues. Next fire is automated; nothing for the operator to do.

End of handoff.
