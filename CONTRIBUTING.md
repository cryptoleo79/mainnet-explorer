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

## Deployment

`mainnet.nightforge.jp` and `nightforge.jp` serve from `/var/www/explorer-mainnet` and `/var/www/explorer-main` respectively. The latter is root-owned and requires `sudo cp` to update.

Tools pages are served live by the Node server at port 3005 with `cache-control: no-store`, so changes to `/home/midnight/mainnet-explorer/tools/*.html` are visible immediately.

## What This Project Is Not

- It is not the official Midnight Foundation explorer.
- It is not endorsed by the Midnight Foundation, IOHK, or any chain authority.
- It is not a wallet (use YAMORI for that).
- It does not store user keys or run a node.

If you need to characterise NightForge in copy or PR text, the accurate phrasing is "an independent, privacy-first block explorer for Midnight."
