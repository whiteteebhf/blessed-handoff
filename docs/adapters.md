# Transport adapter contract

The `handoff` skill owns the handoff doc — what goes in it, how it's gated, where it lands. A **transport adapter** changes exactly one thing: how the doc reaches the successor (Step 4). Everything upstream — Steps 0–3.5, the resumability gate, the thin-loader principle — is reused, not reimplemented.

This page is the contract an adapter must satisfy. (A Telegram adapter was cut from v1.0; the seam stayed. This documents the seam.)

## What an adapter is

A separately installed skill (e.g. `handoff-telegram`) that:

1. declares a **detect rule** the main skill's Step 0 can evaluate, and
2. provides its own **Step 4** that delivers the handoff through its channel.

## Detect rule

- Must be a check the executing agent can run cheaply and unambiguously (an env var, a `command -v`, a config file, a live bridge session). Example: a Telegram adapter fires when its bridge session is present.
- Must fail quiet: if the adapter is referenced but not installed, or its detect rule doesn't fire, the main skill falls through to the next transport — **an adapter must never be a hard dependency of a handoff**.

## What the main skill hands you

After Steps 0–3.5 you can rely on:

- `<DOCDIR>` — the resolved doc directory (Step 1; may be `<CWD>` itself, not necessarily `docs/`). All your output paths derive from it — never hardcode `docs/`.
- The handoff doc's absolute path, topic slug, and date.
- The header values (`next_action`, `do_not`, tripwires) — already gathered, verified, and gated.
- The harness profile (`SUCCESSOR_CMD`, `HAS_SUBAGENTS`, `HAS_TASK_LIST`).

## Your Step 4 must

1. **Stay a thin loader.** Deliver the doc's location plus the hard guardrails — never restate the resume payload through the channel. Two copies drift; the doc is the only truth.
2. **Carry the guardrails.** The header `do_not` and any `[IRREVERSIBLE]` / `[CONFIDENTIAL]` lines must reach the successor even if it never reads anything else you sent.
3. **Preserve the ACK contract.** The successor writes `<DOCDIR>/.handoff-ack-<topic>-<date>.txt`, mirroring the doc filename including any `-2` collision suffix (PICKED UP / FIRST STEP / DRIFT). If your channel can't run the successor interactively, deliver the doc + guardrails and print the manual pickup path instead (`handoff-resume` exists for exactly this).
4. **Degrade, never error.** If delivery fails mid-Step-4, fall back to the file-only behavior: doc path + exact manual command, prominently reported. A handoff must never fail over a transport.
5. **Respect the redaction rule.** Your channel is one more place secrets must not leak — reference credentials abstractly there too.

## Versioning

The doc contract evolves in `skills/handoff/SKILL.md` ("when you change the doc contract, change it HERE"). Pin your adapter to the contract version you tested against, and say so in your README.
