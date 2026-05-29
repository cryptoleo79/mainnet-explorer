# Deploy Flow

How NightForge gets published to the four nginx docroots and the three indexer-served tool directories. One command, one source repo, four target environments.

For repo→environment mapping see `REPO_TOPOLOGY.md`. This file is operational: what to run, where it lands, how to verify.

## TL;DR

```bash
cd /home/midnight/mainnet-explorer
sudo bash scripts/deploy-all.sh
```

That publishes `website/nightforge-main.html`, `website/credential-gate.html`, and `website/yamori.html` to all four NightForge docroots with correct per-environment substitutions. It does **not** publish `/tools/` content — see [Tool pages](#tool-pages) below.

## What `deploy-all.sh` does

| Step | Action |
|---|---|
| 1 | Reads source from `website/nightforge-main.html` (homepage), `website/credential-gate.html`, `website/yamori.html` |
| 2 | For each of 4 targets: renders an env-specific copy by substituting `__NETWORK_LABEL__`, `__NETWORK_COLOR__`, `<title>`, `og:title`, `og:url` |
| 3 | Copies the rendered file to the docroot (with `sudo` only when needed) |
| 4 | Reports `ok=<n> fail=<n>` summary |

## Target mapping

| Target name | Docroot | Owner | Sudo? | UI host(s) | Env label | Color token |
|---|---|---|---|---|---|---|
| `apex` | `/var/www/explorer-main` | `root:root` | YES | `nightforge.jp` | `Mainnet` | `text-green-400` |
| `mainnet` | `/var/www/explorer-mainnet` | `midnight:midnight` | no | `mainnet.nightforge.jp` | `Mainnet` | `text-green-400` |
| `preview` | `/var/www/explorer-lite` | `root:root` | YES | `preview.nightforge.jp` | `Preview` | `text-cyan-400` |
| `preprod` | `/var/www/explorer-preprod` | `midnight:midnight` | no | `preprod.nightforge.jp` | `Preprod` | `text-orange-400` |

Running with `sudo bash` covers all four targets in one invocation. Running with `bash` (no sudo) succeeds for `mainnet` and `preprod`, fails for `apex` and `preview`.

## Indexer ports + API routing

Each environment's indexer listens on its own port; nginx routes `/api/<env>/*` to that port. The apex has one documented asymmetry — it serves bare `/api/*` direct from the mainnet indexer.

| UI host | Indexer service | Port | API path on this host |
|---|---|---|---|
| `nightforge.jp` (apex) | `midnight-mainnet-indexer.service` | `3005` | `/api/*` (bare, routes straight to `:3005`) |
| `mainnet.nightforge.jp` | `midnight-mainnet-indexer.service` | `3005` | `/api/mainnet/*` → `:3005/*` |
| `preview.nightforge.jp` | `midnight-preview-explorer.service` | `3000` | `/api/preview/*` → `:3000/*` |
| `preprod.nightforge.jp` | `midnight-preprod-indexer.service` | `3004` | `/api/preprod/*` → `:3004/*` |

The homepage derives `window.__NF_API` from `location.hostname` so the same HTML source is correct on all four hosts. **Never hardcode an env-specific API path in `nightforge-main.html`.** See `REPO_TOPOLOGY.md` rule 11.

## Tool pages

`/tools/<page>.html` (including `/tools/index.html`) is **not** managed by `deploy-all.sh`. Each environment's indexer Express server serves its own `tools/` directory:

| UI host | Source of `/tools/*` | How it gets there |
|---|---|---|
| `nightforge.jp` + `mainnet.nightforge.jp` | `/home/midnight/mainnet-explorer/tools/` (served by `:3005`) | Edited in this repo, picked up by the indexer process |
| `preview.nightforge.jp` | `/home/midnight/preview-explorer-new/tools/` (served by `:3000`) | Edited in that repo |
| `preprod.nightforge.jp` | `/home/midnight/preprod-explorer/tools/` (served by `:3004`) | Edited in that repo |

This is why `/tools/index.html` can drift between hosts (e.g. mainnet shows 20 cards, preview/preprod show 17). Reconciliation is a manual copy from `mainnet-explorer/tools/` into the other two repos, followed by a normal commit in each repo. There is no symlink, no shared dir, and no sync hook today. Treat each repo's `tools/` as its own surface.

### When you need cross-env `/tools/` parity

1. Edit `tools/<file>.html` in `mainnet-explorer`.
2. Copy the same file into `preview-explorer-new/tools/` and `preprod-explorer/tools/`.
3. Commit each repo separately (forward-only, scope `tools:`).
4. The indexer processes pick up the static file on next request — no service restart needed for `.html` changes.

A future enhancement (not built) would extend `deploy-all.sh` to also sync `tools/` between the three repos. Not in scope for the current observation-mode milestone.

## Required environment

- Source repo at `/home/midnight/mainnet-explorer`, working tree clean
- Source file `website/nightforge-main.html` present and contains the `__NETWORK_LABEL__` and `__NETWORK_COLOR__` placeholders unsubstituted (this is the fail-loud safety; a file missing the placeholders will publish a wrong label silently)
- All four docroots present (`/var/www/explorer-{main,mainnet,lite,preprod}`)
- `sudo` available

## Exact deploy command

From a clean working tree on `main`:

```bash
cd /home/midnight/mainnet-explorer
sudo bash scripts/deploy-all.sh
```

To preview without writing anything:

```bash
cd /home/midnight/mainnet-explorer
sudo bash scripts/deploy-all.sh --dry-run
```

The script exits non-zero if any target fails. It never silently skips a target.

## Post-deploy verification checklist

Run after every deploy. Five seconds, four checks per host.

```bash
for host in nightforge.jp mainnet.nightforge.jp preview.nightforge.jp preprod.nightforge.jp; do
  echo "--- $host ---"
  # 1. UI responds
  printf "  ui:    "; curl -fsS -o /dev/null -w 'HTTP %{http_code}  size=%{size_download}\n' "https://$host/" --max-time 5

  # 2. Env label is correct (not the literal placeholder)
  label=$(curl -fsS "https://$host/" --max-time 5 | grep -oE 'NightForge Explorer - [A-Za-z_]+' | head -1)
  echo "  label: $label"

  # 3. API returns the right network for this host
  case "$host" in
    nightforge.jp)               p=/api/stats ;;
    mainnet.nightforge.jp)       p=/api/mainnet/stats ;;
    preview.nightforge.jp)       p=/api/preview/stats ;;
    preprod.nightforge.jp)       p=/api/preprod/stats ;;
  esac
  net=$(curl -fsS "https://$host$p" --max-time 5 | python3 -c "import sys,json; print(json.load(sys.stdin).get('network','?'))")
  echo "  net:   $net"

  # 4. No literal placeholder leaked through
  ph=$(curl -fsS "https://$host/" --max-time 5 | grep -c '__NETWORK_LABEL__')
  echo "  placeholder leak: $ph (must be 0)"
done
```

Expected output:

| host | label | net |
|---|---|---|
| `nightforge.jp` | `NightForge Explorer - Mainnet` | `Midnight Mainnet` |
| `mainnet.nightforge.jp` | `NightForge Explorer - Mainnet` | `Midnight Mainnet` |
| `preview.nightforge.jp` | `NightForge Explorer - Preview` | `Midnight Preview` |
| `preprod.nightforge.jp` | `NightForge Explorer - Preprod` | `Midnight Preprod` |

Every `placeholder leak` line must read `0`. Any non-zero value means a docroot was published outside of `deploy-all.sh`.

## Rollback procedure

Rolling back the NightForge UI is the same shape as rolling forward: identify the last-known-good commit, check it out in the source repo, run `deploy-all.sh`, verify.

There is no automatic snapshot of `/var/www/explorer-*/index.html`. The source of truth is the git history of `website/nightforge-main.html` in this repo. Rollback works by re-deploying an older version of that file.

### Standard rollback (last-known-good commit on `main`)

1. Identify the commit to roll back to.
   ```bash
   cd /home/midnight/mainnet-explorer
   git log --oneline -10 -- website/nightforge-main.html
   ```
   Pick the SHA of the commit whose state you want live. Call it `<GOOD>`.

2. Confirm the rollback will not lose newer uncommitted work.
   ```bash
   git status
   git diff HEAD -- website/nightforge-main.html
   ```
   If there is uncommitted local work in `website/nightforge-main.html`, stash it first: `git stash push -- website/nightforge-main.html`.

3. Forward-only rollback (the right one — does not rewrite history):
   ```bash
   git checkout <GOOD> -- website/nightforge-main.html
   git commit -m "deploy: roll back nightforge-main.html to <GOOD>"
   sudo bash scripts/deploy-all.sh
   ```
   This produces a *new* commit on `main` that restores the old contents. History stays forward-only.

4. Verify with the post-deploy checklist above. All four hosts should serve the rolled-back HTML, correct env labels, no placeholder leak.

### Emergency rollback (out-of-band, no commit)

If something is actively broken and you need to revert before you can commit:

1. Save the broken file aside: `cp website/nightforge-main.html /tmp/nightforge-main.broken.$(date +%s).html`
2. Check out the previous version into the working tree: `git checkout HEAD~1 -- website/nightforge-main.html`
3. `sudo bash scripts/deploy-all.sh`
4. Verify with the checklist.
5. Then commit the rollback as in step 3 of the standard procedure above. **Do not push or deploy again until the working-tree state matches a real commit on `main`.**

### What rollback does NOT cover

- **Indexer / API behavior** — rollback only re-publishes the static HTML. If the bug is in `/api/*`, you need to revert the indexer source and `sudo systemctl restart midnight-<env>-{indexer,explorer}`.
- **Tool pages** — `/tools/*.html` are served per-env by each indexer; see [Tool pages](#tool-pages). To roll back a tools page, revert the file in the appropriate repo (`mainnet-explorer`, `preview-explorer-new`, or `preprod-explorer`) and restart is not required for static files.
- **nginx config** — `deploy-all.sh` does not touch nginx. nginx rollback is a separate procedure (sudo edit `/etc/nginx/sites-available/`, `nginx -t`, `systemctl reload nginx`).
- **The CredentialGate contract** — on-chain, immutable, never rolled back.

### When NOT to roll back

- **A truth-rule violation that is already deployed.** Forward-fix it with a new commit and re-deploy. Rolling back loses the audit record of what was wrong.
- **A typo or copy mistake.** A forward fix is two minutes and keeps history honest.
- **You're not sure what broke.** Diagnose first. A blind rollback can mask the actual fault and rolling forward later may re-introduce it.

## What is NOT a deploy

These are common confusions. None of them are a "deploy":

- **`scp` to `/var/www/`** — bypasses the per-env substitution and the safety placeholders. Never do this.
- **`git push`** — moves source code, does not change what is served. The push must be followed by `sudo bash scripts/deploy-all.sh` for users to see the change.
- **Indexer restart** — affects `/api/*`, not `/`. Restart the indexer only when an indexer code change requires it (`sudo systemctl restart midnight-mainnet-indexer` etc).
- **Editing `tools/<file>.html` in `mainnet-explorer`** — only takes effect on `nightforge.jp` and `mainnet.nightforge.jp`. Preview and preprod serve from different repos. See [Tool pages](#tool-pages).

## Troubleshooting

### `ok=3 fail=1` — one docroot failed

Look at the failing target's line in the output:

- `doc root does not exist: /var/www/explorer-<X>` — confirm the host's nginx config and create the docroot.
- `index.html failed` — likely sudo prompt timed out or wrong password. Re-run interactively.

### Live label is `__NETWORK_LABEL__`

Someone published `nightforge-main.html` straight from the repo without going through `deploy-all.sh`. Re-run `sudo bash scripts/deploy-all.sh` to fix.

### Live label is wrong (e.g. preview host shows "Mainnet")

Either the substitution ran with the wrong arg, or someone hand-edited the docroot. Re-run `deploy-all.sh`.

### `/tools/<page>` is stale on preview or preprod after mainnet update

Tools are not synced by `deploy-all.sh`. See [Tool pages](#tool-pages).

### `/api/*` returns wrong network

Indexer service running against the wrong network. Check `systemctl status midnight-<env>-indexer` and the service's `WorkingDirectory=`.

## Indexer service map

| Service | Port | Working directory | Network |
|---|---|---|---|
| `midnight-mainnet-indexer.service` | `3005` | `/home/midnight/mainnet-explorer` | Mainnet |
| `midnight-preview-explorer.service` | `3000` | `/home/midnight/preview-explorer-new` | Preview |
| `midnight-preprod-indexer.service` | `3004` | `/home/midnight/preprod-explorer` | Preprod |
| `main-indexer.service` | `3003` | `/home/midnight/services/midnight-preview-indexer` (runtime only, not a git repo) | Pre-existing infra; out of scope for explorer deploys |

Restart pattern: `sudo systemctl restart midnight-<env>-{indexer,explorer}`. Logs: `sudo journalctl -u midnight-<env>-{indexer,explorer} -f`.

## What this doc deliberately does not cover

- YAMORI build/release — separate repo, separate process, see `/home/midnight/YAMORI/docs/` and `SESSION_STATE.md`.
- CredentialGate contract deploy — frozen at the active preview address, see `OBSERVATION_MODE.md`.
- nginx config changes — handled outside this script; require sudo edits in `/etc/nginx/sites-available/` plus `nginx -t && systemctl reload nginx`.
- TLS certificate renewal — handled by certbot, separate cron.

## Cross-references

- `REPO_TOPOLOGY.md` — repo / env / branch / domain mapping and rules.
- `SESSION_STATE.md` — what is currently deployed, deferred items.
- `COMMIT_AND_PR_STYLE.md` — commit / PR standard for any change that flows into a deploy.
- `OBSERVATION_MODE.md` — what is frozen at the current milestone.
- `scripts/deploy-all.sh` — the script itself; authoritative source of behavior.
