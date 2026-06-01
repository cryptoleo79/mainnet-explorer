# Next Real Bugs — operator triage list

Ranked by impact. Dated **2026-06-01**, grounded in the deep-audit pass that landed `be33051 / 91f560f / 9787f3b` and the `2026-06-01` delta sweep in `ECOSYSTEM_WAKEUP_PLAN.md`.

This is a triage document. **No fix has been written.** Each entry is the smallest honest description of the bug; implementation requires explicit per-item approval. No feature work, no governance-memory implementation, no SDK work, no deploy proposed here.

---

## Priority 1 — `/api/credential-gate/liveness` returns SPA HTML on apex

### Issue
Public probe of `https://nightforge.jp/api/credential-gate/liveness` returns the homepage HTML (the full NightForge SPA, ~321 KB) instead of the JSON the endpoint is designed to emit. The endpoint is registered in `src/api/server.ts` (one of 71 routes inventoried in the audit). The on-homepage CredentialGate hero card (top of `nightforge.jp`) consumes this same endpoint client-side via `loadCredentialGateLiveness()`.

### Root cause (hypothesised, not verified)
Nginx routing precedence on apex. The site has a catch-all SPA route that hands every unmatched path to `index.html`. If the `location` block that proxies `/api/*` to the mainnet indexer (`:3005`) does not have a higher precedence than the SPA catch-all, the catch-all wins and serves the homepage instead of forwarding to the backend.

The other `/api/<env>/*` paths (mainnet / preview / preprod) are likely matched by explicit env-prefixed `location` blocks and so don't hit the catch-all. `/api/credential-gate/liveness` on apex has no env prefix, so it falls through.

Direct probe against the mainnet indexer at `127.0.0.1:3005/api/credential-gate/liveness` is the verification step required to confirm: if the indexer responds JSON, the bug is purely nginx; if the indexer also returns HTML, the bug is in the backend route registration.

### User impact
The CredentialGate hero card is the headline differentiator of NightForge per the 2026-05-30 ecosystem scan (no other Midnight explorer surfaces a live on-chain credential gate). If the card's data source is silently serving HTML to its JSON parser, the card is rendering empty / fallback / stale data on apex while looking correct, which is exactly the "static live theater" the truth rules forbid. Cross-host: the same bug pattern may or may not affect `mainnet.nightforge.jp` — needs probe.

### Fix scope
- nginx config change in `/etc/nginx/sites-available/nightforge.jp` (and possibly `mainnet.nightforge.jp`): explicit `location /api/credential-gate/` block that `proxy_pass http://127.0.0.1:3005/api/credential-gate/;` with the same headers as the other api locations
- `nginx -t && systemctl reload nginx`
- Re-probe + verify JSON response on both hosts
- Re-probe the hero card client-side (browser dev tools) to confirm it's now receiving real liveness data

Zero code change. Zero deploy script change. Zero `deploy-all.sh` run needed.

### Risk
Low. Single nginx location block addition. `nginx -t` catches syntax errors before reload. Reload is graceful (existing connections drained, new ones use the new config). Worst case: rollback by reverting the config and reloading — same procedure as the `DEPLOY_FLOW.md` rollback shape, but on nginx.

### Recommendation
**DO NOW once you authorize touching nginx config.** This is the highest-impact bug in the audit because (a) it silently degrades the headline differentiator, (b) the fix is one config block, (c) there is no code path that has to change. If you don't want nginx touched in the same pass as docs, hold and revisit; either way this should be the first bug fix after the next deploy-touching pass.

---

## Priority 2 — Backend timeout cluster

The original 2026-05-25 capture said "all four endpoints are upstream hangs." The 2026-06-01 indexer-direct re-triage (`9787f3b`) split them into three distinct fixes. This priority entry is the umbrella for all three; each can be done independently.

### 2.A — nginx `proxy_read_timeout` too short

**Affected endpoints**
- `https://nightforge.jp/api/mainnet/analytics/bridge` — indexer responds in ~2.7 s, public times out at 4 s
- `https://nightforge.jp/api/mainnet/live/shielded-rate` — indexer responds in ~2.7 s, public times out at 4 s

