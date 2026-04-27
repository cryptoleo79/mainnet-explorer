# Contributing to NightForge

NightForge is a privacy-first block explorer for the Midnight Network. Every line of code, every commit message, and every PR description is held to the same standard: **truth, precision, auditability**.

If a Midnight or Cardano engineer reads any of our PRs, they must immediately understand:

- what the problem was
- what changed
- why it is safe
- how it was verified

## The Truth Rule

Every displayed metric must be one of:

1. live API value
2. derived from live API value
3. canonical on-chain / deployment fact
4. explicit unavailable / empty state

If a number does not fit one of those four categories, **remove it**.

No mock values. No fake live-looking placeholders. No stale numbers presented as current. No hardcoded fallbacks that flatter a degraded indicator (e.g. defaulting to `||10` or `||0.99` and rendering an A+ score on missing data).

## Commit & PR Style

See [`docs/COMMIT_AND_PR_STYLE.md`](docs/COMMIT_AND_PR_STYLE.md).

### Install the commit-msg hook (one-time, per clone)

```bash
git config core.hooksPath .githooks
```

That points git at `.githooks/commit-msg`, which validates every commit title against the policy (scope present, lowercase imperative, ≤72 chars, no banned words, no AI attribution). If a commit is rejected, the hook prints the offending title and the rule that failed.

Same check runs as CI on every PR via `.github/workflows/commit-style.yml`, so a missing local hook is caught before merge. Do not bypass the hook with `--no-verify` on `main`.

Quick form:

```
<scope>: <imperative action>
```

Allowed scopes: `api | web | tools | explorer | data | nginx | docs | build | perf | ui | truth`

Lowercase scope, imperative verb, max 72 characters, no vague words ("update", "stuff", "misc", "changes"), **no AI / Claude / co-author attribution**.

## Tone Rules

Write like an engineer.

**Do:**

- be precise
- use facts
- mention exact files, endpoints, commits, tx hashes, blocks
- state limitations clearly

**Do not:**

- hype
- exaggerate
- write marketing language
- imply official endorsement
- claim "first" unless proven
- claim ZK if it is signed disclosure
- claim mainnet when it is preview

## Branching & Merging

- `main` is the deployed branch.
- Forward-only commits. **No amend, no rebase, no force-push, no tag rewriting** on `main`.
- Feature work in topic branches; squash-merge only when the squashed commit message itself follows this standard.

## Pre-merge Checklist

- [ ] Truth rule applied (every visible number classified).
- [ ] Mainnet vs preview labels explicit; no mixing.
- [ ] No fake/mock/hardcoded live-looking values introduced.
- [ ] Empty states are honest (em-dash + `title="Awaiting indexer data"` or equivalent).
- [ ] Background animation stays behind content (`pointer-events: none` on decorative layers, `isolation: isolate` where needed).
- [ ] No SW/load-time work added that runs before first paint without `requestIdleCallback`.
- [ ] PR description follows the template in [`docs/COMMIT_AND_PR_STYLE.md`](docs/COMMIT_AND_PR_STYLE.md).

## Repository Layout (high level)

| Path | Purpose |
|---|---|
| `src/api/` | Express server, indexer GraphQL clients, REST endpoints |
| `src/indexer/` | Local indexer, SQLite persistence, GraphQL helpers |
| `tools/` | Static tools pages served by the Express server (DUST status, validators, etc.) |
| `website/nightforge-main.html` | The deployed homepage source |
| `data/` | SQLite databases (gitignored) |

## Deploying NightForge

NightForge is served from **four** doc roots, one per environment. They must stay in sync, or visitors land on stale builds depending on which subdomain they hit.

| Environment | Subdomain | Doc root | Owner |
|---|---|---|---|
| apex | `nightforge.jp` | `/var/www/explorer-main` | `root` (sudo) |
| mainnet | `mainnet.nightforge.jp` | `/var/www/explorer-mainnet` | `midnight` |
| preview | `preview.nightforge.jp` | `/var/www/explorer-lite` | `root` (sudo) |
| preprod | `preprod.nightforge.jp` | `/var/www/explorer-preprod` | `midnight` |

### One command to deploy everywhere

```bash
npm run deploy
```

This runs `bash scripts/deploy-all.sh`, which:

1. Renders an environment-specific `index.html` per target with `<title>`, `og:title`, and `og:url` substituted to advertise the right network.
2. Copies `website/nightforge-main.html` and `website/credential-gate.html` into each doc root.
3. Uses `sudo` only on root-owned roots (`explorer-main`, `explorer-lite`); never blanket-elevates.
4. Prints per-target ✓ / ✗ with deployed size and mtime.
5. Exits non-zero if any target fails. **Never silently skips.**

To preview the plan without writing:

```bash
npm run deploy -- --dry-run
```

### Do not manually copy files

**Never `cp` directly into `/var/www/explorer-*`.** That is how environments drift — apex ends up on yesterday's build, preview keeps an older title, preprod misses a fix. Any deploy that does not go through `scripts/deploy-all.sh` is presumed wrong, even if the diff looks the same: the script also rewrites the per-environment metadata (`<title>`, OG tags) that a raw `cp` would clobber.

If the script fails for a target, fix the target (missing dir, permissions, wrong nginx config) and re-run the script. Do not "just `sudo cp` it for now" — that is the problem this script exists to remove.

CI on `main` may eventually add a check that flags PRs whose merge timestamp does not have a matching `deploy-all.sh` invocation. Until then, this is a documented norm: read it as a hard rule.

### Tools pages

Tools pages under `/home/midnight/mainnet-explorer/tools/*.html` are served live by the Node API at port 3005 with `cache-control: no-store`. Edits there are visible immediately and do **not** go through `deploy-all.sh`.

## What This Project Is Not

- It is not the official Midnight Foundation explorer.
- It is not endorsed by the Midnight Foundation, IOHK, or any chain authority.
- It is not a wallet (use YAMORI for that).
- It does not store user keys or run a node.

If you need to characterise NightForge in copy or PR text, the accurate phrasing is "an independent, privacy-first block explorer for Midnight."
