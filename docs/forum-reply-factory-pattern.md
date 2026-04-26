> Notes: Thread is real and unanswered (0 replies) at https://forum.midnight.network/t/factory-pattern-for-tracking-deployed-contracts-best-practice-on-midnight/1176. OP asks 3 things: (1) on-chain registry pattern, (2) factory-from-contract support, (3) indexer-by-bytecode. Reply addresses #3 directly with the existing NightForge endpoints, sidesteps #2 (we don't know yet), and gently nudges on #1.

---

Hey — late reply, but this is exactly the question we built one of the NightForge tools for, so figured it's worth dropping the pattern here.

**Indexer-based discovery (your option 3) already works today.**

Every successful contract deploy on Midnight emits a `midnight.ContractDeploy` event on the chain itself. So you don't actually need a registry contract or a custom backend — you can scan the chain for that one event and reconstruct the full set of deployed addresses with their deploy block, timestamp, and tx hash.

We do this in our explorer's indexer: filter `events.section = 'midnight' AND events.method = 'ContractDeploy'`, then unwrap the `contractAddress` from the event payload. That's it — no bytecode matching needed, because the deploy event is the canonical signal.

We expose the result as a public JSON feed if you want to skip running your own indexer:

- **Live tool (visual heatmap of deploys + calls):** https://mainnet.nightforge.jp/tools/contracts.html
- **Raw deployed-contracts list:** https://mainnet.nightforge.jp/api/contracts/deployed
- **30-day call/deploy heatmap:** https://mainnet.nightforge.jp/api/contracts/heatmap

Example shape from `/api/contracts/deployed`:

```json
{
  "total": 117,
  "contracts": [
    { "address": "0x6d69...213d2", "txHash": "0xfa07...9e7d", "block": 521144, "timestamp": 1777027590 }
  ]
}
```

For your ticketing dApp, that means you can drop the off-chain Postgres registry entirely and instead derive "all events deployed by this factory" from chain events plus a small filter (e.g. organizer pubkey in the deploy tx, or a known initial-state shape).

We don't yet have a strong answer on contract-deploys-contract (your option 2) — haven't seen it in practice on mainnet — so curious if anyone from the core team can confirm.

— NightForge
