# External Validation

Goal: one external developer and one wallet tester each run through the
system once, end-to-end, without hand-holding. We record where reality
pushes back.

Two paths below. Each tester picks **one** and follows it cold. The
shorter `docs/EXTERNAL_TEST_PLAN.md` is the quick-start view of the
same steps; this doc is the full handoff with prerequisites.

Time budget:
- Developer path: ~30 min first run (clone + install + DUST faucet + demo)
- Wallet tester path: ~15 min (extension load + credential import)

When you hit friction, record it in `docs/FRICTION_LOG_TEMPLATE.md` and
return that file. Don't ping the team mid-test for guidance — silence
is part of the test.

---

## Path 1 — Developer tester

### Prerequisites

- Node.js 20+
- git
- Docker (for the Midnight proof server)
- A Midnight **preview** wallet mnemonic (24 words). If you don't
  already have one, generate via `npm run gen` after the clone in
  step 2 — that script writes a fresh mnemonic to `.env`.
- That wallet must hold **preview DUST**. Get it from the Midnight
  Foundation faucet (https://midnight.network/test-tdust). The demo
  spends DUST for `prove_kyc` and `swap` — a zero-DUST wallet will
  hang at the PROVE step.

### Steps

1. **Clone the repo**

   ```sh
   git clone https://github.com/cryptoleo79/YAMORI.git
   cd YAMORI/contracts/credential-gate/deploy
   ```

2. **Install + configure**

   ```sh
   npm install
   cp .env.template .env
   # Open .env and set MIDNIGHT_MNEMONIC=<your 24-word preview mnemonic>
   # Or: npm run gen   (generates a fresh mnemonic into .env)
   ```

   Note: the repo at `github.com/cryptoleo79/YAMORI` is currently
   invite-only. If `git clone` returns 404, ask the operator for access
   or a release tarball of `contracts/credential-gate/`.

3. **Start the proof server** (in a separate terminal)

   ```sh
   docker run -d -p 6300:6300 midnightntwrk/proof-server:8.1.0-rc.1
   ```

4. **Generate the issuer keypair** (one time only — skip if `../issuer/keys/issuer.json` exists)

   ```sh
   cd ../issuer && npm install && npm run gen-issuer && cd ../deploy
   ```

5. **Run the demo**

   ```sh
   npm run demo:clean
   ```

   Expected output, in order:

   ```
   Contract: 7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703
   [ISSUE]  running issuer CLI for alice ...
   [ISSUE]  credential written: out/cred-<uuid>.json
   [IMPORT] manual wallet verification step — not automated by this CLI
   [IMPORT] credential signature PASS (ed25519, off-chain, independent of YAMORI)
   [FAIL]   swap without credential → reverted: Credential required
   [PROVE]  prove_kyc                → txHash <hash>
   [PASS]   swap with credential     → txHash <hash>
   ```

   The two `txHash` values are real signed transactions on Midnight
   preview. You can verify them in step 7.

6. **Confirm FAIL → PROVE → PASS**

   - The `[FAIL]` line proves the contract rejects unauthorized swaps
     (a Compact `assert` reverts; the demo catches the revert and
     records it as the expected failure path).
   - The `[PROVE]` line proves the credential was recorded on chain.
   - The `[PASS]` line proves the same swap call now succeeds because
     the credential exists and has not expired.

   If the demo halts at `[IMPORT]` with `credential signature INVALID`,
   the issuer keypair is missing or out of sync — re-run step 4.

   If the demo halts at `[PROVE]` with `InsufficientFunds`, your wallet
   has no DUST — return to the prerequisites and fund it.

7. **Open the live preview contract on NightForge**

   - https://preview.nightforge.jp/tools/contracts.html?address=7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703
   - You should see the contract metadata, recent transactions, and
     your two new tx hashes from step 5 appearing in the contract's
     activity (allow ~30 s for indexer propagation).

8. **Record friction** in `docs/FRICTION_LOG_TEMPLATE.md` and submit.

---

## Path 2 — Wallet tester

### Prerequisites

- Google Chrome or Brave or Chromium (any Chromium-based browser
  with Manifest V3 support — Chrome 116+)
- The latest YAMORI extension zip: `YAMORI/yamori-v1.5.0.zip`
- One signed credential JSON file produced by the issuer CLI. Either:
  - Ask the operator for a pre-issued `cred-*.json` file, or
  - Produce one yourself by running steps 1–4 of Path 1 plus
    `cd contracts/credential-gate/issuer && npm run issue -- --subject <hex32> --claim kyc_passed --expires-days 90`

### Steps

1. **Load the extension**

   - Unzip `yamori-v1.5.0.zip` to a folder
   - Open `chrome://extensions` in Chrome
   - Enable **Developer mode** (top-right toggle)
   - Click **Load unpacked** → point at the unzipped folder (the
     folder that contains `manifest.json`)
   - The YAMORI icon should appear in the toolbar. Pin it for
     convenience.

2. **Confirm the wallet opens**

   - Click the YAMORI icon. A popup opens.
   - On first run you'll be asked to either create a new wallet or
     import a mnemonic.
   - **Create** a fresh wallet for the test (don't import your real
     mainnet wallet — this is a manually-loaded development build).
   - You'll be shown a 24-word mnemonic. Save it somewhere ephemeral;
     the test wallet has no real funds.
   - Set a password when prompted.

3. **Verify the credentials page opens**

   - Navigate to the **Credentials** tab inside the popup.
   - You should see three buttons:
     - **Import Credential JSON** (green, primary)
     - **Issue DEV Test Credentials** (amber, for local dev only)
     - **Verifier Demo** (purple)
   - Bottom of the page reads:
     `Backend: signed selective disclosure (ed25519). Not ZK predicates.
     Issuer trust established on chain via add_issuer(pkHash).`

4. **Import the signed credential JSON**

   - Click **Import Credential JSON**.
   - In the modal, either click the file picker and select the
     `cred-*.json` file, or paste its full JSON contents into the
     textarea.
   - Within ~1 s, a green box should appear:
     ```
     ✓ signature verified
     issuer:  CredentialGate Issuer (issuer-credgate-v1)
     claim:   kyc_passed
     expires: 2026-08-08 05:35 UTC
     ```
   - If the file was tampered, you'll instead see:
     `✗ signature INVALID — credential rejected`
     and the Save button stays disabled. That's the correct fail path.
   - On success, click **Save credential**. The credential appears in
     the credentials list with its issuer and claims.

5. **Open the live preview contract on NightForge**

   - https://preview.nightforge.jp/tools/contracts.html?address=7ee02faf5e88911e2f4b12edfb95bb4612282b3ad26536ff9d5ce290fa7a3703
   - This is the contract YAMORI's credential was signed against. It
     should load quickly with contract metadata + recent activity.

6. **Try the network selector on NightForge**

   - Open https://nightforge.jp (apex) and click the network dropdown
     in the header. Switch to Preview and Preprod. Each switch should
     navigate to the corresponding subdomain and show the correct
     label (Mainnet/green, Preview/cyan, Preprod/orange) on first
     paint.

7. **Record friction** in `docs/FRICTION_LOG_TEMPLATE.md` and submit.

---

## What is being tested

- That a stranger can run the demo end-to-end without slack pings.
- That the credential import flow is honest about what it verifies
  (signed disclosure, not ZK) and refuses tampered credentials clearly.
- That NightForge's live contract view aligns with the demo output.
- That the network selector and host labeling are unambiguous.

What is **not** being tested (intentionally):

- Mainnet shield/unshield (upstream `midnight-node#1206` blocker;
  YAMORI keeps shield UI gated by `mainnetConfirmed`).
- Mainnet DUST generation (upstream HRP mismatch under investigation
  by the Foundation).
- Wallet recovery from passkey/biometric (out of scope for this pass).

These are downstream-of-upstream issues documented in
`docs/OBSERVATION_MODE.md`. A tester encountering any of them should
note it and move on, not block.
