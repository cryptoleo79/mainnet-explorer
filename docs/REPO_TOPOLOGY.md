# Repo Topology

Operator reference for the NightForge / YAMORI / CredentialGate stack.
Three networks, three local working trees, three GitHub repos, one
homepage source deployed to four nginx docroots.

If you read nothing else, read this: **each local working tree must point
at the GitHub repo whose name matches its own environment, and nothing
else. `git remote -v` is the only authoritative check.**

## A. Environment Map

| Environment | Local Repo | GitHub Repo | Domain(s) | Canonical Branch | Indexer Port | Docroot | Deploy Path |
|---|---|---|---|---|---|---|---|
| **Mainnet (canonical UI source)** | `/home/midnight/mainnet-explorer` | `cryptoleo79/mainnet-explorer` | `nightforge.jp` (apex), `mainnet.nightforge.jp` | `main` | `3005` (`midnight-mainnet-indexer.service`) | `/var/www/explorer-main`, `/var/www/explorer-mainnet` | `sudo bash scripts/deploy-all.sh` (from `mainnet-explorer`) |
| **Preview** | `/home/midnight/preview-explorer-new` | `cryptoleo79/preview-explorer` | `preview.nightforge.jp` | `preview-restore` (GitHub default) | `3000` (`midnight-preview-explorer.service`) | `/var/www/explorer-lite` | `sudo bash scripts/deploy-all.sh` (from `mainnet-explorer` — preview docroot is one of four targets) |
| **Preprod** | `/home/midnight/preprod-explorer` | `cryptoleo79/preprod-explorer` | `preprod.nightforge.jp` | `preprod-restore` (GitHub default) | `3004` (`midnight-preprod-indexer.service`) | `/var/www/explorer-preprod` | `sudo bash scripts/deploy-all.sh` (from `mainnet-explorer`) |
| **YAMORI** (wallet, separate stack) | `/home/midnight/YAMORI` | `cryptoleo79/YAMORI` | n/a (Chrome extension; release zip distributed manually) | `main` | n/a | n/a | `npm run build` → `yamori-v<X>.zip` |

### Adjacent infrastructure (not explorer environments)

