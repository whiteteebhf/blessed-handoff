# the-blessed-handoff — cold-resumable session handoffs for Claude Code

You're deep in a working session and the context window is nearly full — or you need to step away, switch machines, or hand the thread to tomorrow-you. `/handoff` writes a dated, self-contained handoff doc capturing exactly where the work stands (the next action, the tripwires, the unverified hunches, the settled decisions), **proves a cold reader can resume from it**, then spawns a fresh Claude instance in a new terminal tab already primed to pick up the thread.

Thirty seconds after typing `/handoff`, a new tab opens, a fresh Claude reads the doc, writes a three-line acknowledgment, and continues your work — with none of your session's context rot and all of its state.

## What it looks like

```text
you › /handoff

⏺ Handoff — writing docs/HANDOFF-checkout-refactor-2026-07-13.md
  · ground truth: branch feat/checkout-v2 @ 4f9c2ae · tests: 2 passed, 1 failed
  · doc written — header next_action: "Fix the stale idempotency test…"
⏺ Resumability gate — spawning a cold reader with zero session context…
  · cold-reader self-test: PASS — successor will: fix the stale idempotency test
⏺ Spawning successor tab (wezterm) — pane 2

────────────────────────────── new tab ──────────────────────────────

⏺ Fresh Claude: reads docs/HANDOFF-checkout-refactor-2026-07-13.md
  · re-verify: make test → 2 passed, 1 failed ✓ matches the doc
  · ACK written → .handoff-ack-checkout-refactor-2026-07-13.txt

  "Picking up the checkout refactor — I'll fix the idempotency test to
   match the new fulfillment-time capture and get the suite green. The
   capture-timing diff is queued for your review before any deploy."
```

*(Illustrative transcript — a screen recording is coming shortly. The successor really does open in a new terminal tab.)*

## The idea that makes it work: resumability is measured, not assumed

Most handoff/summary prompts hope the summary is good enough. This skill **tests** it: before delivery, it spawns one throwaway subagent with zero session context, gives it only the doc, and asks it three questions — *what's the single next action, what's your first reply to the user, and what can't you resolve from this file alone?* If the cold reader picks the wrong action or hits an unresolvable term, the doc gets one bounded revise pass and is re-tested. The doc ships exactly as long as it needs to be to pass — no longer.

Two supporting principles:

- **Single source of truth.** The doc is the artifact. The pickup prompt that boots the successor is a *thin loader* — it points at the doc and carries only the hard guardrails; it never restates the resume payload, because two copies drift.
- **Graceful degradation everywhere.** Auto-spawn works where your terminal supports it; everywhere else the skill writes the doc and prints the exact manual command. No task-list tool? It says so instead of inventing one. No subagents? The gate degrades to a structured author re-read — and tells you it did. The failure mode is always "less automation," never "no handoff."

## What a handoff doc looks like

See [`examples/HANDOFF-checkout-refactor-2026-07-13.md`](examples/HANDOFF-checkout-refactor-2026-07-13.md) — one realistic example teaches the contract faster than the spec. Highlights: a machine-readable YAML header (`next_action`, `do_not`, `validity`), tagged tripwires (`[IRREVERSIBLE]`/`[CONFIDENTIAL]`/`[FOOTGUN]`), LOCKED decisions with their *because* and *reopen-if*, and an "Open threads — what I believe but did NOT verify" section with confidence labels — the predecessor's live mental state, which ordinary summaries silently delete.

## Install

**Option A — bare skill (simplest):**

```bash
git clone https://github.com/whiteteebhf/the-blessed-handoff.git
cp -r the-blessed-handoff/skills/handoff ~/.claude/skills/handoff
```

Then `/handoff` is available in every Claude Code session.

**Option B — as a plugin:**

```
/plugin marketplace add whiteteebhf/the-blessed-handoff
/plugin install the-blessed-handoff@the-blessed-handoff
```

Note: plugin-installed skills are namespaced (`/the-blessed-handoff:handoff`); the bare-skill install gives you the shorter `/handoff`.

## Usage

| Invocation | What happens |
|---|---|
| `/handoff` | Infers a topic, writes the doc, runs the cold-reader gate, spawns the successor |
| `/handoff auth-refactor` | Same, with an explicit topic slug |
| `/handoff --no-spawn` | Doc + gate only; no delivery |
| `/handoff --panic` | Minimal fast-path doc for when context is nearly gone |
| `/handoff --transport file-only` | Write the doc, print the manual spawn command |

Claude will also *propose* a handoff at sensible moments (before `/compact` with non-trivial work in flight, at natural breaks in long sessions) — once, and it won't pester if declined.

## Compatibility

Honest labels — "tested" means used in real work, not that a CI matrix exists:

| Environment | Status |
|---|---|
| Claude Code · macOS · WezTerm auto-spawn | **Tested** (daily use) |
| Claude Code · file-only fallback | **Tested** (daily use) |
| tmux / kitty / iTerm2 / Windows Terminal auto-spawn | Should work, **untested** — spawn failure falls through to file-only by design |
| Other harnesses (anything that can read/write files) | The doc contract itself is harness-agnostic; delivery and the subagent gate degrade as documented. **Untested.** |

Known constraint: some GUI terminals can't be scripted at all (e.g. macOS Accessibility can block automation of Apple Terminal) — that's what the detect-checks and file-only baseline are for.

## Optional extras

- **PreCompact seatbelt** — a small opt-in hook that snapshots mechanical state to disk just before Claude Code *auto*-compacts, so an unplanned compaction never costs you the thread. Deliberately **not** auto-installed by the plugin (a hook that writes into your repos should be your decision): recipe in [`docs/seatbelt.md`](docs/seatbelt.md).

## License

MIT — see [LICENSE](LICENSE).
