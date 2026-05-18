# Handoff Package

Exact list of what we send to each tester, and what we deliberately do not.

## Developer tester package

Send:

- **Repo URL.** `git@github.com:cryptoleo79/YAMORI.git`. Repo is
  currently invite-only; grant read access on GitHub before they start.
  If anonymous HTTPS clone is requested, expect a 404.
- **`docs/TESTER_BRIEF.md`** (one-page summary).
- **`docs/EXTERNAL_VALIDATION.md`** (full Path 1 with prerequisites).
- **`docs/FRICTION_LOG_TEMPLATE.md`** (what they return).
- **Active CredentialGate contract:**
  `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`
  on Midnight preview, deploy tx
  `cf00cff58be5300a0d6ea6e42b46a98528de28e3d976e5141bde82f4a21d2c4e`,
  block 454,958 (2026-04-25).
- **NightForge preview link:**
  `https://preview.nightforge.jp/tools/contracts.html?address=7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`
- **Demo command:** `npm run demo:clean` (from
  `YAMORI/contracts/credential-gate/deploy/`).

Out-of-band but they will need it:

- A **preview-funded deploy mnemonic** (or instructions to mint one
  with `npm run gen` and fund it from
  `https://midnight.network/test-tdust`).
- The proof-server Docker tag they should pull
  (`midnightntwrk/proof-server:8.1.0-rc.1`).

## Wallet tester package

Send:

- **`yamori-v1.5.0.zip`** from `/home/midnight/YAMORI/yamori-v1.5.0.zip`
  (6,502,023 bytes, manifest 1.5.0, built 2026-05-14T23:34:41Z).
- **`docs/TESTER_BRIEF.md`** (one-page summary).
- **`docs/EXTERNAL_VALIDATION.md`** (full Path 2).
- **`docs/FRICTION_LOG_TEMPLATE.md`** (what they return).
- **A signed sample credential JSON** if available. If the operator
  has run the issuer CLI once, ship one freshly-issued credential
  file (e.g. `cred-<uuid>.json`) so the wallet tester does not need
  to install Node + the issuer toolchain. If no sample is available,
  point them at Path 1's `npm run issue` step.
- **NightForge link to the live contract** (same URL as the developer
  tester gets).
- **YAMORI page link:** `https://nightforge.jp/yamori.html`.

## What we do NOT send

- The operator's actual mnemonic, password, or vault data. Both
  paths use fresh test wallets.
- Issuer private keys (`contracts/credential-gate/issuer/keys/`).
  These are git-ignored and stay on the operator's machine.
- Internal session memory or audit notes
  (`~/.claude/projects/-home-midnight/memory/`).
- Any future-roadmap document. Testers are looking at what is, not
  what might be.

## What we do NOT explain live

- The "expected output" is in `docs/EXTERNAL_VALIDATION.md`. If they
  hit something not in that doc, that is the data we want.
- We do not screen-share, voice-call, or guide them step by step.
- We do not pre-warn them about known limitations. Those are listed
  in `docs/OBSERVATION_MODE.md` for the operator's reference, not
  the tester's. (If a tester rediscovers a documented limitation, the
  doc still serves its purpose.)
- We do not fix friction during their run. We log it, then decide.

## How to return feedback

Testers send back a single file: their copy of
`docs/FRICTION_LOG_TEMPLATE.md`, renamed e.g.
`friction-2026-05-DD-<their-handle>.md`. Plus any screenshots,
terminal output, or `chrome://extensions` error console snippets.

Channel: whatever the operator already uses with each tester (PR,
email, Slack, signal). The doc itself is plain markdown — paste-in
works.

## Sequencing

1. Operator picks two people, ideally with no prior context on the project.
2. Operator grants repo read access to the developer tester.
3. Operator sends the developer-tester package and the wallet-tester
   package to their respective people in one message each.
4. Operator does not respond to mid-test pings except to grant
   access. Silence is intentional.
5. After both reports arrive, operator triages with the engineering
   team. No fixes ship during the test window.

End of package list.
