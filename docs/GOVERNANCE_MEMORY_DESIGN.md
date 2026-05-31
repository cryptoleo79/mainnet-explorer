# NightForge as Canonical Governance Memory

**Design document — not implementation. No code. No pages. No widgets.**

Dated 2026-05-31. Anchored to the ecosystem state captured in `docs/ECOSYSTEM_WAKEUP_PLAN.md`.

## Strategic question

> Can NightForge become the place that remembers governance history, not just current governance state?

**Short answer: yes, with caveats.** The chain itself is canonical for *whether* a change happened; an indexer is canonical for *making it queryable today*. Neither guarantees long-horizon retention or migration-safe queryability. NightForge can become the canonical *human-readable, verifiable, append-only* memory of governance changes — provided it (a) ingests reliably, (b) verifies every entry against the on-chain block it cites, (c) survives indexer migrations, (d) is transparently inspectable by third parties.

This is a positioning move, not a feature pass. It costs little to set up and pays off precisely when an indexer resets, the Foundation re-shards a public host, or a researcher asks "what was D-parameter on 2026-03-01" two years from now.

---

## 1. Data source map

### D-parameter

| field | value |
|---|---|
| **What it is** | The Decentralization parameter — `(numPermissionedCandidates, numRegisteredCandidates)` per epoch — controls the mix of permissioned vs registered block producers in the committee |
| **On-chain source of truth** | `Block.systemParameters.dParameter` — present on every block; canonical |
| **Indexer query (snapshot)** | `Query.dParameterHistory → [{ blockHeight, timestamp, numPermissionedCandidates, numRegisteredCandidates }]` |
| **Indexer subscription (live)** | `Subscription.blocks → Block.systemParameters.dParameter` — fires on every new block; D-parameter only *changes* on policy events, so most fires are no-ops |
| **Already wired in NightForge** | `GET /api/governance/d-parameter` (`src/api/server.ts:2890`), consumed by the homepage Decentralization Dial widget (`nightforge-main.html:1159`, `:1313`) |
| **Current mainnet content** | 2 events: genesis `{10, 0}` → block 522886 `{130, 0}` |
| **Current preview / preprod content** | empty (chain has no governance events) |
| **Retention model upstream** | Implicit — indexer rebuilds from chain on reindex, so history is in principle always reconstructible from blocks. In practice an indexer reset is downtime; during downtime, queries fail; after, schema may have changed |

### Terms & Conditions history

| field | value |
|---|---|
| **What it is** | Each on-chain T&C revision — `{hash, url, blockHeight, timestamp}` — recording when chain-governing terms were updated and where the document lives |
| **On-chain source of truth** | T&C storage in chain state; canonical |
| **Indexer query (snapshot)** | `Query.termsAndConditionsHistory → [{ blockHeight, timestamp, hash, url }]` |
| **Indexer subscription (live)** | none specifically; detected via `Subscription.blocks` watching for state-root changes affecting the T&C key (less direct than `dParameter` which is in `systemParameters`) |
| **Already wired in NightForge** | `GET /api/governance/tc-history` (`src/api/server.ts:3050`), uses `termsAndConditionsHistory { blockHeight timestamp hash url }` |
| **Current mainnet content** | 1 event (genesis) |
| **Off-chain dependency** | `url` field points off-chain; the document at that URL is not pinned to the chain. **A canonical memory should snapshot the document content, not just the URL** — see Storage Model |

### Retention limitations (the reason this design matters)

1. **Indexer reset wipes the queryable history** even though the chain still has the underlying blocks. Reconstructing requires a fresh reindex which can take days.
2. **Indexer schema change** can rename or remove the history fields. Examples already in our memory: `NativePoint → JubjubPoint`, `Transaction.fees` moved to `RegularTransaction.fees`, `endIndex` fields added in v4.3.3-rc.
3. **Off-chain T&C document loss** — if the issuer's URL goes dark, the historical document text is lost from the human-readable record, even though the on-chain hash remains.
4. **Cross-version queryability** — if v4.4 changes the response shape, applications break. A NightForge-side store insulates downstream consumers.

