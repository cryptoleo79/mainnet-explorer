# Friction Log Template

Fill one of these in after running `docs/EXTERNAL_VALIDATION.md`. Don't
self-edit your raw notes — we want the unfiltered version. Copy this
file to a new name (e.g. `friction-2026-05-20-<your-handle>.md`) and
submit via PR or paste-in.

Plain answers only. Lists are fine. We will not be offended.

---

## Tester

- **Type**: developer / wallet tester / both
- **Handle or name**: 
- **Date / time started (UTC or local)**: 
- **Time spent end-to-end**: 

## Environment

- **OS**: 
- **Browser** (wallet path only): 
- **Node version** (developer path only): `node -v` →
- **Docker version** (developer path only): `docker -v` →
- **YAMORI extension version loaded**: 
- **NightForge host opened**: nightforge.jp / mainnet / preview / preprod
- **Network used** (developer path): preview
- **Were the prerequisites already satisfied?** (wallet funded? DUST present? mnemonic ready?)

## What worked

(things that did exactly what you expected, even small ones)

1. 
2. 
3. 

## What confused you

(things that worked but you weren't sure what was happening)

1. 
2. 
3. 

## What broke

(things that did not work, errors, hangs)

For each item, include:

- The step number from `EXTERNAL_VALIDATION.md`
- The exact error message or behavior
- What you tried before giving up
- Whether it was blocking (couldn't proceed) or non-blocking

Example:
> Step 5 of developer path. `npm run demo:clean` hung at PROVE for
> ~5 minutes then printed `InsufficientFunds`. I had not funded the
> wallet — the doc mentions DUST but I missed it on first read.
> Blocking until faucet step done.

1. 
2. 
3. 

## Screenshots / logs

(paste console errors, network errors, terminal output)

```
<paste here>
```

## Trust concern

Anything you saw that made you feel the system was lying to you, or
that a number was decorative rather than real, or that an action
silently did less than the UI suggested.

(empty if none)

1. 
2. 

## Smallest fix you'd propose

For each thing you flagged, if a one-sentence change would have made
it click, write that here. Don't redesign — just say what would have
unblocked **you** in **30 seconds**.

1. 
2. 

## Free-form note

(anything else — taste, vibe, doubts, what you'd want to do next)

---

## Operator-only fields (we fill these after triage; tester leaves blank)

- Logged as issue / PR / no-action / docs fix:
- Affected surface: NightForge / YAMORI / CredentialGate / docs / upstream
- Priority: 
- Resolved in commit:
