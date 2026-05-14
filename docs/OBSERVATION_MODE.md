# Observation Mode

NightForge, YAMORI, and CredentialGate are considered operational. The
next milestone is **someone else using them**, not more features.

## Current stable state (2026-05-13)

- **NightForge** — four domains live, deploys synced 2026-05-12 03:16 UTC:
  - `nightforge.jp`, `mainnet.nightforge.jp` → Mainnet (text-green-400)
  - `preview.nightforge.jp` → Preview (text-cyan-400)
  - `preprod.nightforge.jp` → Preprod (text-orange-400)
  - First-paint network label correct on all four; no placeholder, no safety-fallback script.
  - `/api/stats` returns JSON on all four hosts.
- **YAMORI** — `main` clean, in sync with `origin/main` at `22a8074`. Extension
  dist built 2026-05-11. Issuer flow live (gen-issuer + issue + verify-credential)
  and shipped to origin.
- **CredentialGate** — preview deployment at
  `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`,
  deploy tx `cf00cff58be5300a0d6ea6e42b46a98528de28e3d976e5141bde82f4a21d2c4e`,
  block 454,958, 2026-04-25. `deployment.json` matches the hardcoded
  hero address in `website/nightforge-main.html`.
- **Repo policy** — commit-msg hook + CI enforce scope-prefixed commits,
  forward-only history, no AI attribution. Verified clean for last 15
  commits on both repos.
- **Demo** — `npm run demo:clean` is reproducible against the active
  preview contract. Independent ed25519 verify of the issued credential
  runs before any on-chain transaction; demo refuses to continue on
  signature failure.

## What is frozen

- All UI HTML and CSS
- Wallet popup, background, offscreen code
- Compact contracts (`CredentialGate.compact`, `gated-swap.compact`)
- Deploy scripts (`scripts/deploy-all.sh`, `contracts/credential-gate/deploy/*`)
- API endpoints and shapes
- Demo flow

## Allowed fixes (no new scope)

1. Real bugs reproducible on the live system
2. Correctness issues (wrong label, wrong number, wrong status)
3. Trust issues (fake values, undisclosed limitations, misleading copy)
4. Broken deploy or runtime behavior
5. Documentation that is factually wrong

## Not allowed in observation mode

- New features
- New pages or UI sections
- New metrics
- Identity-platform scope expansion
- ZK claims (current backend is signed disclosure)
- Competitor comparisons
- Fake or live-looking placeholder data

## Known non-blocking limitations

- **CredentialGate liveness route** on 3 of 4 hosts:
  `/api/credential-gate/liveness` is proxied only on
  `mainnet.nightforge.jp`. On `nightforge.jp`, `preview.nightforge.jp`,
  and `preprod.nightforge.jp` nginx falls through to the SPA. The
  client guards against the non-JSON response (Content-Type check +
  4 s `AbortSignal.timeout`), so there is no 336 KB body download and
  no console error — the hero tile simply stays on its em-dash
  "Awaiting indexer data" state on those hosts. **Fix is a one-line
  nginx `location` block + reload on the three affected vhosts; needs
  operator with sudo.**
- **Wallet SDK 4.0 migration** (YAMORI) — `@midnight-ntwrk/wallet-sdk-facade@4.0.0`
  shipped 2026-04-23 but no `4.0.1` patch yet. YAMORI remains on
  `^3.0.0`. The migration plan lives at `YAMORI/docs/WALLET_SDK_MIGRATION.md`.
  Coordinated bump deferred until `4.0.1` lands or mainnet runtime 1.0.0
  cutover forces it.
- **Shield blocker upstream** — `midnight-node` issues `#1206`
  (`AllCommitmentsSubsetCheckFailure` on shielded mint) and `#1374`
  (sister EffectsCheckFailure on `sendShielded`) are both open with no
  PR linked. `toolkit-1.0.0-rc.6` (2026-05-12) does not include a fix
  for either. YAMORI's `mainnetConfirmed` gate keeps the shield UI off
  until upstream lands a fix. Tracked by a scheduled remote agent
  (`trig_01APqfwv2SG5ckmhL5UYJJBK`) re-checking weekly.
- **YAMORI header link `/yamori.html` is apex-only.** The file lives at
  `/var/www/explorer-main/yamori.html` (45,650 bytes, mtime 2026-04-16)
  and is **not** in the source repo. `scripts/deploy-all.sh` copies
  `index.html` and `credential-gate.html` only, so the other three
  docroots never received `yamori.html`. On `mainnet.nightforge.jp`,
  `preview.nightforge.jp`, and `preprod.nightforge.jp` the URL
  `/yamori.html` returns HTTP 200 but is the 336 KB SPA fallthrough —
  the user clicks "YAMORI" and the page appears not to change.
  Recorded 2026-05-13. Fix proposal (Option A in that day's report):
  put `yamori.html` under source control and add a `deploy_file` step
  in `deploy-all.sh`. Pending operator decision; non-blocking for the
  external test plan.

## Next validation task

External user/dev run-through per `docs/EXTERNAL_TEST_PLAN.md`. Record
where reality pushes back: confusion, friction, things that look real
but aren't, things that need explanation. Treat the run-through as the
test, not the demo.

End of observation log.
