# NightForge — Commit & PR Style

All commits and PRs must read like professional, auditable engineering work.

No noise. No fluff. No hype. No AI traces. No fake values. No unverifiable claims.

## Commit Format

```
<scope>: <action>
```

### Allowed scopes

```
api | web | tools | explorer | data | nginx | docs | build | perf | ui | truth
```

### Rules

- lowercase scope
- imperative verb (`add`, `fix`, `remove`, `replace`, `defer`, `tighten`)
- max 72 characters in the title
- no vague words: `update`, `stuff`, `misc`, `changes`
- no AI / Claude / co-author attribution

### Good

```
truth: remove hardcoded health score fallbacks
api: add dust eligibility endpoint
ui: defer background canvas behind requestIdleCallback
perf: cap canvas to viewport height + 30fps + reduce nodes
docs: add commit + PR style policy
tools: sweep em-dash placeholders to add awaiting-data title
```

### Bad

```
update stuff
final fixes
wow changes
Claude cleanup
fix bug
misc
```

## PR Title

Same format as the commit title.

```
<scope>: <clear milestone>
```

Examples:

```
truth: enforce truth rule on Network Status card and validators page
perf: tame background animation + 3-tier boot
api: indexer v4.1 fields + 6 new widgets
```

## PR Description Template

```markdown
## Summary
One paragraph explaining what this PR does.

## Includes
- concrete change
- concrete change
- concrete change

## Observed Issue
- what was wrong
- where it appeared
- logs / signals / screenshots if relevant

## Root Cause
- concise technical cause if known

## Changes
- exact behavior introduced

## Truth / Data Safety
- every visible number is live, derived, canonical, or explicit empty state
- no mock/fake/hardcoded live-looking values
- preview/mainnet labels are explicit
- no stale value presented as current

## Security / Safety
- key material impact (none / list)
- wallet/vault impact (none / list)
- signing/proof impact (none / list)
- fallback behavior (honest empty / explicit error)

## Verification
- commands run
- URLs checked
- endpoint responses
- build result
- deploy result

## Success Criteria
- measurable outcome
- measurable outcome
```

## Debug PRs Must Include

```markdown
**Observed:**
**Root cause:**
**Fix:**
**Verification:**
```

## Tone Rules

Write like an engineer.

**Do:**

- be precise
- use facts
- mention exact files (`src/api/server.ts:2440`), endpoints (`/api/mainnet/dust-eligibility`), commits (`8ab0627`), tx hashes (`cf00cff5…`), blocks (`#454,958`)
- state limitations clearly

**Do not:**

- hype ("massive upgrade", "world-class", "revolutionary")
- exaggerate ("everything is fixed")
- write marketing language
- imply official endorsement
- claim "first" unless proven
- claim ZK if it is signed disclosure
- claim mainnet when it is preview

## Truth Rule (mandatory in every PR)

Every displayed metric must be one of:

1. live API value
2. derived from live API value
3. canonical on-chain / deployment fact
4. explicit unavailable / empty state

If not, remove it.

In the PR description, classify the metrics added or changed by category.

## What "audit-ready" means

If a Midnight / Cardano engineer reads the PR, they must immediately understand:

- what the problem was
- what changed
- why it is safe
- how it was verified

If the PR cannot answer those four questions in plain language, it is not ready to merge.
