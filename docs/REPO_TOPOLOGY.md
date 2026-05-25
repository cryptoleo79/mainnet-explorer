# Repo Topology — Explorers, Indexers, Domains

Operator reference. The accidental cross-repo force-push of 2026-04-15
(preview history written over preprod's `main`) and the 31-day silent
preprod-indexer stall it masked were both downstream of a topology that
was never documented and that allowed two local working trees to share
one GitHub remote. This file exists so that mistake is impossible to
repeat.

## TL;DR

Three networks. Three local working trees. Three GitHub repos. One
homepage source (this repo) deployed to four nginx docroots. **Each
local dir must point at the GitHub repo of its own name. No exceptions.**

## Topology map

| local dir | GitHub repo | environment | indexer service | port | nginx docroot | UI hosts | API path |
|---|---|---|---|---|---|---|---|
| `/home/midnight/mainnet-explorer` | `cryptoleo79/mainnet-explorer` | Mainnet (+ shared NightForge UI source) | `midnight-mainnet-indexer` | **3005** | `/var/www/explorer-main`, `/var/www/explorer-mainnet` | `nightforge.jp` (apex), `mainnet.nightforge.jp` | `/api/mainnet/*` |
| `/home/midnight/preview-explorer-new` | `cryptoleo79/preview-explorer` | Preview | `midnight-preview-explorer` | **3000** | `/var/www/explorer-lite` | `preview.nightforge.jp`, `lite.nightforge.jp` (alias) | `/api/preview/*` |
| `/home/midnight/preprod-explorer` | `cryptoleo79/preprod-explorer` | Preprod | `midnight-preprod-indexer` | **3004** | `/var/www/explorer-preprod` | `preprod.nightforge.jp` | `/api/preprod/*` |

Out of scope for this doc but on the same box:
- `/home/midnight/nightforge-nft` → `cryptoleo79/NIGHTFORGE` → `nft.nightforge.jp`
- `/home/midnight/services/midnight-preview-indexer` is the runtime dir for `main-indexer.service` (port **3003**) — not a git repo, runtime artifacts only.

## Canonical branch per repo

| repo | canonical branch | notes |
|---|---|---|
| `cryptoleo79/mainnet-explorer` | `main` | clean. Default branch on GitHub. |
| `cryptoleo79/preview-explorer` | `main` | **pending** — remote `main` currently holds only the GitHub LICENSE auto-init commit `9af6e8c`. Local `main` (`88d9745`) cannot fast-forward over it. Resolution requires either recreating the repo empty, pushing to a `preview-restore` branch and switching the GitHub default, or a one-time authorized force-push. **No history rewrite without explicit approval.** |
| `cryptoleo79/preprod-explorer` | **`preprod-restore`** (pending default-branch switch in GitHub Settings) | Remote `main` (`88d9745`) is preview code from the 2026-04-15 cross-repo accident — frozen, not deleted. The genuine preprod history lives on the `preprod-restore` branch at `f1e3c4e` (includes the WebSocket freshness watchdog). The repo also has `feat/nightforge-trust-pass` as a working branch. |

## NightForge UI deploy

The four docroots above are populated from this repo by `scripts/deploy-all.sh`:

- Source: `website/nightforge-main.html` (one file)
- Targets: `/var/www/explorer-main`, `/var/www/explorer-mainnet`, `/var/www/explorer-lite`, `/var/www/explorer-preprod`
- Per-env substitution: `__NETWORK_LABEL__` → `Mainnet|Preview|Preprod`, color tokens, etc.
- Requires `sudo` because docroots are root-owned.

`/api/<env>/*` is served by the indexer Express server in each env's dir, fronted by nginx with a per-host `location /api/` proxy.

## Common confusions to avoid

1. **Same name, different prefix.** `cryptoleo79/preprod-explorer` and `cryptoleo79/preview-explorer` differ by two letters. `git remote -v` is the only authoritative check. Don't rely on memory.
2. **`preview-explorer-new/package.json` still says `"midnight-preprod-explorer"`.** Fossil from the original clone — the dir was forked off preprod and the package.json was never renamed. This is what fed the 2026-04-15 incident: an automated check that read `package.json` to identify the network would have agreed with whichever remote `git push` was targeting. **Rename to `midnight-preview-explorer` in the next preview commit.**
3. **`mainnet-explorer/package.json` description says "Port 3001".** The service actually listens on 3005. Stale, harmless, but should be corrected on the next mainnet commit.
4. **`lite.nightforge.jp` and `preview.nightforge.jp` share `/var/www/explorer-lite`.** Same content, two hostnames. Not a bug. `lite.` is the historical name; `preview.` is the operational one.
5. **Apex `nightforge.jp` serves mainnet** (`/var/www/explorer-main`). It is NOT a separate environment.
6. **`midnight-preview-explorer.service`** runs the preview indexer despite the word "explorer" in the unit name — naming inconsistency with `midnight-preprod-indexer.service` (which calls itself an indexer). Not a bug, just a trap when grepping `systemctl`.

## Naming convention going forward

Forward-only convention. Do not rename existing dirs/repos retroactively.

- **GitHub repo name** = `<env>-explorer` (one of `mainnet-explorer`, `preview-explorer`, `preprod-explorer`).
- **Local working dir** name SHOULD match the GitHub repo name. `preview-explorer-new` is grandfathered; rename to `preview-explorer` only when convenient (it requires updating the `midnight-preview-explorer.service` `WorkingDirectory=` line and a `systemctl daemon-reload`).
- **`package.json` `name` field** MUST match the GitHub repo name segment (`midnight-<env>-explorer`). This is the machine-checkable marker.
- **`src/config.ts` `network.name`** MUST be one of `'Midnight Mainnet' | 'Midnight Preview' | 'Midnight Preprod'`.
- **Service unit `Description=`** MUST include the env name + port.
- **API path prefix** = `/api/<env>/...` — never bare `/api/...` on the homepage; rely on `window.__NF_API` derived from `location.hostname`.

## NEVER point preview at the preprod repo (or vice versa)

The 2026-04-15 incident was an accidental `git push` from `/home/midnight/preview-explorer-new` whose `origin` was set to `git@github.com:cryptoleo79/preprod-explorer.git`. The push was a force because the histories diverged; it overwrote preprod's `main` with preview's history. The local preprod indexer (port 3004) was unaffected and kept running, but its WebSocket subscription stalled silently 5 days later (2026-04-20) — and because the remote was already wrong, nobody noticed for 31 days.

**Hard rule:** before any `git push` in an explorer dir, the operator (or a pre-push hook) must verify that `git remote get-url origin` ends in `<env>-explorer.git` where `<env>` matches `package.json:name` and `src/config.ts:network.name`. Anything else aborts.

## Recommended pre-push hook (defensive — not yet installed)

Add to each repo's `.git/hooks/pre-push` (or `.githooks/pre-push` if `core.hooksPath` is set):

```sh
#!/usr/bin/env bash
# Block pushes when local repo identity disagrees with the remote URL.
set -e
remote_url=$(git remote get-url "$1" 2>/dev/null || true)
expected_env=$(node -p "require('./package.json').name.replace('midnight-','').replace('-explorer','')" 2>/dev/null || true)
case "$remote_url" in
  *"${expected_env}-explorer.git") ;;  # OK
  *) echo "REFUSING push: remote $remote_url does not match package.json env '${expected_env}'"; exit 1 ;;
esac
```

This is a *recommendation*; install only with operator approval. The deploy-all.sh script and the env-aware homepage already make environment confusion *visible*; the hook makes a push-time *mistake* impossible.

## Cross-references

- WebSocket watchdog that detects future indexer stalls — commit `f1e3c4e` on `cryptoleo79/preprod-explorer:preprod-restore`
- NightForge per-env coherence helpers — `window.__NF_NET` / `__NF_API` / `__NF_RPC` defined in `website/nightforge-main.html` and used by every API fetch
- Deploy script — `scripts/deploy-all.sh` (this repo)
- Tester handoff — `docs/HANDOFF_PACKAGE.md`, `docs/EXTERNAL_VALIDATION.md`, `docs/TESTER_BRIEF.md`

## Known pending state at time of writing (2026-05-25)

- `cryptoleo79/preview-explorer` `main` is still the LICENSE-only auto-init commit; real preview history `88d9745` has not landed.
- `cryptoleo79/preprod-explorer` default branch is still `main` (preview code); should be switched to `preprod-restore` in GitHub Settings.
- `preview-explorer-new/package.json` rename to `midnight-preview-explorer` not yet done.
- `mainnet-explorer/package.json` description port fix (3001 → 3005) not yet done.
- Pre-push hook not yet installed in any repo.

All five items are forward-only fixes. None require a history rewrite.