**Root cause**
Nginx `proxy_read_timeout` on those two `location` blocks is shorter than the indexer's real response time for the windowed event-scan queries those handlers run.

**User impact**
Homepage widgets that consume these silently render empty states. The Decentralization Dial widget partially renders (it has 4 inputs; this affects some of them). The Privacy / Bridge analytics surfaces are missing real data they could be showing.

**Fix scope**
Two nginx config lines — one per affected `location` block — setting `proxy_read_timeout 8s;` (3 s indexer response + 5 s headroom; do not bump site-wide). `nginx -t && systemctl reload nginx`.

**Risk**
Lowest of the three. The endpoints already respond; the timeout just needs to allow time for the response. No backend change.

**Recommendation**
**DO NOW once nginx authorized.** Bundle with Priority 1 fix into a single nginx-only commit + reload.

### 2.B — nginx `proxy_pass` strips `/api/` prefix

**Affected endpoint**
- `https://nightforge.jp/api/mainnet/epoch/current` — indexer responds in ~540 ms at `:3005/api/epoch/current`, but public times out

**Root cause**
The apex nginx `location /api/mainnet/` has `proxy_pass http://127.0.0.1:3005/;` (trailing slash). nginx strips the `/api/mainnet/` prefix and sends the upstream path as `/epoch/current` — but the indexer only registers `/api/epoch/current`. The upstream request 404s without responding cleanly, and the public side hangs.

**User impact**
Same as 2.A — widgets that call `epoch/current` see no data. This is the same symptom but a different root cause; lumping them together is what caused the 2026-05-25 capture to misdiagnose all four as upstream hangs.

**Fix scope**
Either change the `proxy_pass` target from `http://127.0.0.1:3005/` to `http://127.0.0.1:3005/api/`, or add a `rewrite ^/api/mainnet/(.*)$ /api/$1 break;` directive before the `proxy_pass`. Single-line config change.

**Risk**
Slightly higher than 2.A because this change affects every endpoint under `/api/mainnet/`, not just `epoch/current`. Must verify that the *other* `/api/mainnet/*` endpoints still respond after the rewrite — they might have been working *because* of the prefix strip, in which case the rewrite breaks them.

**Recommendation**
**PLAN — investigate first.** Before changing the rewrite rule, probe every `/api/mainnet/*` endpoint that NightForge depends on and confirm which ones currently work via the prefix-strip path. If many depend on the strip, the surgical fix is a per-endpoint `location` block for `/api/mainnet/epoch/current` that preserves `/api/` rather than a site-wide rewrite.

### 2.C — `live/dust-rate` real upstream hang

**Affected endpoint**
- `http://127.0.0.1:3005/api/live/dust-rate` — indexer-direct probe also times out at 4 s

**Root cause**
Genuine backend hang. Most likely: an unindexed event-scan path in the SQLite store, or a query that full-scans events without a `LIMIT` short-circuit on the hot window. Handler is at `src/api/server.ts` line 2957.

**User impact**
The Live Feed widget's DUST-rate component silently renders empty on mainnet. Comparison endpoints (`analytics/dust`) work fine, so the user sees a partial Live Feed — some live tiles, some empty.

**Fix scope**
Backend code change. Reproduce against the local SQLite store with `EXPLAIN QUERY PLAN`. Add a `LIMIT`-bounded window on the event-scan path or an index on the scanned column, whichever the explain output actually shows is the culprit.

**Risk**
Medium. Backend code change in a hot path. Touching the SQLite query plan can have downstream effects on other handlers that share the same table scan logic. Needs a test against the existing comparison endpoints to confirm they don't regress.

**Recommendation**
**WAIT** — gated on Priority 1 and Priority 2.A being done first. Those are nginx-only and ship safely; this one needs a backend-code commit and indexer service restart. Sequence properly to keep the blast radius small.

---

## Priority 3 — Memory correction propagation

### Issue
Older auto-memory files (`session_2026_05_12_recon.md` lines 74 + 145, `session_2026_05_20.md` line 95) label `midntwrk/midnight-node#1397` as the "Mainnet DUST HRP mismatch." That is wrong. `#1397` is `cnight_generates_dust (aka mapping validator) has the same address across all deployments`. The HRP issue is `forum.midnight.network/t/.../1209`.

