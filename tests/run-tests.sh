#!/usr/bin/env bash
# Fixture tests for hooks/handoff-autosave.sh. Run from the repo root:
#   bash tests/run-tests.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/handoff-autosave.sh"
failures=0

check() { # $1 = name, $2 = exit code of the condition just run
  if [ "$2" -eq 0 ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    failures=$((failures + 1))
  fi
}

json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/handoff-hook-test-XXXXXX")"

# --- fixture 1: auto-compact in a git repo whose path contains a SPACE ---
# Regression test: a space-split cwd used to silently disable the hook.
proj="$work/my project"
mkdir -p "$proj"
(
  cd "$proj" || exit 1
  git init -q
  git -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init
)
out="$(printf '{"cwd": %s, "trigger": "auto"}' "$(json_str "$proj")" | bash "$HOOK")"
ls "$proj"/docs/HANDOFF-AUTOSAVE-*.md >/dev/null 2>&1
check "auto-compact in spacey git-repo path writes docs/HANDOFF-AUTOSAVE-*" $?
printf '%s' "$out" | grep -q '"systemMessage"'
check "auto-compact prints a systemMessage nudge" $?

# --- fixture 2: manual /compact does nothing ---
before="$(ls "$proj"/docs/HANDOFF-AUTOSAVE-*.md 2>/dev/null | wc -l)"
out="$(printf '{"cwd": %s, "trigger": "manual"}' "$(json_str "$proj")" | bash "$HOOK")"
[ -z "$out" ]
check "manual trigger: no output" $?
after="$(ls "$proj"/docs/HANDOFF-AUTOSAVE-*.md 2>/dev/null | wc -l)"
[ "$before" = "$after" ]
check "manual trigger: no new autosave file" $?

# --- fixture 3: auto-compact outside a git repo → nudge only, no file ---
plain="$work/plain dir"
mkdir -p "$plain"
out="$(printf '{"cwd": %s, "trigger": "auto"}' "$(json_str "$plain")" | bash "$HOOK")"
[ -z "$(ls -A "$plain")" ]
check "non-git dir: no files written" $?
printf '%s' "$out" | grep -q '"systemMessage"'
check "non-git dir: still nudges" $?

# --- fixture 4: garbage stdin → fail-open, exit 0 ---
printf 'not json at all' | bash "$HOOK" >/dev/null 2>&1
check "garbage payload exits 0" $?

rm -rf "$work"
echo
if [ "$failures" -eq 0 ]; then
  echo "All hook fixture tests passed."
else
  echo "$failures test(s) FAILED."
  exit 1
fi