### API requirements for NightForge to become memory

- Read access to the indexer GraphQL endpoint per env (already in place)
- Subscription transport (WebSocket) per env (already in place for `Subscription.blocks` on the Live Feed)
- Append-only persistence on the NightForge backend (SQLite is already used — `data/mainnet.db`, `data/blockchain.db`)
- Outbound HTTPS to fetch + hash the T&C document at its `url`
- A public read API exposing the stored history, with verification metadata per entry

---

## 2. Storage model

### Principles

1. **Append-only.** No updates, no deletes. A "correction" is a new event with a `supersedes` pointer. The on-chain record can't be retracted; neither can NightForge's.
2. **Block-anchored.** Every row references a `blockHeight` + `blockHash`. The chain is the verifier.
3. **Per-env, per-type.** Mainnet / preview / preprod are isolated stores. D-parameter and T&C are separate tables.
4. **Sized for decades.** D-parameter changes maybe 1× per epoch; T&C changes maybe 1× per year. SQLite handles `< 1M` rows trivially. No PostgreSQL needed.
5. **Verification metadata in-row.** Every row carries `indexer_seen_at`, `chain_verified_at`, `verifier_signature_or_null` so a reader can see the provenance without leaving the row.

### Schema (illustrative, not implementation)

```
table: governance_d_parameter_<env>
  block_height                INTEGER  PRIMARY KEY
  block_hash                  TEXT     NOT NULL
  block_timestamp             INTEGER  NOT NULL   -- chain timestamp
  num_permissioned_candidates INTEGER  NOT NULL
  num_registered_candidates   INTEGER  NOT NULL
  source_indexer_url          TEXT     NOT NULL   -- which indexer host returned this
  source_indexer_version      TEXT     NOT NULL   -- v4.3.x line
  indexer_seen_at             INTEGER  NOT NULL   -- when NightForge first ingested
  chain_verified_at           INTEGER             -- when last block-replay verified
  superseded_by_block_height  INTEGER             -- non-null only if a later correction event
  notes                       TEXT                -- free-form (e.g. "ingested via subscription")

table: governance_tc_<env>
  block_height                INTEGER  PRIMARY KEY
  block_hash                  TEXT     NOT NULL
  block_timestamp             INTEGER  NOT NULL
  doc_hash                    TEXT     NOT NULL   -- as recorded on chain
  doc_url                     TEXT     NOT NULL   -- as recorded on chain
  doc_url_first_seen_at       INTEGER             -- when we first fetched the URL
  doc_content_sha256          TEXT                -- our re-hash of fetched content
  doc_hash_matches            BOOLEAN             -- whether our fetched content's hash matches the on-chain doc_hash
  doc_snapshot_path           TEXT                -- local path to the captured doc bytes (read-only after capture)
  source_indexer_url          TEXT     NOT NULL
  source_indexer_version      TEXT     NOT NULL
  indexer_seen_at             INTEGER  NOT NULL
  chain_verified_at           INTEGER
  notes                       TEXT
```

### Backup model

- **Hot store**: `data/governance.db` on the NightForge box (single SQLite file)
- **Daily snapshot**: copy + integrity-checked digest to off-disk (S3-compatible or a second box). Append-only on the snapshot side too.
- **Snapshot pruning**: never. Storage cost is trivial; the value of a 2-year-old snapshot is precisely that it is 2 years old.
- **Document snapshots** (T&C body bytes) are content-addressed by the on-chain `doc_hash`. Two events with the same hash deduplicate to one snapshot file.

### Revision tracking

A change to D-parameter is itself a new event with a new `block_height` — there is no in-place update. The "revision history" emerges from the rows ordered by `block_height`.

