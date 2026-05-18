# External Validation Brief

Short instructions for the developer tester and the wallet tester.
Print this page if it helps. Anything longer is in `docs/EXTERNAL_VALIDATION.md`.

## 1. What you are testing

- **NightForge** — the block explorer at `nightforge.jp` and its three
  subdomain mirrors (`mainnet`, `preview`, `preprod`).
- **YAMORI** — the Chrome MV3 wallet extension, build `v1.5.0`.
- **CredentialGate** — a credential-gated swap contract deployed on
  Midnight preview. Address
  `7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`.

## 2. What we want from you

Plain notes only. Don't be nice. Record:

- confusion — anywhere the next step wasn't obvious.
- broken links — a click that 404'd, redirected oddly, or did nothing visible.
- unclear wording — a label, copy line, or status string that didn't match what you observed.
- trust concerns — anywhere a number or claim looked decorative rather than real.
- hesitation — anywhere you stopped to ask "is this safe?" or "is this real?"

Praise is not useful here. Friction is.

## 3. Developer path (~30 min)

Open `docs/EXTERNAL_VALIDATION.md`, Path 1. The short version:

```sh
git clone git@github.com:cryptoleo79/YAMORI.git
cd YAMORI/contracts/credential-gate/deploy
npm install
cp .env.template .env                 # then set MIDNIGHT_MNEMONIC
cd ../issuer && npm install && npm run gen-issuer && cd ../deploy
docker run -d -p 6300:6300 midnightntwrk/proof-server:8.1.0-rc.1
npm run demo:clean
```

Confirm the six output lines in order:

```
[ISSUE]  credential written: out/cred-...json
[IMPORT] manual wallet verification step — not automated by this CLI
[IMPORT] credential signature PASS (ed25519, off-chain, independent of YAMORI)
[FAIL]   swap without credential → reverted: Credential required
[PROVE]  prove_kyc                → txHash ...
[PASS]   swap with credential     → txHash ...
```

Then open the live contract on NightForge:
`https://preview.nightforge.jp/tools/contracts.html?address=7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`

The two tx hashes from `[PROVE]` and `[PASS]` should appear in the
contract's recent activity within ~30 s.

## 4. Wallet path (~15 min)

Open `docs/EXTERNAL_VALIDATION.md`, Path 2. The short version:

1. Unzip `yamori-v1.5.0.zip`.
2. `chrome://extensions` → Developer mode → Load unpacked → point at the unzipped folder.
3. Open the popup, **create a fresh test wallet** (do not import any wallet you actually use).
4. Navigate to Credentials → tap **Import Credential JSON**.
5. Upload (or paste) a `cred-*.json` file produced by the issuer CLI.
6. Look for `✓ signature verified` with issuer + claim + expiry. Save.
7. Open
   `https://preview.nightforge.jp/tools/contracts.html?address=7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703`
   and confirm the page loads with the contract's metadata.

## 5. What not to assume

- The credential flow today is **ed25519 signed selective disclosure**.
  It is **not** a zero-knowledge predicate proof. The on-chain checks
  are: issuer is in the trusted set, and `blockTimeLt(expires_at)`.
- The CredentialGate contract is on **Midnight preview**, not mainnet.
- The wallet extension is loaded **unpacked** for this test; this is a
  developer build, not a Chrome Web Store install.
- No mainnet funds are involved at any step. The deploy wallet runs on
  preview tDUST from the Midnight faucet.

## 6. Return

When you finish:

- Fill in `docs/FRICTION_LOG_TEMPLATE.md` and send it back. Don't
  self-edit your raw notes.
- Attach screenshots or terminal output for anything that broke.
- If something looked wrong but you can't reproduce it, write it down
  anyway. "I'm not sure" entries are useful.

That's all. Don't tell us how to fix it; tell us what made you stop.