### Root cause
Mislabel introduced ~2026-05-08 from a forum thread misidentification, propagated forward through subsequent session memory entries without verification, surfaced by the 2026-05-30 agent sweep, corrected in the project docs (`ECOSYSTEM_WAKEUP_PLAN.md` and the new auto-memory file `feedback_node_issues_correction.md`) but the **historical session memory files were intentionally left unedited** to preserve their point-in-time character.

### User impact
Operational, not user-facing. If a future session reads the older session memory without also reading `feedback_node_issues_correction.md`, it will cite `#1397` as the HRP issue in commit bodies, plans, or external communications. Low-frequency embarrassment risk, high-cost if it lands in something audit-grade.

### Fix scope
Three options, each leaves the historical memory files unedited (point-in-time principle):

1. **Status quo** — rely on the correction memory `feedback_node_issues_correction.md` and `MEMORY.md` index entry to be loaded alongside any older session memory. No further action. This is what is in place now.
2. **In-file correction note** — append a one-line "Correction note 2026-06-01: see `feedback_node_issues_correction.md` for the corrected `#1397` label" to the top of each affected historical file. Adds a clear breadcrumb for anyone reading the file directly. Does not edit the body. Adds 3 lines across 2 files.
3. **Future-session auto-load enforcement** — add the correction file to the persistent-context preamble so it's always loaded before any historical session memory. This requires a settings change on the harness; out of scope for a pure auto-memory pass.

### Risk
Lowest of any item in this doc. Memory writes only, no project code change.

### Recommendation
**PLAN — option 2.** The status-quo (option 1) is currently working but fragile; option 2 is two file edits with three lines of text added, no body edit, no history-rewrite concern. Hold until the operator confirms the breadcrumb-style correction approach is acceptable.

---

## Ranked summary

| # | priority | bug | fix surface | risk | recommendation |
|---|---|---|---|---|---|
| 1 | P1 | `/api/credential-gate/liveness` returns SPA HTML on apex | nginx config | low | DO NOW once nginx authorized |
| 2 | P2.A | `analytics/bridge` + `live/shielded-rate` nginx timeout | nginx config | lowest | DO NOW (bundle with P1) |
| 3 | P2.B | `epoch/current` nginx prefix-strip | nginx config | low-medium (verify regressions) | PLAN (probe before changing) |
| 4 | P2.C | `live/dust-rate` real indexer hang | backend code + indexer restart | medium | WAIT (do after P1/P2.A) |
| 5 | P3 | `#1397` mislabel propagation | auto-memory only | lowest | PLAN — option 2 (breadcrumb) |

## What this triage doc deliberately does NOT do

- Does not implement any fix
- Does not propose a deploy
- Does not propose any feature work
- Does not propose any SDK / wallet / contract / governance-memory implementation
- Does not edit nginx config
- Does not touch the live system in any way

Per-item implementation requires explicit operator approval. The recommended sequence — if you approve everything in this list eventually — is **P1 + P2.A as one nginx-only commit and reload**, then **P2.B in a separate nginx-only commit after probe verification**, then **P3 as a memory-only pass**, then **P2.C as a backend code commit with its own indexer restart**. Each step is independently reversible.

## Cross-references

- `docs/BUG_BACKEND_TIMEOUTS.md` — full re-triage of the timeout cluster (`9787f3b`)
- `docs/SESSION_STATE.md` — both bugs logged inline as latest known issues (`91f560f`)
- `docs/ECOSYSTEM_WAKEUP_PLAN.md` § 2026-06-01 delta — upstream state context (`be33051`)
- `~/.claude/projects/-home-midnight/memory/feedback_node_issues_correction.md` — authoritative `#1206 / #1374 / #1397 / forum #1209` labels (out-of-repo, auto-memory)
- `src/api/server.ts` — endpoint registrations (71 routes, line numbers for the 4 timeout endpoints captured in BUG_BACKEND_TIMEOUTS.md)
- `/etc/nginx/sites-available/{nightforge,mainnet.nightforge,preview.nightforge,preprod.nightforge}.jp` — nginx configs (read-only context; not edited by this doc)
