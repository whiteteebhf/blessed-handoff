# Telegram transport adapter (optional)

**Status: optional adapter — not part of the core skill, ships disabled.**

This adapter delivers a handoff as a paste-ready "pickup block" into a Telegram topic instead of spawning a terminal tab. It exists for setups where Claude Code sessions are driven from a phone through a **Telegram↔tmux bridge**: a dedicated tmux session in which each window is a Claude session bound to a Telegram topic via a bot.

**No bridge is included in this repo**, and none is required for the core `/handoff` skill — without this adapter, `/handoff` simply uses your terminal or falls back to file-only.

## Install (only if you run such a bridge)

1. Copy `adapters/telegram/` to `~/.claude/skills/handoff-telegram/` (the folder must contain `SKILL.md`).
2. Edit the `<BRIDGE-SESSION>` placeholder in `SKILL.md` to your bridge's tmux session name.
3. Done — `/handoff` Step 0 will auto-route to it when a session is running inside that tmux session.

## What the adapter does NOT do

- It does not send Telegram messages itself. It prints a block; **you** paste it into a new topic.
- It does not manage topics, bots, or the bridge lifecycle.
- It does not change the handoff doc contract — that stays 100% in `skills/handoff/SKILL.md`.
