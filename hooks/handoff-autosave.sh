#!/usr/bin/env bash
# PreCompact seatbelt for the /handoff skill — "autosave + nudge".
# Fires before compaction. On AUTO compaction inside a git repo, writes a
# mechanical-state snapshot to docs/HANDOFF-AUTOSAVE-<ts>.md and nudges the
# user to run /handoff for a real resume doc. On manual /compact it does
# nothing (the user is present and chose to compact).
#
# Receives the hook payload as JSON on stdin (fields: cwd, trigger,
# transcript_path, ...). Best-effort and fail-open: any error exits 0 so it
# can never block compaction.
#
# OPT-IN — install manually per docs/seatbelt.md; never wire this up
# silently. Safe to delete; remove the PreCompact entry in
# ~/.claude/settings.json too if you do.
#
# Requires: bash, git, and a python3 on PATH (used only to parse the JSON
# payload; ships with macOS and most Linux distros).
set -uo pipefail

input="$(cat 2>/dev/null)"

# --- parse stdin JSON ---
read -r cwd trigger < <(
  printf '%s' "$input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print(d.get("cwd", ""), d.get("trigger", ""))
' 2>/dev/null
)
[ -z "${cwd:-}" ] && cwd="$PWD"

# --- only act on AUTO compaction ---
if [ "${trigger:-}" != "auto" ]; then
  exit 0
fi

cd "$cwd" 2>/dev/null || exit 0

nudge() { printf '{"systemMessage": %s}\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1")"; }

# --- not a git repo → nudge only, no file ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  nudge "Context is auto-compacting. Consider running /handoff afterward to capture a clean resume point."
  exit 0
fi

ts="$(date +%Y-%m-%d-%H%M%S)"
docdir="docs"; [ -d "$docdir" ] || docdir="."
out="$docdir/HANDOFF-AUTOSAVE-$ts.md"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
head="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"

{
  echo "# HANDOFF — AUTOSAVE (mechanical seatbelt · $ts)"
  echo
  echo "> Auto-written by the PreCompact seatbelt hook because context auto-compacted."
  echo "> This is a MECHANICAL snapshot, not a real handoff — it has no resume point,"
  echo "> open threads, or narrative. Run **/handoff** for a proper cold-resumable doc."
  echo "> NOT part of the canonical handoff chain. Safe to delete."
  echo
  echo "## Snapshot"
  echo "- cwd: \`$cwd\`"
  echo "- branch: \`$branch\` · HEAD: \`$head\`"
  echo
  echo "## git status (short)"
  echo '```'
  git status --short 2>/dev/null | head -100
  echo '```'
  echo
  echo "## Recent commits"
  echo '```'
  git log --oneline -15 2>/dev/null
  echo '```'
  echo
  echo "## Existing handoff docs in this project"
  echo '```'
  ls -1 "$docdir"/HANDOFF-*.md 2>/dev/null | grep -v AUTOSAVE | tail -10
  echo '```'
} > "$out" 2>/dev/null || { nudge "Context auto-compacting — run /handoff to capture state (autosave write failed)."; exit 0; }

nudge "Context auto-compacted. Mechanical seatbelt saved → $out. Run /handoff for a full resume doc."
exit 0