The `superseded_by_block_height` column is reserved for an unlikely-but-possible case: indexer returns an entry that, after independent verification, turns out not to be in the canonical chain. In that case the row is **not deleted** — a new row with `block_height = <correction>` is inserted with `notes` describing the correction, and the corrupt row's `superseded_by_block_height` is set. The original is preserved for auditability; downstream reads default to filtering out superseded rows.

---

## 3. UI concept

Four reading surfaces. All read-only. All derive from the same storage; no separate state. None of these are pages-to-build today — this is the conceptual map.

### 3.1 Timeline view

| element | content |
|---|---|
| layout | vertical timeline anchored on left, newest at top |
| each event card | block height + chain timestamp + change summary (e.g. "D-parameter changed from (10, 0) to (130, 0)") + indexer-attribution badge |
| filter | per env (Mainnet / Preview / Preprod), per type (D-parameter / T&C), per date range |
| empty state | "No governance events recorded since (chain genesis | first-ingested-block)" — honest, not a "coming soon" |
| verification chip per event | green if `chain_verified_at` is recent and matches; amber if stale; red if mismatch |

### 3.2 Change history view (per parameter)

| element | content |
|---|---|
| layout | table; columns `Block`, `Date`, `Field`, `From`, `To`, `Verified`, `Source` |
| sort | by block descending |
| field-level granularity | one row per *changed field* per event, not one row per event. A single event that changes `numPermissioned` 10→130 AND `numRegistered` 0→5 produces two rows. This makes parameter-specific history (e.g. "show me only `numPermissioned` history") trivially filterable. |
| export | CSV + JSON download per filtered view |

### 3.3 Current state view

| element | content |
|---|---|
| layout | "what is D-parameter right now" + "what is the current T&C document hash" at the top |
| computation | takes the row with the largest `block_height` from each parameter, after filtering out `superseded_by_block_height` rows |
| companion | "Since block X (Y time ago)" + a link to the change-event card in the Timeline view |
| trust note | "Stored memory matches indexer at <indexer_url> as of <chain_verified_at>" — honest, dated |

### 3.4 Diff view

| element | content |
|---|---|
| inputs | two block heights (any pair from the store) |
| output | side-by-side table of every governance parameter, with values at `A` and at `B`, with changes highlighted |
| convenience | "Diff vs current state" with one click |
| use case | a researcher asks "what changed between epoch 100 and epoch 200" — diff view answers in one query |

### What none of these views should be

- Not a real-time *animated* timeline. Governance changes too infrequently to justify animation; it would be theater.
- Not a sentiment / activity score. There is no "governance score" — the data is fact, not feeling.
- Not a homepage hero card. Governance memory is reference material, not first-paint content.

---

## 4. Operational model

### Update frequency

- **Primary**: `Subscription.blocks` per env. Every new block fires; the daemon checks if `Block.systemParameters.dParameter` has changed vs the last stored event. If yes, upsert. T&C update is detected via state-root delta on the T&C key (preferred) or — if that's not directly observable — by polling `Query.termsAndConditionsHistory` and looking for new entries.
- **Fallback (heartbeat poll)**: every 5 minutes, fetch `Query.dParameterHistory` and `Query.termsAndConditionsHistory` in full, diff against stored, upsert new entries. Catches anything the subscription missed (transport reconnect, indexer hiccup).
- **Document refetch**: T&C `doc_url` is fetched once at first sighting and verified against `doc_hash`. Periodic re-fetch (weekly) to detect URL drift; record `doc_hash_matches: false` if the URL now serves different bytes — but do not overwrite the original snapshot.

### Failure modes

