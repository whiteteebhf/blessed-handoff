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
cp -r the-blessed-handoff/skills/handoff-resume ~/.claude/skills/handoff-resume   # optional pickup side
```

Then `/handoff` is available in every Claude Code session. The second copy is `handoff-resume`, the companion pickup skill — it lets ANY fresh session (any harness, any machine) pick up a handoff doc by path, without the auto-spawn machinery. On other harnesses, copy it into that harness's own skills directory instead of `~/.claude/skills/`.

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
| `/handoff-resume docs/HANDOFF-….md` | Companion skill: pick up a handoff doc from any fresh session — re-verifies state, writes the ACK, continues the work |

Claude will also *propose* a handoff at sensible moments (before `/compact` with non-trivial work in flight, at natural breaks in long sessions) — once, and it won't pester if declined.

Note: `/handoff` boots a **live agent that immediately runs the doc's re-verify checks** (tests, git, deploy status). Irreversible actions stay user-gated via the tripwires, but if you'd rather review the doc before anything runs, use `--no-spawn`.

## Compatibility

Honest labels — "tested" means used in real work, not that a CI matrix exists:

| Environment | Status |
|---|---|
| Claude Code · macOS · WezTerm auto-spawn | **Tested** (daily use) |
| Claude Code · file-only fallback | **Tested** (daily use) |
| tmux / kitty / iTerm2 / Windows Terminal auto-spawn | Should work, **untested** — spawn failure falls through to file-only by design. Windows Terminal assumes WSL/MSYS; the skill's shell commands are POSIX throughout |
| Other harnesses (anything that can read/write files) | The doc contract itself is harness-agnostic; Step 0's harness profile parameterizes the successor command, the subagent gate, and the task list, and delivery degrades as documented. The `handoff-resume` companion skill is the harness-neutral pickup path. **Untested.** |

Known constraints:
- Some GUI terminals can't be scripted at all (e.g. macOS Accessibility can block automation of Apple Terminal, and iTerm2-via-osascript needs an Automation/Apple Events consent that fails opaquely on first run) — that's what the detect-checks and file-only baseline are for.
- "Switch machines" carries **committed state only**. The doc references local branches, uncommitted work, and absolute paths; the re-verify steps will fail on another machine unless the checkout matches. Treat cross-machine resume as "same repo, same commit, then re-verify."

## Optional extras

- **`handoff-resume` pickup skill** (`skills/handoff-resume/`) — the successor side of the contract as a standalone skill: point any fresh session at a handoff doc and it re-verifies state, writes the ACK, and continues. This is the natural pickup path for other harnesses, other machines, and terminals where auto-spawn doesn't work.
- **PreCompact seatbelt** — a small opt-in hook that snapshots mechanical state to disk just before Claude Code *auto*-compacts, so an unplanned compaction never costs you the thread. Deliberately **not** auto-installed by the plugin (a hook that writes into your repos should be your decision): recipe in [`docs/seatbelt.md`](docs/seatbelt.md). Autosave snapshots accumulate — prune `HANDOFF-AUTOSAVE-*` occasionally; they're safe to delete.
- **Writing a transport adapter?** (Telegram, Slack, …) — the adapter contract lives in [`docs/adapters.md`](docs/adapters.md).
- **Contributing** — CI runs shellcheck on the hook, fixture tests for the PreCompact payload parsing, and a frontmatter parse of the example doc. Run them locally with `tests/run-tests.sh` and `tests/check-docs.py`.

## License

MIT — see [LICENSE](LICENSE).
