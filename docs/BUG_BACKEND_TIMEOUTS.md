# BUG — backend endpoints timing out

Captured 2026-05-25 during the capability-parity audit. Re-triaged 2026-06-01.
**Not fixed in this commit.** Logged here so the next backend pass has the list.

## 2026-06-01 re-triage — root causes now distinguished

A direct probe against the mainnet indexer at `127.0.0.1:3005` (bypassing
nginx) reveals that the four endpoints have **different** failure modes
than originally captured. The public URL still times out in each case,
but the cause is not always "backend hang."

| endpoint | public URL response | indexer direct response | classified cause |
|---|---|---|---|
| `analytics/bridge` | HTTP 000, timeout at 4 s | HTTP 200 in ~2.7 s | nginx `proxy_read_timeout` < indexer response time |
| `live/dust-rate` | HTTP 000, timeout at 4 s | HTTP 000, timeout at 4 s | **real upstream hang — indexer-side** |
| `live/shielded-rate` | HTTP 000, timeout at 4 s | HTTP 200 in ~2.7 s | nginx `proxy_read_timeout` < indexer response time |
| `epoch/current` | HTTP 000, timeout at 4 s | HTTP 200 in ~540 ms | nginx routing artefact — `/api/mainnet/epoch/current` strips to `:3005/epoch/current` (missing `/api` prefix) and the route 404s without responding cleanly |

So the original "all four are upstream hangs" framing was wrong. Only
`live/dust-rate` is a genuine indexer-side hang. The other three are
nginx-configuration issues: two need a `proxy_read_timeout` bump to
match real indexer response time (~3 s headroom); one needs the env-
prefix nginx rewrite rule corrected on apex so the upstream path
preserves `/api/`.

## Affected endpoints (original 2026-05-25 capture, kept for record)

| endpoint | mainnet | preview | preprod |
|---|---|---|---|
| `analytics/bridge` | **timeout** | **timeout** | **timeout** |
| `live/dust-rate` | **timeout** | 404 (not implemented) | 404 (not implemented) |
| `live/shielded-rate` | **timeout** | 404 (not implemented) | 404 (not implemented) |
| `epoch/current` | **timeout** | 404 (not implemented) | 404 (not implemented) |

Comparison endpoints that respond normally on mainnet within a few
hundred ms: `governance`, `validators`, `committee`, `analytics/overview`,
`analytics/privacy`, `analytics/dust`, `cardano-anchors`,
`validators/liveness`, `contracts/heatmap`. So the timeouts are
per-endpoint, not a host-wide slowdown.

## Source locations

All four routes live in `src/api/server.ts`:

- `analytics/bridge` — line 865 (`/api/analytics/bridge`)
- `live/dust-rate` — line 2957 (`/api/live/dust-rate`)
- `live/shielded-rate` — line 2998 (`/api/live/shielded-rate`)
- `epoch/current` — line 2825 (`/api/epoch/current`)

## Likely causes (not verified — bug note only)

- `analytics/bridge` and the two `live/*-rate` handlers do
  windowed event scans against the indexer SQLite store. Most likely
  cause: an unindexed column on the event-scan path, or a query that
  full-scans events with no `LIMIT` short-circuit on the hot window.
- `epoch/current` on mainnet probably joins against
  `sidechain_getStatus` RPC; an RPC stall there would hang the
  handler. Preview/preprod return 404 (route never registered on those
  backends), which is a separate consistency gap.

## UI consequences (already known)

- NightForge homepage widgets that consume these silently render empty
  states. The truth-rule fallback (`||0` / `||"—"`) means no fake
  numbers are shown — but no signal is shown either.
- Decentralization Dial (`renderDecentralizationDial`) calls
  `epoch/current` as one of its four inputs; on mainnet the dial
  partially renders, on preview/preprod the dial renders without
  epoch-derived numbers.

## What this commit does NOT do

- No backend code touched.
- No timeout flag, retry, or caching added.
- No frontend masking of the timeouts.
- No deploy-script change.

## Suggested next step (separate commit, separate scope)

Per the 2026-06-01 re-triage above, the four endpoints split into three
distinct fixes — sequence accordingly:

1. **nginx `proxy_read_timeout` bump** for `/api/mainnet/analytics/bridge`
   and `/api/mainnet/live/shielded-rate`. Indexer responds at ~2.7 s; raise
   the nginx timeout to 8 s on those two locations only (do not bump
   site-wide). Single-line nginx config change per host + `nginx -t` +
   `systemctl reload nginx`. No backend touch.
2. **nginx rewrite rule** for `/api/mainnet/epoch/current` on apex. The
   current `proxy_pass http://127.0.0.1:3005/` strips `/api/mainnet/`
   without preserving the `/api/` segment that the indexer routes need.
   Either change the proxy_pass target to `:3005/api/` or add a `rewrite`
   directive that injects `/api/` back. Same nginx-only change pattern.
3. **`live/dust-rate` upstream hang** — the genuine indexer-side issue.
   Reproduce locally against the SQLite store with `EXPLAIN QUERY PLAN`
   on the event-scan path; add a `LIMIT`-bounded window or an index on
   the scanned column, whichever is the actual culprit. Backend code
   change. Out of scope for an nginx-only pass.
4. For `epoch/current` on preview + preprod (currently 404): register
   the route on those backends if it's meant to be a cross-env capability;
   otherwise mark it mainnet-only in the UI and stop calling it from the
   non-mainnet widgets.
5. Re-probe with `curl --max-time 4` from a non-local client and confirm
   sub-second responses after each change.

Owner: not assigned. Operator to triage.
