# The PreCompact seatbelt (optional, opt-in)

`/handoff` works best as a habit — but the moment you most need a handoff is exactly the moment you're least likely to remember it: when Claude Code's context fills up and **auto-compacts**, silently discarding the session detail a handoff would have captured.

The seatbelt is a small `PreCompact` hook that fires just before compaction:

- **Auto-compaction, inside a git repo** → writes a mechanical snapshot (`docs/HANDOFF-AUTOSAVE-<timestamp>.md`: branch, HEAD, `git status`, recent commits, existing handoff chain) and posts a system message telling you where it landed and to run `/handoff` for a real resume doc.
- **Auto-compaction, not a git repo** → just the nudge, no file.
- **Manual `/compact`** → does nothing. You're present; it stays out of your way.

It is **fail-open by design**: any error exits 0, so it can never block compaction. Autosave snapshots are mechanical only — they have no resume point or narrative, are never part of the canonical handoff chain, and are safe to delete.

## Why this is opt-in and not part of the plugin

Claude Code auto-enables hooks that a plugin declares in its manifest. A hook that writes files into your repos on a global trigger should be a decision you make, not a side effect of installing a skill. So this ships as a **documented recipe only** — nothing installs it for you.

## Install (two steps)

1. Copy the script somewhere stable and make it executable:

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/handoff-autosave.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/handoff-autosave.sh
   ```

2. Add the `PreCompact` entry to `~/.claude/settings.json` (merge with any existing `hooks` block):

   ```json
   {
     "hooks": {
       "PreCompact": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "~/.claude/hooks/handoff-autosave.sh"
             }
           ]
         }
       ]
     }
   }
   ```

Requirements: `bash`, `git`, and a `python3` on PATH (used only to parse the hook's JSON payload; present by default on macOS and most Linux distros).

## Uninstall

Delete the script and remove the `PreCompact` entry from `~/.claude/settings.json`. That's it — the hook keeps no other state.