| mode | behavior |
|---|---|
| Indexer down | New ingest pauses; existing stored history continues to be served. `/api/governance/d-parameter-history?source=stored` keeps working. The `chain_verified_at` field will gradually become stale; UI surfaces the staleness honestly. |
| Indexer schema change (e.g. field rename) | Ingest job fails loudly. Heartbeat job logs the failure to `BUG_BACKEND_TIMEOUTS.md` equivalent. Stored history continues to serve; new events stop accumulating until the ingestor is patched. Do not attempt schema auto-detection — it hides drift. |
| Subscription disconnect | Reconnect with exponential backoff. Once reconnected, run a catch-up poll against `dParameterHistory` to ingest anything missed during disconnect. |
| Indexer disagrees with stored row | Loud alert. **Do not auto-correct.** Both the stored row and the indexer's response are persisted in the audit log. Operator decides whether to insert a `superseded_by` row. |
| Disk failure | Daily snapshot restore. Catch-up poll fills the gap. |
| T&C URL serves new content | `doc_hash_matches` flips to `false` for the affected row; UI shows an amber "URL drift detected" chip; original snapshot bytes are still served from `doc_snapshot_path`. |

### Verification path

Every stored entry is verifiable independently:

1. Reader queries `/api/governance/d-parameter-history` and gets back rows with `block_height` + `block_hash`
2. Reader hits `/api/blocks/<block_height>` (already exposed) and checks the returned block's hash matches
3. Reader queries `Block.systemParameters.dParameter` directly against any public indexer and confirms the value matches the row
4. For T&C: reader fetches `/api/governance/tc-snapshot/<doc_hash>` (would need to be added), independently hashes the bytes, confirms against the on-chain `doc_hash`

Steps 1–3 work today against the existing endpoints with no new code. Step 4 needs the snapshot serving — the only new public API surface this design requires.

NightForge does NOT sign its own claims. The signature on a governance fact is the chain's. NightForge's job is to relay + persist + expose, not to authenticate.

### Reproducibility guarantees

| guarantee | how |
|---|---|
| **Every value is reproducible from chain** | every row cites `block_height` + `block_hash`; anyone can re-derive |
| **Stored history is auditable** | append-only schema; `notes` documents any superseded row; daily snapshot to off-disk preserves the audit trail outside the running box |
| **Schema is documented** | publicly, in this doc and a future `/api/docs#governance-memory` section |
| **Third-party reindex is possible** | given the public read API, any third party can replicate the store; the design encourages it |

The point: **NightForge does not require trust**. A user who doesn't trust NightForge can use the stored data as a hint and verify every claim against the chain.

---

## 5. Minimal implementation plan

Each phase is independently shippable. No phase blocks deployment; each leaves the system in a strictly-better state. No phase modifies the deployed contract or the wallet.

### Phase 1 — Read-through proxy with explicit memory disclaimer (low risk, high info)

- Confirm and document the existing `/api/governance/d-parameter` and `/api/governance/tc-history` endpoints as the live-pass-through interface
- Add a one-line response header / wrapper field that advertises: `"source": "live", "indexer": "<host>", "retention": "indexer-dependent"`
- Update `/api/docs` to describe this honest model
- No new persistence. No new pages. No new widgets. **Cost: half a day.**
- **Outcome**: anyone consuming the API knows what they are consuming and the limitations

### Phase 2 — Persist behind the proxy (the core memory)

- Add `data/governance.db` with the two tables described in §2
- Add an ingest daemon (runs in-process inside the existing indexer service, or as a separate `governance-memory` systemd unit — choice deferred to implementation)
- Daemon flows:
  - on startup, run full catch-up poll of `dParameterHistory` + `termsAndConditionsHistory`
  - subscribe to `Subscription.blocks`; check `systemParameters.dParameter` on each new block for changes; upsert if changed
  - poll heartbeat every 5 minutes
- Extend `/api/governance/d-parameter` and `/api/governance/tc-history` with a `?source=stored|live|both` query parameter (default `both`)
- For T&C: add `doc_url` fetcher + `doc_hash` verifier; store the document body at `data/governance-docs/<doc_hash>` (content-addressed, immutable)
- Add `/api/governance/tc-snapshot/<doc_hash>` to serve the captured bytes (read-only)
- Add the daily snapshot job (cron or systemd timer)
- **Cost: 2–3 days for backend, plus an env-by-env catch-up window**
- **Outcome**: NightForge owns a durable, append-only, verified governance record that survives indexer resets

