# BUG — backend endpoints timing out

Captured 2026-05-25 during the capability-parity audit. **Not fixed in this commit.**
Logged here so the next backend pass has the list.

## Affected endpoints

Probed live with `curl --max-time 4` from this host. "timeout" = no
HTTP status, connection hung past 4 s. Probed via `/api/<env>/...` on
each env's own UI host (apex routes /api/mainnet/, etc.).

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

1. Reproduce locally against the SQLite store with `EXPLAIN QUERY PLAN`.
2. Add a `LIMIT`-bounded window on the event-scan path or an index on
   the scanned column, whichever is the actual culprit.
3. For `epoch/current`: register the route on preview + preprod
   backends if it's meant to be a cross-env capability; otherwise mark
   it mainnet-only in the UI and stop calling it from the
   non-mainnet widgets.
4. Re-probe with `curl --max-time 4` and confirm sub-second response.

Owner: not assigned. Operator to triage.
