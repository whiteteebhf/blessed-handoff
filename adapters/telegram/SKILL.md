---
name: handoff-telegram
description: Telegram transport adapter for /handoff. Writes the same dated, cold-resumable handoff doc (the canonical contract lives in handoff/SKILL.md), then — instead of spawning a terminal tab — emits a ready-to-paste pickup block the user drops into a new Telegram topic. REQUIRES your own Telegram↔tmux bridge (not included — see README in this folder). Use when the user says "/handoff-telegram", "telegram handoff", "hand off this topic", or when running inside a bridge-bound tmux session and needs to reset context.
---

# Handoff — Telegram Transport (optional adapter)

> **Prerequisite — bring your own bridge.** This adapter assumes a Telegram↔tmux bridge: a setup where phone-driven Claude sessions run inside a dedicated tmux session, each bound to a Telegram topic via a bot. No such bridge is included here. If you don't run one, this adapter is not for you — plain `/handoff` already degrades to file-only everywhere.

This is **not a separate handoff spec.** It is the `/handoff` skill delivered over a different transport, for sessions driven from a phone (where spawning a terminal tab is impossible).

**The entire doc contract — filename rules, ground-truth gathering, the machine-readable header, the body structure, the length guidance, the resumability self-test, and the What-NOT-to-do list — lives in `handoff/SKILL.md`. Follow that file for Steps 0–3.5 and Step 5.** This file overrides ONLY **Step 4 (delivery)**. If the doc contract ever feels out of date here, the truth is in `handoff/SKILL.md` — never duplicate it back into this file.

---

## Configuration

Set your bridge's tmux session name where this file says `<BRIDGE-SESSION>` (edit this file after installing, or keep the convention your bridge uses). Detection keys off that name.

## When to use this vs. `/handoff`

| Situation | Use |
|---|---|
| User at their desk in a scriptable terminal | `/handoff` (spawns a tab) |
| User on phone, session bound to the bridge's tmux session | `/handoff-telegram` (emits a pickup block) |
| Started from Telegram, now at the desk | Either — the pickup block still works; just paste it at the desk |

**Auto-detection** (plugs into `handoff/SKILL.md` Step 0's adapter row): if `$TMUX` is set and `tmux display -p '#S'` returns `<BRIDGE-SESSION>`, you are in a Telegram-driven session and this transport applies. If `$TMUX` is unset, warn: "You're not in a bridge session — did you mean `/handoff`?" and proceed only on confirmation.

---

## Inputs

- **Positional topic slug** — same normalization as `/handoff`.
- **`--doc-only`** — write the doc, skip the pickup block.
- **`--panic`** — panic-cheap mode (see `handoff/SKILL.md` Step 0).

*(No `--no-spawn` — nothing is spawned. The "spawn" here is the user pasting into Telegram, which is always opt-in.)*

---

## Steps 0–3.5 — identical to `/handoff`

Run them from `handoff/SKILL.md` exactly as written, including:
- Step 2's **task-list capture** and **memory/CLAUDE.md read** (both best-effort per the canonical spec).
- The **machine-readable YAML header** at the top of the doc.
- **Step 3.5 resumability gate** — the author re-read (always) and the cold-reader self-test subagent (normal mode, when subagents exist). A Telegram handoff is held to the same cold-resumable bar as a desktop one.

The handoff doc written to `<DOCDIR>` is byte-for-byte the same kind of artifact `/handoff` produces. Only the delivery below differs.

---

## Step 4 — Build the Telegram pickup block (a thin loader)

Skip if `--doc-only`.

Like the desktop loader, the pickup block does **not** restate the doc — it points at it. The successor that boots in the new Telegram topic has filesystem access to the project, so it reads the doc directly.

### 4a — Compose the pickup block

Save it to `<DOCDIR>/HANDOFF-<topic>-<YYYY-MM-DD>.pickup.md` **and** print it inline. Saving it to disk is a real, reported step (so the user can re-fetch it if they lose the Telegram message) — confirm the file was written in Step 5.

Template (keep under ~3500 chars so it fits one Telegram message with room for the code fence):

```
Fresh context — you're taking over a <PROJECT NAME> session from a prior Telegram topic via handoff.

AUTHORITATIVE — read this FIRST and act on IT, not on memory of this message:
  <path to the handoff doc, relative to the project root>

Hard guardrails (hold even if you misread the doc):
  - <the 1–3 tripwires from the header `do_not` + any [IRREVERSIBLE]/[CONFIDENTIAL] lines>
  - Do NOT make irreversible changes until the user directs you.

Your first actions, in order:
  1. Read the handoff doc in full. (Large referenced specs: skim only the sections it names — don't burn context.)
  2. Run its "Re-verify before you act" checks; note any drift from live state.
  3. If it references a live task list, re-hydrate those tasks.
  4. Confirm pickup back IN THIS TOPIC in 2–3 sentences: restate the next action in your own words + flag any doc-vs-live drift you spotted.
  5. Then proceed.

The user's name is <NAME>. Today is <DATE>. Working directory is the project root.
```

Substitute every `<...>`; leave none in the output. (On Telegram the ACK is the successor's 2–3 sentence reply in-topic — the user sees the loop close in-app, so no separate ack file is needed.)

### 4b — Output to the current topic

Print one short instruction line, then the pickup block in a triple-backtick fence so Telegram preserves formatting and the user can tap-copy it:

```
Handoff doc → <DOCDIR>/HANDOFF-<topic>-<YYYY-MM-DD>.md
Pickup block → <DOCDIR>/HANDOFF-<topic>-<YYYY-MM-DD>.pickup.md

To resume with fresh context:
1. In Telegram, create a new topic.
2. Start a Claude session bound to it (however your bridge does this) in <project dir>.
3. Paste the block below as your first message:

```<pickup block>```
```

Do NOT dump the full handoff doc into chat — it's a file; the pickup block is the bridge.

---

## Step 5 — Report back

1. Path to the handoff doc.
2. Path to the `.pickup.md` file (confirm it was actually written — this is the re-fetch safety net).
3. Resumability gate result (PASS / residual gap / skipped), same as `/handoff`.
4. One-line hint of what the successor will do first.

---

## What NOT to do (transport-specific)

- **Don't spawn a terminal tab** — the user isn't at their desk. If they are, they wanted `/handoff`.
- **Don't reset or unbind the Telegram topic** — the user owns topic lifecycle in Telegram.
- **Don't paste the full doc into chat** — only the pickup block.
- **Don't restate the doc's resume payload in the block** — it's a thin loader; the doc is the truth.
- **Don't claim the `.pickup.md` was saved without actually writing it** — make the write real and report it.
- Everything else (no padding, no hallucinated state, no leaked secrets, no overwriting old handoffs) — see `handoff/SKILL.md` § What NOT to do.

---

## Sample invocations

| User input | Behavior |
|---|---|
| `/handoff-telegram` | Infer topic. Write doc (+ self-test) + emit & save pickup block. |
| `/handoff-telegram daily-log` | Explicit slug. |
| `/handoff-telegram --doc-only` | Doc only, no pickup block. |
| `/handoff-telegram --panic` | Panic-cheap doc + pickup block. |