| Item | Path | Purpose |
|---|---|---|
| Legacy NightForge repo | `cryptoleo79/NIGHTFORGE` | **Stale.** 1 commit, last pushed 2026-04-03. Not used. Candidate for archive — see [Safe Cleanup Candidates](#safe-cleanup-candidates). |
| Mainnet HTML legacy | `/home/midnight/nightforge-nft` → `cryptoleo79/NIGHTFORGE` → `nft.nightforge.jp` | Separate NFT site, out of scope for this topology. |
| Runtime-only dir | `/home/midnight/services/midnight-preview-indexer` | `WorkingDirectory=` for `main-indexer.service` on port `3003`. Not a git repo. Runtime artifacts only. |

## B. Rules

These are non-negotiable. A pre-push hook is recommended (see end of this doc) but not yet installed.

### Repo identity rules

1. **The local working tree's `git remote get-url origin` must match the environment.** A working tree of preview history must push to `cryptoleo79/preview-explorer.git`, never to `cryptoleo79/preprod-explorer.git` or anywhere else.
2. **`package.json` `name` field must match the environment**, i.e. `midnight-<env>-explorer`. This is the machine-checkable marker the pre-push hook reads.
3. **`src/config.ts` `network.name` must match the environment**, i.e. one of `'Midnight Mainnet' | 'Midnight Preview' | 'Midnight Preprod'`.
4. **Preview, preprod, and mainnet histories stay isolated.** No merge across them. No cherry-pick across them. They diverged on purpose.

### Branch rules

5. **No force-push on canonical branches.** Forward-only.
6. **No history rewrite on canonical branches.** No `git rebase -i`, no `git reset --hard` followed by a push, no `git commit --amend` after a push.
7. **No `--no-verify` on commit or push** unless explicitly authorized for the scope of that one command.

### Deploy rules

8. **`scripts/deploy-all.sh` is the only authoritative way to publish the NightForge UI.** No direct edits in `/var/www/<X>/`. No `scp` to a docroot.
9. **`sudo` is required** for the apex (`/var/www/explorer-main`) and preview (`/var/www/explorer-lite`) docroots because they are root-owned. The mainnet (`/var/www/explorer-mainnet`) and preprod (`/var/www/explorer-preprod`) docroots are `midnight:midnight` and do not need sudo, but `deploy-all.sh` requests sudo automatically only where needed.
10. **Per-env substitution is mandatory.** The source HTML contains `__NETWORK_LABEL__` and `__NETWORK_COLOR__` placeholders. A docroot that is published without going through `deploy-all.sh` will render the literal placeholders — loud and obviously broken — which is the intended fail-loud behavior.

### Routing / API rules

11. **No cross-environment API bleed.** Preview UI must hit the preview indexer, preprod UI must hit preprod, mainnet UI must hit mainnet. Each homepage derives its API root from `window.__NF_API` based on `location.hostname` — never hardcode `/api/mainnet/` in shared HTML.
12. **API path prefix matches the environment.** `/api/mainnet/*`, `/api/preview/*`, `/api/preprod/*`. The apex (`nightforge.jp`) is the one documented exception: it proxies bare `/api/*` straight to the mainnet indexer at `:3005`. This asymmetry is intentional and predates the per-env naming; do not "fix" it without a planned migration.

### Repo policy rules

13. **No AI attribution** in commit messages, PR bodies, or doc bodies in either repo. (`COMMIT_AND_PR_STYLE.md` is authoritative.)
14. **Commit scope prefix required** — `api | web | tools | explorer | data | nginx | docs | build | perf | ui | truth | fix | deploy`.
15. **Forward-only on `main`.** Any "fix" to a past commit is a new commit, not an amend.

## C. Recovery History

A single past incident shapes most of the rules above. Recorded here factually for operator context.

**2026-04-15 — Cross-repo push event.**
The local working tree at `/home/midnight/preview-explorer-new` was used to push preview history to a remote whose URL ended in `cryptoleo79/preprod-explorer.git`. The histories had diverged, so the push completed only because force was supplied. The preprod repo's `main` was overwritten with preview history.

**Detection lag — 31 days.** The local preprod indexer (port `3004`) was unaffected and continued running, but its WebSocket subscription stalled silently on 2026-04-20. Because the remote was already pointing at the wrong history, routine remote inspection did not surface the divergence between the local repo's purpose and what GitHub was advertising.

**Recovery posture chosen.** Recovery was done without force-push and without history rewrite. The genuine preprod history was pushed to a new branch `preprod-restore` on the preprod repo. The genuine preview history was pushed to a new branch `preview-restore` on the preview repo. The mis-pushed `main` branches were left in place as frozen references.

**Recovery completed 2026-05-29.** The GitHub default-branch switch on each repo (`cryptoleo79/preview-explorer` → `preview-restore`, `cryptoleo79/preprod-explorer` → `preprod-restore`) landed on 2026-05-29 and was verified by two independent methods (REST API `default_branch` field + `git ls-remote --symref HEAD`). A fresh `git clone` of either repo now lands on the correct history by default. The mis-pushed `main` branches remain as frozen references and are listed in Safe Cleanup Candidates below.

**Outcomes built into this stack.** The WebSocket freshness watchdog committed on `preprod-restore` at `f1e3c4e` is the durable detection mechanism for the silent-indexer-stall failure mode. The per-env `__NF_NET` / `__NF_API` / `__NF_RPC` conventions in `website/nightforge-main.html` are the durable mechanism for keeping UI and API in agreement. This `REPO_TOPOLOGY.md` document is the durable mechanism for keeping the local-dir-to-GitHub-repo mapping discoverable. The recommended pre-push hook below is the durable mechanism for preventing the mistake at the source.

No blame assigned. No emotional language. The mistake's root cause was structural — an undocumented topology where two local dirs could share one remote URL by typo. The structural fix is documentation, fail-loud placeholders, and a pre-push hook.

## Common confusions to avoid

These are the traps a new operator will hit in the first 24 hours. None are bugs; all are real surface area.

1. **`preprod` and `preview` differ by two letters.** The repo names also differ by only two letters. `git remote -v` is the only authoritative check; don't trust the directory name or memory.
2. **`preview-explorer-new/package.json` still says `"midnight-preprod-explorer"`.** Fossil from the original fork. This is the marker that fed the 2026-04-15 incident. Rename in the next preview commit.
3. **`mainnet-explorer/package.json` description says "Port 3001".** The service listens on `3005`. Stale, harmless, fix on next mainnet commit.
4. **`lite.nightforge.jp` and `preview.nightforge.jp` share `/var/www/explorer-lite`.** Same content, two hostnames. `lite.` is historical, `preview.` is operational.
5. **Apex `nightforge.jp` serves mainnet** (`/var/www/explorer-main`). It is not a separate environment.
6. **`midnight-preview-explorer.service` runs the preview indexer**, despite the word "explorer" in the unit name. Naming inconsistency with `midnight-preprod-indexer.service`. Not a bug, just a trap when grepping `systemctl`.
7. **`cryptoleo79/NIGHTFORGE` (uppercase) is the stale legacy repo.** The canonical NightForge UI repo is `cryptoleo79/mainnet-explorer` (lowercase). Do not confuse.
8. **`cryptoleo79/YAMORI` returns 404 from the unauthenticated REST API** but is fully accessible via `git ls-remote git@github.com:cryptoleo79/YAMORI.git`. The repo is private; the SSH key on this box has access. This is by design.

## Safe Cleanup Candidates

These are stale or accidental artifacts. Listed for operator review; **no destructive action is taken automatically**. Each line states what it is, why it is safe to remove, and the prerequisite (if any) before removing.

### GitHub branches

| Repo | Branch | Safe to delete? | Prerequisite |
|---|---|---|---|
| `cryptoleo79/preview-explorer` | `main` (LICENSE-only stub `9af6e8c`) | Yes — single auto-init commit, not part of preview history | None — default-branch switch landed 2026-05-29; deletable any time |
| `cryptoleo79/preprod-explorer` | `main` (mis-pushed preview code `88d9745`) | Yes — frozen artifact of 2026-04-15 incident, no value outside the historical record kept in this file | None — default-branch switch landed 2026-05-29; deletable any time |
| `cryptoleo79/preprod-explorer` | `feat/nightforge-trust-pass` (`8d123dc`) | Unknown — verify whether it merged into mainnet's `feat/nightforge-trust-pass` (`07f5af1`) or is independent work | Diff against mainnet's branch of the same name before deleting |
| `cryptoleo79/mainnet-explorer` | `feat/homepage-visual-hierarchy` (`ab5d522`) | Likely yes — UI work; check `git log --oneline main..feat/homepage-visual-hierarchy` to confirm no unmerged commits | Cross-check with current `main` HEAD |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-action-layer` (`706f152`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-contract-intelligence-and-address-lookup` (`cfb319c`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-data-hydration-pass` (`38c79b2`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-live-feeds-and-validator-dashboard` (`88052b6`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-pulse-and-epoch-intelligence` (`ea0b256`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/nightforge-trust-pass` (`07f5af1`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/observe-verify-loop` (`06d7f50`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/passport-alignment` (`2f754d4`) | Likely yes | Cross-check |
| `cryptoleo79/mainnet-explorer` | `feat/refinement-pass` (`bd56d1f`) | Likely yes | Cross-check |

### GitHub repos

| Repo | Safe to archive? | Prerequisite |
|---|---|---|
| `cryptoleo79/NIGHTFORGE` (legacy) | Yes — superseded by `cryptoleo79/mainnet-explorer`; last activity 2026-04-03 | Confirm `nightforge-nft` dir is what serves `nft.nightforge.jp` and does not depend on this repo for ongoing deploys |

### Local working trees

| Path | Cleanup | Prerequisite |
|---|---|---|
| `preview-explorer-new` uncommitted changes (5 modified `tools/*.html` files) | Commit, discard, or stash — currently unsafe to push | Review diffs and decide intent |
| `preprod-explorer` uncommitted changes (4 modified `tools/*.html` files) | Commit, discard, or stash | Review diffs and decide intent |
| `preview-explorer-new` local branch is still named `main` | Optional rename: `git branch -m main preview-restore && git branch --set-upstream-to=origin/preview-restore` | None — default-branch switch landed |
| `preprod-explorer` local branch is still named `main` | Optional rename: `git branch -m main preprod-restore && git branch --set-upstream-to=origin/preprod-restore` | None — default-branch switch landed |
| `preview-explorer-new` is `1 ahead / 18 behind` of (old) upstream `origin/main` | After local rename above, upstream becomes `origin/preview-restore`; local HEAD already matches it, so reconciliation reduces to nothing | None |
| `preprod-explorer` is `17 ahead / 22 behind` of (old) upstream `origin/main` | After local rename above, upstream becomes `origin/preprod-restore`; local HEAD already matches it | None |

### Files

| File | Cleanup | Prerequisite |
|---|---|---|
| `preview-explorer-new/package.json` `name: "midnight-preprod-explorer"` | Rename to `"midnight-preview-explorer"` | None — pure forward-only edit |
| `preview-explorer-new/package-lock.json` (same fossil) | Same rename | After `package.json` edit + `npm install` |
| `mainnet-explorer/package.json` description "Port 3001" | Correct to "Port 3005" | None |

## Recommended pre-push hook (defensive — not yet installed)

Add to each explorer repo's `.git/hooks/pre-push` (or `.githooks/pre-push` if `core.hooksPath` is set):

```sh
#!/usr/bin/env bash
# Refuse pushes when the local repo's environment identity disagrees with
# the remote URL. Reads `package.json:name` (which must match
# `midnight-<env>-explorer`) and compares against the remote URL ending.
set -e
remote_url=$(git remote get-url "$1" 2>/dev/null || true)
expected_env=$(node -p "require('./package.json').name.replace('midnight-','').replace('-explorer','')" 2>/dev/null || true)
case "$remote_url" in
  *"${expected_env}-explorer.git") ;;  # OK
  *)
    echo "REFUSING push: remote $remote_url does not match package.json env '${expected_env}'"
    exit 1
    ;;
esac
```

Install only with operator approval. The `deploy-all.sh` script and the env-aware homepage already make environment confusion *visible* at deploy time; this hook makes a push-time *mistake* impossible.

## Cross-references

- `docs/DEPLOY_FLOW.md` — exact deploy command, repo→docroot mapping, sudo requirements, post-deploy verification checklist.
- `docs/SESSION_STATE.md` — current operational posture, latest commits, deferred items.
- `docs/COMMIT_AND_PR_STYLE.md` — scope prefixes, message format, banned words.
- `docs/OBSERVATION_MODE.md` — what is frozen at the current milestone.
- `docs/BUG_BACKEND_TIMEOUTS.md` — backend endpoints timing out; not part of topology but tracked.
- WebSocket freshness watchdog — commit `f1e3c4e` on `cryptoleo79/preprod-explorer:preprod-restore`.
- Per-env coherence — `window.__NF_NET` / `__NF_API` / `__NF_RPC` in `website/nightforge-main.html`.
