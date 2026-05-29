# SESSION_STATE.md — NightForge / YAMORI / CredentialGate

Snapshot of where this stack stands. Update at the end of each working session.

## Current operational posture: OBSERVATION MODE

NightForge, YAMORI, and CredentialGate are considered operational. The next milestone is **someone else using them**, not more features. New work is restricted to:

- structural / topology hygiene (this session's class)
- documentation
- truth-rule fixes (no fake values, no static "live" theater)
- bug fixes triggered by observed behavior

Out of scope: new features, new widgets, new APIs, SDK upgrades, storage migrations, contract changes, UI redesign, deploy-behavior changes.

See `OBSERVATION_MODE.md` for the frozen-surface list.

## Current stable state

### NightForge — `/home/midnight/mainnet-explorer`

| field | value |
|---|---|
| Origin remote | `git@github.com:cryptoleo79/mainnet-explorer.git` |
| Canonical branch | `main` |
| Local HEAD | `d45862e ui: separate explorer nav from hero` |
| `origin/main` | `d45862e` (in sync) |
| Last deploy mtime | `2026-05-26 06:13:21 UTC` on all four docroots |
| Deploy command | `sudo bash scripts/deploy-all.sh` |
| Live env labels | apex + mainnet show `Mainnet`; preview shows `Preview`; preprod shows `Preprod`; all four `/api/*/stats` return matching `network` strings |

Four-domain map (see `REPO_TOPOLOGY.md` for full topology):

| domain | env | docroot | indexer port |
|---|---|---|---|
| `nightforge.jp` | Mainnet | `/var/www/explorer-main` | `3005` |
| `mainnet.nightforge.jp` | Mainnet | `/var/www/explorer-mainnet` | `3005` |
| `preview.nightforge.jp` | Preview | `/var/www/explorer-lite` | `3000` |
| `preprod.nightforge.jp` | Preprod | `/var/www/explorer-preprod` | `3004` |

### YAMORI — `/home/midnight/YAMORI`

| field | value |
|---|---|
| Origin remote | `git@github.com:cryptoleo79/YAMORI.git` (private; SSH only, REST API returns 404 unauthenticated) |
| Canonical branch | `main` |
| Local HEAD | `0c0414a docs: expand sdk 4 migration plan after fresh audit` |
| Latest release | **v1.5.0** at `/home/midnight/YAMORI/yamori-v1.5.0.zip` |
| All release zips | v1.1.0, v1.2.0, v1.3.0, v1.4.0, v1.5.0 |
| Chrome vault | **DO NOT TOUCH** |
| Issuer flow | live (`gen-issuer`, `issue`, `verify-credential`) |

### CredentialGate

| field | value |
|---|---|
| Active contract | `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703` |
| Network | Midnight Preview |
| Verified addresses match | `website/nightforge-main.html`, `website/credential-gate.html`, `contracts/credential-gate/deploy/.../deployment.json` all agree |
| E2E status | fail → prove → pass green on preview |
| **Proof model** | **Signed disclosure** — issuer ed25519 over a credential payload, verified out-of-circuit. **NOT full ZK predicate verification.** The `_verify_issuer_sig` witness is a placeholder that returns true; a real in-circuit Schnorr-on-JubJub verification is the queued upgrade path (see deferred items). |
| UI surface | hero card at the top of the NightForge homepage (mainnet-only liveness widget) |

## Latest deployed NightForge commit

`d45862e ui: separate explorer nav from hero` — pushed to `origin/main`, deployed to all four docroots at 2026-05-26 06:13Z. Branch state: in sync, no unpushed commits.

## Topology repair state

The 2026-04-15 cross-repo accident is fully recovered as of 2026-05-29. Status:

| step | status |
|---|---|
| Preview history pushed to `cryptoleo79/preview-explorer:preview-restore` (`88d9745`) | ✅ done |
| Preprod history pushed to `cryptoleo79/preprod-explorer:preprod-restore` (`f1e3c4e`) | ✅ done |
| GitHub default branch on `preview-explorer` → `preview-restore` | ✅ done 2026-05-29 (verified REST API + `git ls-remote --symref HEAD`) |
| GitHub default branch on `preprod-explorer` → `preprod-restore` | ✅ done 2026-05-29 (verified REST API + `git ls-remote --symref HEAD`) |
| `preview-explorer-new` working tree uncommitted (5 files in `tools/`) | ⚠ pending review |
| `preprod-explorer` working tree uncommitted (4 files in `tools/`) | ⚠ pending review |
| `preview-explorer-new` local branch still named `main` | optional rename to `preview-restore` (see REPO_TOPOLOGY.md § Safe Cleanup Candidates) |
| `preprod-explorer` local branch still named `main` | optional rename to `preprod-restore` (see REPO_TOPOLOGY.md § Safe Cleanup Candidates) |

Class-of-mistake closed. A fresh `git clone` of either repo now lands on the correct canonical history by default.

See `REPO_TOPOLOGY.md` § Recovery History for the operational summary, and § Safe Cleanup Candidates for the post-switch cleanup list.

## Latest known bug

**Nav / hero visual collision** — resolved last session in `d45862e`. The sticky `z-40` glass-card surface that overlapped the CredentialGate hero on scroll was replaced with a plain transparent row inside `mt-4 mb-6`. Live verification clean on all four docroots since 2026-05-26.

No new bugs logged this session.

## Deferred items

| item | status | reason |
|---|---|---|
| GitHub default-branch switch on preview-explorer and preprod-explorer | **DONE 2026-05-29** | Both repos now point HEAD at their canonical `*-restore` branch. Verified REST API + `git ls-remote --symref HEAD`. |
| `nightforge.app` DNS | not configured | Apex domain `nightforge.jp` serves Mainnet today. `nightforge.app` is not currently wired to this stack. Deferred until product positioning is final; meanwhile any external reference should point at `nightforge.jp`, not `.app`. |
| `preview-explorer-new/package.json` `name: "midnight-preprod-explorer"` rename | not done | fossil from original fork; pure forward-only edit when convenient |
| `mainnet-explorer/package.json` description "Port 3001" correction | not done | should read 3005 |
| Pre-push hook | not installed | template in `REPO_TOPOLOGY.md`; install in each explorer repo with operator approval |
| `/tools/index.html` parity on preview + preprod indexer dirs | not synced | mainnet has 20 cards (incl. DUST Console, Privacy Flow); preview/preprod still 17. Manual copy needed — `deploy-all.sh` does not manage `/tools/` |
| `BUG_BACKEND_TIMEOUTS.md` endpoints | logged, not fixed | `analytics/bridge`, `live/dust-rate`, `live/shielded-rate`, `epoch/current` |
| `/governance.html` SPA route gap | not fixed | `.html` suffix lands on Overview instead of Governance tab |
| `tools/passport-ready.html` restore | held | awaiting explicit user confirmation it's a shipped feature |
| `wallet-sdk-facade@4.0.1` upstream patch | waiting | unshipped 25+ days; YAMORI SDK 4.0 migration **deferred** until shipped |
| midnight-node #1206 + #1374 shield blocker | waiting | both still open upstream |
| Mainnet DUST HRP mismatch (#1397) | waiting | Foundation-side |
| Indexer v4.2/v4.3 rollout | waiting | all three envs still v4.1-class |
| Chrome 147 PRF-on-create | waiting | revisit at GA |
| SD-JWT-VC draft-17 / WGLC | waiting | revisit ~2026-07-17 |
| YAMORI manifest `minimum_chrome_version` 116 → 132 | queued | pairs with next zip cut; surfaces CVE-2026-7952 floor + stable PRF |
| CredentialGate Schnorr-on-JubJub design doc | queued | 1-2 day pass; do not touch contract code without design review |
| MIP-0002 ShieldedReceive field-order fix (#124) in YAMORI parser | queued | merged upstream |
| MPS-0012 Account Aliasing (#123) in YAMORI address book | queued | merged upstream |

## Known limitations

- **Apex API asymmetry.** `nightforge.jp` serves bare `/api/*` direct from the mainnet indexer at `:3005`. The other three hosts use `/api/<env>/*`. Intentional, predates the per-env naming convention; do not "fix" without a planned migration.
- **`midnight-preview-explorer.service` is the preview indexer**, despite the word "explorer" in the unit name. Naming inconsistency with `midnight-preprod-indexer.service`. Not a bug.
- **`cryptoleo79/YAMORI` REST API returns 404** unauthenticated — repo is private. SSH access works fine.
- **`cryptoleo79/NIGHTFORGE` (uppercase) is the stale legacy repo.** Last activity 2026-04-03. Canonical NightForge UI is `cryptoleo79/mainnet-explorer` (lowercase). Listed as archive candidate in `REPO_TOPOLOGY.md`.
- **10 stale `feat/*` branches** on `cryptoleo79/mainnet-explorer`. All from completed work; cross-check before delete. Listed in `REPO_TOPOLOGY.md` § Safe Cleanup Candidates.

## Repo rules (summary)

- **No force-push.** Forward-only on `main` for all repos.
- **No history rewrite.** Any "fix" is a new commit.
- **No AI attribution** in commits, PR bodies, or docs.
- **Commit scope prefix required** — see `COMMIT_AND_PR_STYLE.md` for allowed scopes.
- **`deploy-all.sh` is the only authoritative way** to publish the NightForge UI. No direct edits to `/var/www/*`.
- **Each local explorer working tree must point at the matching GitHub repo.** Pre-push hook recommended in `REPO_TOPOLOGY.md`.

## See also

- `REPO_TOPOLOGY.md` — repo / env / branch / domain mapping, rules, recovery history, safe cleanup candidates.
- `DEPLOY_FLOW.md` — exact deploy command, target mapping, post-deploy verification checklist.
- `OBSERVATION_MODE.md` — what is frozen at the current milestone.
- `COMMIT_AND_PR_STYLE.md` — commit / PR standard.
- `BUG_BACKEND_TIMEOUTS.md` — captured backend timeout endpoints.
- `RESEARCH_UPDATE_SWEEP.md` — most recent ecosystem intelligence sweep.
- `EXTERNAL_VALIDATION.md` + `TESTER_BRIEF.md` + `HANDOFF_PACKAGE.md` — external tester handoff materials.
