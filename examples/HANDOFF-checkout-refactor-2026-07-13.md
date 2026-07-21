---
handoff: "checkout-refactor"
date: "2026-07-13 16:42 CDT"
project: "acme-storefront"
branch: "feat/checkout-v2"
head_sha: "4f9c2ae"
validity: "until the next push to feat/checkout-v2"
supersedes: "HANDOFF-checkout-refactor-2026-07-11.md"
chain: "3 of 3"
next_action: "Fix the failing idempotency-key test in tests/payments/test_capture.py (see §Resume point) and get the suite back to green before touching the webhook branch."
do_not: "Do NOT deploy to staging or merge feat/checkout-v2 until the user has reviewed the Stripe capture-timing change."
open_tasks: 4
---

# HANDOFF — Checkout Refactor (2026-07-13, late afternoon)

## Lineage

Supersedes `HANDOFF-checkout-refactor-2026-07-11.md`. Chain: doc 3 of 3 — full
history: `ls docs/HANDOFF-*`. Carry-forward: the payment-provider decision matrix
is still ONLY in doc 1 (`HANDOFF-checkout-refactor-2026-07-08.md` §4) — read it
before proposing any provider change.

## TL;DR — where to start

1. **Fix the failing test**: `tests/payments/test_capture.py::test_idempotency_key_reuse`
   broke when we moved capture from order-creation time to fulfillment time. The
   test still asserts the OLD timing. Update the test, not the code — the new
   timing is LOCKED (see below).
2. Re-run the full suite (`make test` — 212 tests, 211 passing at handoff).
3. Then resume the webhook retry work on `src/webhooks/retry.py` (§Open work).
4. Deploy/merge is user-gated — see Tripwires.

## Tripwires — actively guard these

- `[IRREVERSIBLE]` **No staging deploy, no merge** of `feat/checkout-v2` until the
  user reviews the capture-timing change — they asked to eyeball it first.
- `[FOOTGUN]` `make deploy-staging` reads the WORKING TREE, not the last commit —
  stash unrelated WIP before running it (this bit us on 07-10).
- `[FOOTGUN]` The Stripe test-mode webhook secret in `.env.local` differs from the
  one in CI — a webhook test that passes locally can still fail in CI. Check CI,
  not just local green.

## LOCKED — settled decisions (do not relitigate)

- **Capture at fulfillment, not at order creation** — because refund volume on
  cancelled-before-shipment orders was 11% of support load; reopen-if Stripe's
  auth-expiry window (7 days) becomes a problem for made-to-order items.
- **Idempotency keys are order-scoped, not request-scoped** — because retried
  fulfillment jobs must not double-capture; reopen-if we ever split fulfillment
  into partial shipments.
- **No provider switch this quarter** — rationale in doc 1 §4; reopen-if the
  Stripe fee renegotiation (user's thread, not ours) fails.

## Resume point + first reply

We were mid-way through adapting the test suite to the capture-timing change.
The code change itself is DONE and committed (`4f9c2ae`): capture now happens in
`FulfillmentService.complete()` instead of `OrderService.create()`. Test adaptation
was in progress:

1. `test_capture_on_fulfillment` — rewritten, passing.
2. `test_no_capture_on_order_create` — new, passing.
3. `test_idempotency_key_reuse` — STILL FAILING: it creates an order and asserts a
   capture exists immediately (old timing). It needs to call
   `FulfillmentService.complete()` first, then assert the capture, then retry the
   fulfillment job and assert NO second capture (the actual idempotency property).

My last substantive recommendation, verbatim: "Update the test to the new timing
rather than adding a compatibility shim — the shim would re-create the old
double-capture window in test code and someone will copy it."

The user's last message, verbatim: "agreed, fix the test — but I want to see the
capture-timing diff before anything ships."

Successor's first reply should be: "Picking up the checkout refactor — I'll fix
the idempotency test to match the new fulfillment-time capture and get the suite
green. The capture-timing diff is queued for your review before any deploy."

## Key file map

| Concern | File | Notes |
|---|---|---|
| Capture timing (the change) | `src/services/fulfillment.py` | `complete()` now owns capture — lines 88–131 |
| Old capture site (removed) | `src/services/order.py` | capture call deleted; comment marks why |
| Failing test | `tests/payments/test_capture.py` | `test_idempotency_key_reuse` — see Resume point |
| Webhook retry (next up) | `src/webhooks/retry.py` | skeleton only; design in §Open work |
| Deploy entrypoint | `Makefile` | `deploy-staging` reads working tree — see Tripwires |

## Open threads — what I believe but did NOT verify

- The Stripe auth-expiry window is 7 days for our account tier (`likely` — from
  docs, not our dashboard). Cheapest settle: check the dashboard's payment
  settings page.
- CI runs the payments suite against a pinned `stripe-mock` version that may not
  know fulfillment-time capture flows (`hunch`). Cheapest settle: read
  `.github/workflows/test.yml` for the pin and changelog-check it.
- `FulfillmentService.complete()` may be called twice concurrently by the job
  runner under retry storm (`confirmed-but-untested` — the runner docs say
  at-least-once). The idempotency key should make this safe; the fixed test is
  exactly the proof.

## Verification

Ground truth at handoff (2026-07-13 16:40 CDT):

```
git branch --show-current   → feat/checkout-v2
git rev-parse --short HEAD  → 4f9c2ae
make test                   → 212 tests: 211 passed, 1 failed (test_idempotency_key_reuse)
```

Re-verify before you act:

```bash
git status && git log --oneline -5
make test 2>&1 | tail -3
```

Mismatch = confirm with the user; don't abort.

## Tasks snapshot

- `T-41` · in_progress · Fix idempotency test for new capture timing · blockedBy: none
- `T-42` · pending · Webhook retry with exponential backoff · blockedBy: T-41
- `T-43` · pending · Capture-timing diff review · owner: user
- `T-38` · pending · Remove legacy cart sessions after v2 ships · blockedBy: T-43

Successor: re-hydrate these — they are the structured open-work list; treat §Open
work as the un-tracked remainder.

## Open work / queued items

- **Webhook retry** (`src/webhooks/retry.py`): skeleton committed, no logic. Design
  agreed in-session: exponential backoff 1s/4s/16s, max 3 attempts, dead-letter to
  `webhook_failures` table, alert only on dead-letter. Scope: ~half a day.

## Errors / lessons worth keeping

- `make deploy-staging` shipped un-stashed WIP on 07-10 — working-tree deploys are
  a footgun; now a Tripwire above.
- Early draft asserted "Stripe holds auths for 7 days" as fact; corrected to an
  unverified belief with a settle path. Don't launder docs-derived claims into
  ground truth.
