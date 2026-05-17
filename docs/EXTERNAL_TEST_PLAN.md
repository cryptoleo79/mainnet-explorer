# External Test Plan

Goal: someone unfamiliar with the system can run through this without
us guiding every click. Record friction. Don't optimise yet.

Time budget: ~10 minutes (observer); ~25 minutes (developer); ~15 minutes (wallet tester).

## 1. Open NightForge

Visit each:

- https://nightforge.jp
- https://mainnet.nightforge.jp
- https://preview.nightforge.jp
- https://preprod.nightforge.jp

For each, note:
- Does the page render quickly?
- Is anything still loading after 5 seconds?
- Anything that looks like a placeholder you expected to be a real value?

## 2. Confirm network selector

On each domain, look at the network selector in the top-right header.

Expected:
- `nightforge.jp` → Mainnet (green)
- `mainnet.nightforge.jp` → Mainnet (green)
- `preview.nightforge.jp` → Preview (cyan)
- `preprod.nightforge.jp` → Preprod (orange)

Click it and switch to another environment. The page should navigate
to the other subdomain.

## 3. View CredentialGate hero

On any host, the hero block shows the CredentialGate contract on
preview. Confirm visible:
- Contract address (truncated; full address in tooltip)
- Deploy tx hash, block, date
- Last `prove_kyc` and last gated swap (em-dash on hosts without the
  liveness route is expected — see OBSERVATION_MODE.md)
- "Preview" tag — the contract is on Midnight preview, not mainnet

## 4. Open the preview contract link

Click "View on preview explorer →" in the CredentialGate hero. It
should open the contract page on `preview.nightforge.jp/tools/contracts.html`
with the contract address pre-filled.

## 5. (Developer) Run the demo

```sh
# repo is currently invite-only — ask operator if 404
git clone git@github.com:cryptoleo79/YAMORI.git
cd YAMORI/contracts/credential-gate/deploy
npm install
cp .env.template .env       # then add MIDNIGHT_MNEMONIC
npm run demo:clean
```

Expected six lines, in this order:

```
[ISSUE]  running issuer CLI for alice ...
[ISSUE]  credential written: out/cred-...json
[IMPORT] manual wallet verification step — not automated by this CLI
[FAIL]   swap without credential → reverted: Credential required
[PROVE]  prove_kyc                → txHash ...
[PASS]   swap with credential     → txHash ...
```

If the demo halts at IMPORT with `credential signature INVALID`, the
issuer keypair is missing or out of sync — re-run `npm run gen-issuer`
in `contracts/credential-gate/issuer/`.

The `[IMPORT]` step is **not automated**. The CLI verifies the
credential signature independently before continuing; YAMORI's
Chrome-extension import is a separate manual step (see step 6).

## 6. (Wallet tester) Import a signed credential into YAMORI

1. Load the YAMORI extension (`YAMORI/dist/`) into Chrome via
   `chrome://extensions` → Developer mode → Load unpacked.
2. Open the popup → unlock or create a wallet.
3. Navigate to Credentials → tap **Import Credential JSON**.
4. Either upload `contracts/credential-gate/issuer/out/cred-*.json` or
   paste its contents.
5. Wait for the green `✓ signature verified` line. Confirm:
   - issuer name matches what `gen-issuer` printed
   - claim is `kyc_passed` or `age_over_18`
   - expires timestamp is in the future
6. Tap **Save credential**. The credential should appear in the
   credentials list.

If the signature shows `✗ signature INVALID — credential rejected`, the
file was tampered or canonicalization drifted — the credential is
correctly refused.

## 7. Record what was confusing

Free-form. Examples:

- A page where you couldn't tell whether you were on mainnet or preview
- A number that looked real but wasn't (please flag — these should not exist)
- A button that did nothing or was unclear
- A step in the demo that hung longer than 30 s without a status message
- Wording you didn't understand

Send the notes back without filtering. We want the friction, not a clean report.