### Phase 3 — Surface the memory (the UI debt)

- Add `tools/governance.html` (or extend an existing page) with the four views from §3
- No homepage hero, no new tab — the Tools page is the right home
- Diff view + CSV export are the highest-leverage additions (auditors and researchers want them)
- Update `tools/index.html` to link the page (forward-only, scope-prefixed)
- Update `docs/REPO_TOPOLOGY.md` Safe Cleanup section if any old governance widget gets retired
- **Cost: 2–3 days for UI**
- **Outcome**: NightForge becomes the *human-readable* canonical memory, not just a backend store

Phases 1–3 in sequence map to three forward-only commits per phase (api / data / tools), each scope-prefixed, each tested against mainnet (real data), preview (empty data), and preprod (empty data). Phase 1 unblocks Phase 2 unblocks Phase 3, but each phase is releaseable on its own.

### What is explicitly OUT of scope for the first implementation pass

- Cross-chain governance comparison (Cardano partner-chain, etc.) — too speculative
- "Governance change predictions" — there is no signal for this; would be theater
- Governance voting interface — NightForge is read-only by mandate
- A homepage hero card or animated timeline — governance is reference material, not first-paint content
- Mutating any deployed contract — out of mandate
- Any wallet integration — out of mandate

---

## Answering the strategic question

**Can NightForge become the place that remembers governance history?**

Yes — provided we accept that:

1. **NightForge is not the source of truth.** The chain is. NightForge is the *durable, verifiable, queryable mirror* of governance facts.
2. **The value proposition is precisely the layer the chain + indexer don't provide.** Long retention. Append-only audit log. Off-chain document snapshots. Cross-indexer-version stability. Public read API with verification metadata in every row.
3. **The cost is low.** SQLite + a small daemon. Storage growth measured in kilobytes per year.
4. **The risk is operational, not technical.** A canonical memory must be backed up, monitored for divergence, and never silently corrected. The schema in §2 makes silent correction structurally impossible.
5. **Differentiation is real.** No other Midnight explorer surfaces governance history at all (per the 2026-05-30 ecosystem scan in `ECOSYSTEM_WAKEUP_PLAN.md`). midnightexplorer.com has tx + block charts; Subscan has Substrate-pattern accounts; neither has governance memory. This is a genuine first.

The honest framing for users: **"NightForge remembers what the chain remembers, but in a form you can ask questions about."**

That framing is true today (we already proxy the indexer). The full memory model in §1–§4 makes it remain true even if the indexer schema changes, the indexer resets, the T&C URL goes dark, or the canonical chain explorer moves elsewhere.

---

## Cross-references

- `docs/ECOSYSTEM_WAKEUP_PLAN.md` — broader research that surfaced governance as the highest-leverage DO NOW item
- `docs/REPO_TOPOLOGY.md` — repo / domain / branch mapping (governance store would live in mainnet-explorer/data/)
- `docs/DEPLOY_FLOW.md` — deploy + rollback procedure (no changes required for phases 1–3)
- `docs/OBSERVATION_MODE.md` — what is frozen at the current milestone (this design adds new surfaces; does not modify frozen ones)
- `docs/COMMIT_AND_PR_STYLE.md` — scope prefix expectations (api, data, tools, docs)
- `src/api/server.ts:2890` (`/api/governance/d-parameter`) and `:3050` (`/api/governance/tc-history`) — the existing surfaces this design extends
- `website/nightforge-main.html:1159`, `:1313` — the homepage Decentralization Dial widget that already consumes this data (would not change)

**No implementation has been written. No pages have been added. No widgets have been built. This is design only.** Per-phase implementation requires explicit approval.
