# SESSION_STATE.md — NightForge / YAMORI / CredentialGate

Snapshot of where this stack stands. Update at the end of each working session.

## Deployed state

### NightForge — `/home/midnight/mainnet-explorer`

| domain | env | role |
|---|---|---|
| nightforge.jp | mainnet | apex |
| mainnet.nightforge.jp | mainnet | env-scoped |
| preview.nightforge.jp | preview | env-scoped |
| preprod.nightforge.jp | preprod | env-scoped |

- Deploy: `sudo bash scripts/deploy-all.sh` (writes to 4 `/var/www/<X>/` docroots)
- Last homepage push: `fd07738 ui: improve explorer nav spacing` (2026-05-25)
- Origin: `git@github.com:cryptoleo79/NIGHTFORGE.git`, default branch `main`, **forward-only**

Truth rules in force:
- no fake values
- no static "live" theater
- no preview/mainnet API bleed (each env hits its own backend)
- correct env label on first paint

### YAMORI — `/home/midnight/YAMORI`

- Latest zip: `/home/midnight/YAMORI/yamori-v1.5.0.zip`
- SDK 4.0 migration: **deferred** (wallet-sdk-facade@4.0.1 patch still unshipped upstream as of 2026-05-25)
- Chrome vault: **do not touch**
- Repo: `cryptoleo79/yamori`, **forward-only**

### CredentialGate

- Active preview contract: `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`
- fail → prove → pass E2E green on preview
- Hero card lives at the top of the NightForge homepage (mainnet-only liveness widget)

## Latest known bug

**Nav / hero visual collision** (logged this session, fix in progress):
- Sticky `topNav` with `z-40` glass-card surface overlapped the CredentialGate hero on scroll.
- Fix: drop sticky + glass surface, plain row between header and hero with `mt-4 mb-6`.

## Open / deferred items

| item | status | reason |
|---|---|---|
| Preview-explorer push (`/home/midnight/preview-explorer-new` → `cryptoleo79/preview-explorer`) | **blocked** | remote main has unrelated LICENSE auto-init commit `9af6e8c`. Local `88d9745` can't fast-forward. User must pick: recreate empty / push to new branch / authorize one-time force |
| `/tools/index.html` parity on preview + preprod docroots | not deployed | mainnet/apex have DUST Console + Privacy Flow cards; preview/preprod still serve old 13,863-byte index. Needs `deploy-all.sh` patch |
| Backend timeouts | logged in `BUG_BACKEND_TIMEOUTS.md` | analytics/bridge, live/dust-rate, live/shielded-rate, epoch/current |
| `/governance.html` SPA route gap | not fixed | `.html` suffix lands on Overview instead of Governance tab. One-line route fix held |
| `tools/passport-ready.html` restore | held | awaiting explicit user confirmation it's a shipped feature, not experimental |
| Indexer v4.3 wire-up | queued | swap RPC heuristics for live GraphQL (spoIdentities, currentEpochInfo, dustGenerationStatus, committee, dParameterHistory) |
| CredentialGate Schnorr-on-JubJub | queued | migrate `_verify_issuer_sig` from witness-stub to real in-circuit verification, pin `pragma >= 0.22 && <= 0.23` |
| YAMORI manifest `minimum_chrome_version` 116 → 132 | queued | CVE-2026-7952 floor + Win Hello PRF baseline |
| MIP-0002 ShieldedReceive field-order fix (#124) in YAMORI | queued | merged upstream |
| MPS-0012 Account Aliasing (#123) in YAMORI address book | queued | merged upstream |
| 3 borrowed UX patterns | queued | view-key decrypt toggle, validator state ribbon, dimensional fee breakdown |
| Midnames preprod lookup | queued | live on preprod, needs resolver wired into NightForge + YAMORI |

## Repo rules

- **No force-push.**
- **No merge-rewriting history.** Forward-only on `main` for all repos.
- **No AI attribution** in commits or PR bodies.
- Commit style: scope prefix (`ui:`, `truth:`, `tools:`, `docs:`, `deploy:`, `fix:`) — see `COMMIT_AND_PR_STYLE.md`.

## Repo / docroot topology

See `REPO_TOPOLOGY.md` for the full repo ⇄ docroot mapping. Key rule: never point preview at the preprod repo (this exact mistake is what caused the preview-explorer push blocker).

## See also

- `BUG_BACKEND_TIMEOUTS.md` — captured backend timeout endpoints
- `REPO_TOPOLOGY.md` — explorer repo topology + collision-prevention rules
- `COMMIT_AND_PR_STYLE.md` — commit message + PR body standard
- `RESEARCH_UPDATE_SWEEP.md` — 2026-05-18 intelligence sweep
- `EXTERNAL_VALIDATION.md` + `TESTER_BRIEF.md` — external tester handoff
